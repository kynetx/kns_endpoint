# Kynetx Endpoint Ruby Gem
The Kynetx Endpoint Gem was developed to allow developers of easily tie their existing or new ruby applications to the Kynetx Network System (KNS) and raise events on that platform.  The gem provides a simple DSL for raising (signaling) events on KNS.

## Installation
    gem install kns_endpoint

## Example
    class TestEndpoint < Kynetx::Endpoint
      ruleset :a18x26
      domain :test_endpoint
      
      event :echo

      event :echo_hello  do |p|
        p[:message] = "Hello #{p[:message]}"
      end

      event :write_entity_var
      event :read_entity_var

      directive :say do |d|
        d[:message]
      end
    end

In the above example, a class is created which inherits from Kynetx::Endpoint.  This class can then be use and used to signal events.  Like so:

    @endpoint = TestEndpoint.new
    # the new method also takes an options Hash that can be used to overwrite the defaults defined in the class. 
    # for example: 
    # {:ruleset => :a18x26, :environment => :development, :use_session => false}

    @endpoint.signal(:echo, :message => "Hello World") # => ["Hello World"]
    @endpoint.echo(:message => "Hello World")  # => ["Hello World"]

    # Events can also be called without instantiating the class, like so:
    TestEndpoint.signal(:echo, {:message => "Hello World"})  # => ["Hello World"]
    TestEndpoint.echo({:message => "Hello World"})  # => ["Hello World"]

    # if you wish to override the default class setup you can do so like so with an object:
    @endpoint.environment = :development
    @endpoint.ruleset = :a18x30
    @endpoint.echo({:message => "Hello World"}) # => ["DEVELOPMENT"]

    # if you don't have an object to call but are using the class, you can do this instead:
    TestEndpoint.ruleset :a18x30
    TestEndpoint.environment :development
    TestEndpoint.echo({:message => "Hello World"}) # => ["DEVELOPMENT"]

When the signal method is called, the echo event is raised and the "message" parameter is sent to the KNS event.  If that event sends a directive to "say", then the block provided to the :say directive is executed with "d" being a hash of the directive options. The signal method returns an array with the return values from each of the directive blocks.


The KRL for this endpoint looks like this:

    ruleset a18x26 {
      meta {
        name "Test Ruby Endpoint"
        description << Test Ruby Endpoint >>
        author "Michael Farmer"
        logging off
      }

      rule first_rule is active {
        select when test_endpoint echo
          pre {
            m = event:param("message");
          }
          {
            send_directive("say") with message = m;
          }
      }

      rule second_rule is active {
        select when test_endpoint echo_hello
          pre {
            m = event:param("message");
          }
          {
            send_directive("say") with message = m;
          }
      }

      rule third_rule is active {
        select when test_endpoint write_entity_var
          pre {
            m = event:param("message");
          }
          {
            noop();
          }
          fired {
            mark ent:message with m;
          }
          
      }
      

      rule fourth_rule is active {
        select when test_endpoint read_entity_var
          pre {
            m = current ent:message;
          }
          {
            send_directive("say") with message = m;  
          }
          
      }

    }

The other test krl used in the examples looks like this (note, the production version of this app returns "PRODUCTION"):
    ruleset a18x30 {
      meta {
        name "Testing Dev and Prod KNS Endpoint Gem"
        description <<
          Testing Dev and Prod KNS Endpoint Gem
        >>
        author "Michael Farmer"
        logging off
      }

      rule first_rule is active {
        select when test_endpoint echo
          {
            send_directive("say") with message = "DEVELOPMENT";
          }
      }
    } 


## Session Management
Sessions are also maintained through multiple calls to the KNS Event API so that entity variables can be maintained. So for the above example, you can perform the following:

    @endpoint = TestEndpoint.new(:ruleset => :a18x26)
    @endpoint.signal(:write_entity_var, :message => "Testing 123")
    @endpoint.signal(:read_entity_var) # => ["Testing 123"]

If you want to specify a session, you can do so by setting the session attribute manually:

    @endpoint.session = "3adef184a0779345fd422369a4e21a25"

If you want don't want to maintain session, you can turn it off:

    @endpoint.use_session = false

## Links
- http://docs.kynetx.com/kns/kynetx-network-services-kns/#Event
- http://www.windley.com/archives/2010/06/a_big_programmable_event_loop_in_the_cloud.shtml

