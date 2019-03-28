require 'test_helpers'

if false

class EventTest < UnitTest

  class TestException < StandardError; end

  class MockRequest < OpenStruct; end

  setup do
    Thread.current[:skip_validation_throttling_in_tests] = false

    AppLogger.log_level = :silence
    @event_count = Event.count
    @e = begin
      raise TestException, "WIIIIII"
    rescue Exception => e
      e
    end
    @event = Event.exception(e)
  end

  it "does not fail when invalid data, response, exception and params are handled" do
    event = Event.new
    assert_equal Event::Request, event.request.class, "wrong class for Request"
    assert_equal Event::Data, event.data.class, "wrong class for Data"
    assert_equal Event::Backtrace, event.backtrace.class, "wrong class for Backtrace"

    assert_equal NilClass, event.data.params.class, "wrong class for params"
    event.data = {}.to_json
    event.data[:params] = [].to_json
    #assert_equal Array, event.data.params.class, "wrong class for params"
  end

  # describe "Event::Data::STANDARD_KEYS" do
  #   it "returns basic exception params" do
  #     assert_equal @event.data[:error], @event.error, "error message doesn't work"
  #   end
  # end

  describe "Event.pretty_trace" do
    it "doesn't break" do
      rv = nil
      silence_stream(STDOUT){ rv = @event.pretty_trace }
      assert rv.is_a?(String), "a string should have been traced"
    end
  end

  describe "Event.exception_in_controller" do
    setup do
      @tempfile = Tempfile.new('test')
      @request = MockRequest.new(
        url: 'url',
        path: 'path',
        format: 'format',
        remote_ip: '66.66.66.66',
        env: { 'a' => 'b' }
      )
    end

    it "logs an event like in the controller" do
      @event = Event.exception_in_controller(@e, {param: 'param'}, @request)
      data = @event.data
      params    = data.params

      assert_equal(@request.url, @event.request_url, "request_url is bad")
      assert_equal(@request.path, @event.request_path, "request_path is bad")
      assert_equal(@request.format, @event.request_format, "request_format is bad")
      assert_equal(@request.remote_ip, @event.request_remote_ip, "request_remote_ip is bad")


      assert_equal("{\"param\":\"param\"}", data[:params],  "params is bad in #{data}")
      assert_equal({"param" => "param"}, params,  "params is parsed badly in #{data}")

      # TODO: REQUEST OBJECT IS CURSED
      # assert_equal(TRC::Event::Request.new(@request.env), request_env, "request is bad")

      assert_equal 2, new_events_count, "event count is off"
    end

    it "dumps params even when funny UTF8" do
      @event = Event.exception_in_controller(@e, {'a' => "\u262E".force_encoding('ASCII-8BIT')}, @request)

      assert_equal 2, new_events_count, 'wrong number of exceptions in the DB'
    end

    it "logs an event and doesn't break if an event is undumpable" do
      @request.env = {'a' => Module.new}
      @event = Event.exception_in_controller(@e, {'a' => Module.new}, @request)

      data = @event.data
      params    = data.params
      request_env   = @event.request

      assert_equal(@request.url, @event.request_url, "request_url is bad")
      assert_equal(@request.path, @event.request_path, "request_path is bad")
      assert_equal(@request.format, @event.request_format, "request_format is bad")
      assert_equal(@request.remote_ip, @event.request_remote_ip, "request_remote_ip is bad")

      # TODO: different behavior between Rails & Non-Rails
      # assert_equal("{\"a\":{}}", data[:params],  "params is bad in #{data}")
      # assert_equal({"a"=>{}}, params,  "params is parsed badly in #{data}")

      # TODO: REQUEST OBJECT IS CURSED
      # assert_equal({"a"=>{}},     request_env, "request is bad")

      # hmf nothing breaks, increase this if yu manage to get this scenario to go bad
      assert_equal 2, new_events_count, "event count is off"
    end

    teardown do
      @tempfile.close
    end
  end

  describe "Event#exception" do
    setup do
      @event = Event.exception @e, {happyness: 'life'}
      Timecop.travel 2
      @event2 = Event.exception @e, {happyness: 'life'}
    end

    it "events the exception well" do
      data = @event.data

      assert_equal @e.class.to_s, @event.error_class,   "error_class is bad"
      assert_equal @e.message,    @event.error_message, "error_message is bad"

      assert_equal Event::Backtrace, @event.backtrace.class, "backtrace #{@event.backtrace.inspect} is bad"
      assert @event.backtrace.count > 0,
        "backtrace is not conserved is #{@event.backtrace.inspect}"

      assert_equal 3, new_events_count, "event count is off"
    end

    it "logs backtrace hash in a sane way" do
      assert_equal 40, @event.backtrace_hash.length, "backtrace hash looks funny #{@event.backtrace_hash}"
      assert_equal @event.backtrace_hash, @event2.backtrace_hash,
        "two exceptions with same backtraces should have same hashes"
    end

    it "logs optional parameters" do
      assert_equal "life", @event.data[:happyness]
    end

    it "does not go wacky with a funny exception object" do
      event = Event.exception "Mirko pazi metaK!"
      assert_equal 5, new_events_count, "events count is off"
    end

    it "does not go wacky with a funny options object" do
      AppLogger.log_level = :error
      assert_output(/error/) do
        event = Event.exception "Mirko pazi metaK!", "Hvala Slavko!"
      end
      assert_equal 4, new_events_count, "1 dummy event record"
    end
  end

  describe "Event.trace_exception" do
    setup do
      AppLogger.log_level = :error
    end

    it "does not break with a funny exception object" do
      assert_output(/wiiii :D :D/) do
        Event.trace_exception "wiiii :D :D"
      end
    end
  end

  describe "Event throttler" do

    it "it does not allow same exception within 2 seconds" do
      Timecop.freeze
      e1 = Event.exception @e; e2 = Event.exception @e
      refute e1.new?, 'e1 should be persisted'
      refute e2, 'e2 should NOT exist'
    end

    it "allows same exceptions 2 seconds apart" do
      e1 = Event.exception @e; Timecop.travel(2); e2 = Event.exception @e
      refute e1.new?, 'e1 should be persisted'
      refute e2.new?, 'e2 should be persisted'
    end

  end

  describe "Event.log_and_..." do

    it "goes" do
      event = Event.log_and_go(answer: 42) do
        raise @e
      end
      assert event.is_a?(Event), "event should be a Event"
      assert event.backtrace.first =~ /event_test/, "backtrace is bad"
      assert_equal 2, new_events_count, "event count is off"
    end

    it "raises" do
      assert_raise TestException do
        Event.log_and_raise(answer: 42) do
          raise @e
        end
      end
      assert_equal 2, new_events_count, "event count is off"
    end

  end

  def new_events_count
    Event.count - @event_count
  end

  # this method disappeared from Kernel at one point, and I added it here in this test
  # if funny stuff happens, remove this method and try again
  def silence_stream(stream)
    old_stream = stream.dup
    stream.reopen(RUBY_PLATFORM =~ /mswin/ ? 'NUL:' : '/dev/null')
    stream.sync = true
    yield
  ensure
    stream.reopen(old_stream)
  end

end


end
