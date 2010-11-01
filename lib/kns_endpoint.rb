require 'rest_client'
require 'json'

module Kynetx

  class Endpoint
    attr_accessor :session, :environment, :ruleset, :use_session, :headers

    @@events = {}
    @@directives = {}
    @@use_session = true;
    @@environment = :production
    @@ruleset = nil

    def initialize(opts={})
      @environment = opts[:environment] if opts[:environment]
      @ruleset = opts[:ruleset] if opts[:ruleset]
      @use_session = opts[:use_session] if opts[:use_session]
      @query_timeout = opts[:query_timeout] if opts[:query_timeout]

      # set the defaults
      @environment ||= @@environment
      @use_session ||= @@use_session
      @ruleset ||= @@ruleset
      @query_timeout ||= 120
      @headers ||= {}
      raise "Undefined ruleset." unless @ruleset
    end

    ## Endpoint DSL

    def self.event(e, params={}, &block)
      @@events[e] = { :params => params }
      @@events[e][:block] = block_given? ? block : lambda { |p| p }
    end

    def self.directive(d, &block)
      raise "Directive must supply a block." unless block_given?
      @@directives[d] = block
    end

    def self.ruleset(r); @@ruleset = r end
    def self.domain(d); @@domain = d end
    def self.environment(e); @@environment = e end
    def self.use_session(s); @@use_session = s end

    ##########

    def signal(e, params={})
      run_event(e, params)
    end

    def self.signal(e, params)
      tmp_endpoint = self.new({:ruleset => @@ruleset, :environment => @@environment})
      tmp_endpoint.signal(e, params)
    end

    # allow calling events directly
    def method_missing(meth, *args)
      if @@events.keys.include? meth.to_sym
        return run_event(meth.to_sym, args.first)
      else
        super
      end
    end

    def self.method_missing(meth, *args)
      if @@events.include? meth.to_sym 
        ruleset = @@ruleset
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

    private

    def run_event(e, params)
      # run the event

      # set the default params as an empty hash

      params ||= {}

      kns_json = {"directives" => []}
      
      begin
        # setup the parameters and call the block

        if @@events.keys.include? e
          @@events[e][:block].call(params) 
        else
          raise "Undefined event #{e.to_s}"
        end
        
        raise "Undefined Domain" unless @@domain
        
        api_call = "https://cs.kobj.net/blue/event/#{@@domain.to_s}/#{e.to_s}/#{@ruleset}"
 
        @headers[:cookies] = {"SESSION_ID" => @session} if @session && @use_session

        timeout(@query_timeout) do
          params[@ruleset.to_s + ":kynetx_app_version"] = "dev" unless @environment == :production

          if $KNS_ENDPOINT_DEBUG
            puts "-- NEW REQUEST --"
            puts "-- URL: " + api_call
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

          if $KNS_ENDPOINT_DEBUG
            puts "-- RESPONSE --"
            puts "-- CODE: #{response.code}"
            puts "-- COOKIES: #{response.cookies.inspect}"
            puts "-- HEADERS: #{response.headers.inspect}"
            puts "-- BODY: \n" + response.to_s
          end
        end
      rescue Exception => e
        raise "Unable to connect to KNS. (#{e.message})"
      end

      # execute the returned directives
      directive_output = []
      kns_json["directives"].each do |d|
        o = run_directive(d["name"].to_sym, d["options"]) if @@directives.keys.include?(d["name"].to_sym)
        directive_output.push o
      end

      return directive_output
      
    end


    def run_directive(d, params)
      begin
        return @@directives[d].call(symbolize_keys(params))
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




