# Kynetx Endpoint Ruby Gem
The Kynetx Endpoint Gem was developed to allow developers of easily tie their existing or new ruby applications to the Kynetx Network System (KNS) and raise events on that platform.  The gem provides a simple DSL for raising (signaling) events on KNS.

## Example
    class TestEndpoint < Kynetx::Endpoint
      ruleset :a18x26
      domain :test_endpoint
      
      event :echo

      event :echo_hello  do |p|
        p[:message] = "Hello #{p[:message]}"
      end

      directive :say do |d|
        d[:message]
      end
    end

In the above example, a class is created which inherits from Kynetx::Endpoint.  This class can then be instantiated and used to signal events.  Like so:

    @endpoint = TestEndpoint.new
    @endpoint.signal(:echo, :message => "Hello World")

When the signal method is called, the echo event is raised and the "message" parameter is sent to the KNS event.  If that event sends a directive to "say", then the block provided to the :say directive is executed with "d" being a hash of the directive options.

The KRL for this endpoint looks like this:

    ruleset a18x26 {
      meta {
        name "Test Ruby Endpoint"
        description << Test Ruby Endpoint >>
        author "Michael Farmer"
        logging off
      }

      dispatch { }
      global { }

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
    }


## TODO
- Currently the endpoint doesn't support maintaining a user session.  This needs to be added to support entity variables in KRL.


## Links
- http://docs.kynetx.com/kns/kynetx-network-services-kns/#Event
- http://www.windley.com/archives/2010/06/a_big_programmable_event_loop_in_the_cloud.shtml

