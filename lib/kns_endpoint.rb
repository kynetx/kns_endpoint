require 'net/https'
require 'open-uri'
require 'json'

module Kynetx

  class Endpoint
    attr_accessor :session

    @@events = {}
    @@directives = {}
    @@use_single_session = true;

    def initialize(opts={})
      @@ruleset = opts[:ruleset] if opts[:ruleset]
    end


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
    def use_single_session; @@use_single_session end
    def use_single_session=(uss); @@use_single_session = uss end

    def signal(e, params={}, ruleset=nil)
      raise "Undefined ruleset" unless @@ruleset || ruleset
      
      run_event(e, ruleset || @@ruleset, params)
    end

    def self.signal(e, params, ruleset)
      tmp_endpoint = self.new({:ruleset => ruleset})
      tmp_endpoint.signal(e, params)
    end

    # allow calling events directly
    def method_missing(meth, *args)
      if @@events.keys.include? meth.to_sym
        ruleset = nil
        params = {}

        if args.first.class == Symbol
          ruleset = args.first 
          params = args.last if args.length > 1
        else
          params = args.first if args.first.class == Hash
        end


        return run_event(meth.to_sym, ruleset || @@ruleset, params)

      else
        super
      end
    end

    def self.method_missing(meth, *args)
      raise "Undefined ruleset" unless args.first.class == Symbol
      params = args.length > 1 ? args.last : {}
      e = self.new({:ruleset => args.first})
      e.signal(meth.to_sym, params)
    end

    private

    def run_event(e, ruleset, params)
 
      # setup the parameters and call the block

      if @@events.keys.include? e
        @@events[e][:block].call(params) 
      else
        raise "Undefined event #{e.to_s}"
      end


      # run the event

      kns_json = {"directives" => []}
      
      begin
        raise "Undefined Domain" unless @@domain
        
        api_call = "https://cs.kobj.net/blue/event/#{@@domain.to_s}/#{e.to_s}/#{ruleset}"
        puts api_call if $KNS_ENDPOINT_DEBUG
        uri = URI.parse(api_call)
        http_session = Net::HTTP.new(uri.host, uri.port)
        http_session.verify_mode = OpenSSL::SSL::VERIFY_NONE
        http_session.use_ssl = true
    
        headers = {
          'Host'=>  uri.host,
        }

        headers["Cookie"] = "SESSION_ID=#{@session}" if @session && @@use_single_session

        timeout(30) do
          http_session.start { |http|
            req = Net::HTTP::Post.new(uri.path)
            headers.each{|key, val| req.add_field(key, val)}
            resp, data = http.request(req, params.to_url_params)
            @session = parse_cookie(resp, 'SESSION_ID') 

            puts 'Code = ' + resp.code if $KNS_ENDPOINT_DEBUG
            puts 'Message = ' + resp.message if $KNS_ENDPOINT_DEBUG
            resp.each {|key, val| puts key + ' = ' + val} if $KNS_ENDPOINT_DEBUG
            puts "Data = \n" + data if $KNS_ENDPOINT_DEBUG
            

            raise "Unexpected response from KNS (HTTP Error: #{resp.code} - #{resp.message})" unless resp.code == '200'
            begin
              kns_json = JSON.parse(data)
            rescue
              raise "Unexpected response from KNS (#{data})"
            end
          }
        end
      rescue Exception => e
        raise "Unable to connect to KNS. (#{e.message})"
      end

      # execute the returned directives
      directive_output = []
      kns_json["directives"].each do |d|
        o = run_directive(d["name"].to_sym, symbolize_keys(d["options"])) if @@directives.keys.include?(d["name"].to_sym)
        directive_output.push o
      end

      return directive_output
      
    end


    def run_directive(d, params)
      begin
        return @@directives[d].call(params)
      rescue Exception => e
        puts "Error in directive (#{d.to_s}): #{e.message}\n#{e.backtrace.join("\n")}"
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

    def parse_cookie(resp_hash, cookie)
      cookie_str = resp_hash['set-cookie']
      cookies = {}
      cookie_str.split(";").map{|e| k,v = e.split('='); cookies[k] = v}
      return cookies[cookie]
    end
    
  end

end

class Hash
  def to_url_params
    elements = []
    self.each_pair do |k,v|
      elements << "#{URI.escape(k.to_s)}=#{URI.escape(v.to_s)}"
    end
    elements.join('&')
  end

end


