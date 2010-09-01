require '../lib/endpoint'
describe Kynetx::Endpoint do

  before :all do
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

    @endpoint = TestEndpoint.new
  end

  it "should set use_single_session to true by default" do
    @endpoint.use_single_session.should == true
  end

  it "event should run a simple rule" do
    @endpoint.signal(:echo, :message => "Hello World").should include("Hello World")
  end

  it "event should take a block" do
    @endpoint.signal(:echo_hello, :message => "World").should include("Hello World")
  end

  it "should set a session entity variable and keep it over multiple signals" do
    @endpoint.signal(:write_entity_var, :message => "Testing 123")
    @endpoint.signal(:read_entity_var, {}).should include "Testing 123"
  end

  it "should maintain a session for multiple calls" do
    @endpoint.use_single_session = true
    session = "3adef184a0779345fd422369a4e21a25"
    @endpoint.session = session

    @endpoint.signal(:read_entity_var)
    @endpoint.session.should eql session

    @endpoint.signal(:read_entity_var, {})
    @endpoint.session.should eql session

  end

  it "should get a new session every time if @@use_single_session is false" do
    @endpoint.session = nil
    @endpoint.use_single_session = false

    @endpoint.signal(:read_entity_var, {})
    session = @endpoint.session

    @endpoint.signal(:read_entity_var, {})
    @endpoint.session.should_not eql session

  end


end
