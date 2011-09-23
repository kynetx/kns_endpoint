require 'rest_client'
require 'json'
require 'logger'

module Kynetx

  class Endpoint

    RestClient.log = Logger.new(STDOUT) if $KNS_ENDPOINT_DEBUG

    # DSL 
    class << self
      attr_reader :events, :directives 
      attr_reader :c_ruleset, :c_domain, :c_use_session, :c_environment

      def event(e, params={}, &block)
        @events ||= {}
        @events[e] = { :params => params }
        @events[e][:block] = block_given? ? block : lambda { |p| p }
      end

      def directive(d, &block)
        @directives ||= {}
        @directives[d] = block_given? ? block : lambda { |p| p }
      end

      def use_session(u); @c_use_session = u end
      def environment(e); @c_environment = e end
      def ruleset(r); @c_ruleset = r end
      def domain(d); @c_domain = d end

      def signal(e, params)
        tmp_endpoint = self.new
        tmp_endpoint.signal(e, params)
      end

      def method_missing(meth, *args)
        if @events.include? meth.to_sym 
          ruleset = @ruleset
          if args.first.class == Symbol
            ruleset = args.first 
            params = args.length > 1 ? args.last : {}
          else
            params = args.first
          end
          e = self.new({:ruleset => ruleset})
          e.signal(meth.to_sym, params)
        else
          super
        end
      end


    end

    attr_accessor :session, :environment, :ruleset, :use_session, :headers, :logging, :query_timeout
    attr_reader :log

    def initialize(opts={})
      @environment = opts[:environment] if opts[:environment]
      @ruleset = opts[:ruleset] if opts[:ruleset]
      @use_session = opts[:use_session] if opts[:use_session]
      @query_timeout = opts[:query_timeout] if opts[:query_timeout]
      @logging = opts[:logging] if opts[:logging]
      @headers = opts[:headers] if opts[:headers]
      
      @events = self.class.events
      @directives = self.class.directives
      @ruleset ||= self.class.c_ruleset 
      @domain = self.class.c_domain 
      @environment ||= self.class.c_environment || :production
      @use_session ||= self.class.c_use_session || true
      
      # instance level settings
      @query_timeout ||= 120
      @headers ||= {}
      @logging ||= false
      @log = []
      @params = {}
      raise "No events defined" unless @events 
      raise "No directives defined" unless @directives
      raise "Undefined ruleset." unless @ruleset
      raise "Undefined domain." unless @domain
    end

    def signal(e, params={})
      run_event(e, params)
    end

    def params
      @params ||= {}
    end

    # allow calling events directly
    def method_missing(meth, *args)
      if @events.keys.include? meth.to_sym
        return run_event(meth.to_sym, args.first)
      else
        super
      end
    end

    private

    def run_event(e, p)
      # run the event
      @params = p
      kns_json = {"directives" => []}
      
      begin
        # setup the parameters and call the block

        if @events.keys.include? e
          @events[e][:block].call(params) 

          if self.methods.include? "before_#{e}"
            send "before_#{e}".to_sym
          end
        else
          raise "Undefined event #{e.to_s}"
        end
        
        
        api_call = "https://cs.kobj.net/blue/event/#{@domain.to_s}/#{e.to_s}/#{@ruleset}"

        if @use_session && @session
          @headers[:cookies] = {"SESSION_ID" => @session, "domain" => "kobj.net"}
        else
        #  @session = nil
          @headers = {}
        end

        timeout(@query_timeout) do
          params[@ruleset.to_s + ":kinetic_app_version"] = "dev" unless @environment == :production

          if $KNS_ENDPOINT_DEBUG
            puts "-- NEW REQUEST --"
            puts "-- URL: " + api_call
            puts "-- SESSION: #{@session.inspect}"
            puts "-- USE_SESSION: #{@use_session.inspect}"
            puts "-- HEADERS:\n#{headers.inspect}"
            puts "-- PARAMS:\n#{params.inspect}"
          end

          response = RestClient::Resource.new(
            api_call,
            :timeout => @query_timeout
          ).post(params, headers)

          raise "Unexpected response from KNS (HTTP Error: #{response.code} - #{response})" unless response.code.to_s == "200"

          @session = response.cookies["SESSION_ID"]
          begin
            kns_json = JSON.parse(response.to_s)
          rescue
            raise "Unexpected response from KNS (#{response.to_s})"
          end

          # extract the logging
          if @logging 
            @log = response.split("\n")
            @log.pop
          end

          if $KNS_ENDPOINT_DEBUG
            puts "-- RESPONSE --"
            puts "-- CODE: #{response.code}"
            puts "-- SESSION: #{@session}"
            puts "-- COOKIES: #{response.cookies.inspect}"
            puts "-- HEADERS: #{response.headers.inspect}"
            puts "-- BODY: \n" + response.to_s
            puts "-- LOG: \n" + @log.join("\n")
          end
        end
      rescue Exception => e
        raise "Unable to connect to KNS. (#{e.message})"
      end


      # execute the returned directives
      directive_output = []
      kns_json["directives"].each do |d|
        directive = d["name"].to_sym
        d_opts = d["options"]
        if @directives.keys.include?(directive)
          o = run_directive(directive, d_opts) 
          directive_output.push o

          if self.methods.include? "after_#{directive}"
            send "after_#{directive}".to_sym, d_opts
          end

        end
      end

      return directive_output
      
    end


    def run_directive(d, params)
      begin
        return @directives[d].call(symbolize_keys(params))
      rescue Exception => e
        raise "Error in directive (#{d.to_s}): #{e.message}"
      end

    end

    def symbolize_keys(hash)  
      return {} unless hash.class == Hash

      hash.inject({}){|result, (key, value)|  
        new_key = case key  
                  when String then key.to_sym  
                  else key  
                  end  
      new_value = case value  
                  when Hash then symbolize_keys(value)  
                  else value  
                  end  
      result[new_key] = new_value  
      result  
      }  
    end 



  end

end




