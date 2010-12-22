require 'lib/kns_endpoint'


describe Kynetx::Endpoint do

  before :all do
    class TestEndpoint < Kynetx::Endpoint
      domain :test_endpoint
      ruleset :a18x26
   
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

    @endpoint = TestEndpoint.new
  end

  it "should set defaults" do
    @endpoint.use_session.should == true
    @endpoint.ruleset.should == :a18x26
    @endpoint.environment.should == :production
  end

  it "event should run a simple rule" do
    @endpoint.signal(:echo, :message => "Hello World")
    @endpoint.signal(:echo, :message => "Hello World").should include("Hello World")
  end

  it "event should take a block" do
    @endpoint.signal(:echo_hello, :message => "World").should include("Hello World")
  end

  it "should set a session entity variable and keep it over multiple signals" do
    @endpoint.signal(:write_entity_var, :message => "Testing 123")
    @endpoint.signal(:read_entity_var).should include "Testing 123"
  end

  it "should maintain a session for multiple calls" do
    #$KNS_ENDPOINT_DEBUG = true
    #@endpoint.logging = true

    @endpoint.use_session = true
    session = nil

    @endpoint.signal(:read_entity_var)
    session = @endpoint.session

    @endpoint.signal(:read_entity_var)
    @endpoint.session.should eql session

    @endpoint.signal(:read_entity_var)
    @endpoint.session.should eql session
    #@endpoint.logging = false
    #$KNS_ENDPOINT_DEBUG = false
  end

  it "should get a new session every time if @@use_session is false" do
    @endpoint.session = nil
    @endpoint.use_session = false

    @endpoint.signal(:read_entity_var)
    session = @endpoint.session

    @endpoint.signal(:read_entity_var)
    @endpoint.session.should_not eql session
  end

  it "should allow me to call events as methods." do
    @endpoint.echo(:message => "Hello World").should include "Hello World"
  end

  it "should allow me to raise an event without instantiation." do
    TestEndpoint.echo(:message => "Hello World").should include "Hello World"
  end

  it "should allow me to call signal without instantiation" do
    TestEndpoint.signal(:echo, {:message => "Hello World"})
  end
   
  it "should allow me to raise an event without instantition if the ruleset is defined." do
    TestEndpoint.echo({:message => "Hello World"}).should include "Hello World"
  end

  it "should call the development version of the app" do
    @dev_endpoint = TestEndpoint.new(:ruleset => :a18x30)
    @dev_endpoint.echo({:message => "Hello World"}).should include "PRODUCTION"

    @dev_endpoint.environment = :development
    @dev_endpoint.echo({:message => "Hello World"}).should include "DEVELOPMENT"
  end

  it "should allow me to pass environment as an option when calling the endpoint as a class" do
    # In order to do this you have to access the DSL directly and 
    # overwrite the )efaults. In this case, ruleset and environment.
    TestEndpoint.ruleset :a18x30
    TestEndpoint.environment :development
    TestEndpoint.echo({:message => "Hello World"}).should include "DEVELOPMENT"
  end

  it "should allow me to call the event from the class without any params" do
    TestEndpoint.ruleset :a18x30
    TestEndpoint.echo.should include "DEVELOPMENT"
  end

  it "should capture the logging output if logging is turned on" do
    @endpoint.logging = true
    @endpoint.echo(:message => "Hello World").should include "Hello World"
    @endpoint.log.should be_kind_of Array
    @endpoint.log.should_not be_empty
  end
  

  it "should expose the headers for modification" do
    @endpoint.headers = {"User-Agent" => "Ruby"}
    @endpoint.use_session = true
    @endpoint.echo(:message => "Hello World").should include "Hello World"

    @endpoint.headers[:cookies].should_not be_nil
    @endpoint.headers["User-Agent"].should == "Ruby"

  end
end
