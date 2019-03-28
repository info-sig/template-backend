require "minitest/autorun"
require "roda"
require "rack/test"
require 'sidekiq/testing'
require 'webmock/minitest'
# require 'vcr'
require_relative 'helpers/parallel_executor' if ENV['PARALLEL']

# Load the App in the appropriate ENV
ENV['RACK_ENV'] = 'test'

# Make sure we have enough redis connections
ENV['MAX_REDIS_CONNECTIONS'] ||= '50' # let richness be seen

require './config/environment.rb'
raise "don't want to run tests if DATABASE_URL is set, I'm scared to drop a production database" if ENV['DATABASE_URL']

ENV['INSTALLATION'] ||= 'Heroku'

# go to InfoSwitch#pci_dss? if you want to switch PCI DSS masking off in tests

class UnitTest < MiniTest::Spec

  require_relative "helpers/minitest_dyslexia_helper"
  include MinitestDyslexiaHelper
  require_relative "helpers/multi_threaded"
  include MultiThreaded

  make_my_diffs_pretty!

  def run(*args, &block)
    # Psql::Debug.dbg_disable_triggers

    # if Account.count > 0
      DB.tables.each{ |table| DB[table].truncate(cascade: true) if table != :schema_info }
    # end

    if multi_threaded?
      # printf "!"
      super
    else
      # printf ","
      Sequel::Model.db.transaction(:rollback=>:always, :auto_savepoint=>true) do
        # DB[:raw_messages].delete if DB[:raw_messages].count > 0 # hack hack hack: the raw messages get stored in a separate thread, this is a drkaround
        super
      end
    end
  end

  before do
    Thread.current[:test_run_uid] = @test_run_uid = self.class.to_s.underscore + "/" + name.gsub(/^test_[0-9]+_/, 'test_it_') + "/" + SecureRandom.hex

    WebMock.disable_net_connect!(allow_localhost: true, allow: 'jsecmodule.herokuapp.com')
    AppLogger.log_level = ENV['LOG_LEVEL'].try(:to_sym) || :error

    Sidekiq::Testing.fake!

    # TODO: extract me?
    $api_results = []
    $trx__test_interceptor__announced_hooks = {}
  end

  after do
    # VCR.eject_cassette
    Sidekiq::Worker.clear_all
    $pry = false

    $TEST_COMMIT_BLOCK_EXCEPTION = false
    Timecop.return
    $temp_upload_path = nil
    Thread.current[:skip_validation_throttling_in_tests] = true
  end

  def self.skip_stress_tests?
    ENV['SKIP_STRESS_TESTS'] || ENV['SKIP_SLOW_TESTS']
  end

  def pry!
    $pry = true
  end

  def join_messages *messages
    messages.compact.join(': ')
  end

  def trace_of_all_events scope = Event
    scope.all.map(&:pretty_trace).join("\n")
  end

  def reset_accounts!
    @accounts = nil
    DB[:accounts].delete
    DB[:transaction_orders].delete
    DB[:transactions].delete
    DB[:balances].delete
  end

  def self.do_jsecmodule_tests?
    if JsecModule.host =~ /localhost/
      true

    elsif JsecModule.host =~ /jsecmodule.herokuapp.com/
      if ENV['SKIP_SLOW_TESTS']
        false
      else
        true
      end

    else
      false

    end
  end

  def assert_equal_or_nil exp, act, msg = 'is bonky'
    if exp
      assert_equal exp, act, msg
    else
      assert_nil act, msg
    end
  end

  def capture_http_requests logid, url
    Thread.current["captured-requests/#{logid}"] = []
    stub_request(:any, %r{\A#{url}\z}).
      to_return do |request|
      Thread.current["captured-requests/#{logid}"] << request
      {
        body:   request.body,
        status: 200
      }
    end
  end

  def reset_captured_http_requests logid
    Thread.current["captured-requests/#{logid}"] = []
  end

  def captured_http_requests logid
    Thread.current["captured-requests/#{logid}"] ||= []
  end

  def reset_sequences
    # Psql.reset_sequence 'issued_cards_id_seq'
  end

  def exchange_factory options = {}
    @exchange = Exchange.upsert({name: 'test'}.merge(options))
  end

  def cryptocurrencies_factory
    Cryptocurrency.upsert(code: 'BTC', value_in_EUR: 7_150_00, volume_in_EUR: 1_750_250_343_00)
    20.times do |idx|
      Cryptocurrency.upsert(code: "CURRENCY-#{idx}", value_in_EUR: idx * 1_00, volume_in_EUR: idx * 1_000_00)
    end
  end

  # {:id=>271,
  #   :exchange=>"kucoin",
  #   :from=>"KCS",
  #   :to=>"USDT",
  #   :bid=>#<BigDecimal:4b02c38,'0.8050001E1',18(18)>,
  #     :ask=>#<BigDecimal:4b02b48,'0.8188998E1',18(18)>,
  #   :volume=>#<BigDecimal:4b02ad0,'0.71154841E5',18(18)>,
  #   :timestamp=>2018-01-31 17:53:48 +0100,
  #   :expires_at=>2018-01-31 18:53:48 +0100}
  def set_market_pair from, to, bid, ask, options = {}
    @market_pairs ||= []
    exchange = options.delete(:exchange) || @exchange
    volume = options.delete(:volume) || rand(373873878374)

    rv = MarketPair.set(
      exchange: exchange.name,
      from: from,
      to:   to,
      bid: bid,
      ask: ask,
      timestamp:  Time.now,
      ttl: 1.minute,
      volume: volume
    )

    @market_pairs << rv
    rv
  end

end


class IntegrationTest < UnitTest

  include Rack::Test::Methods

  OUTER_APP = Rack::Builder.parse_file('config.ru').first


  def app
    OUTER_APP
  end

  def request
    Rack::MockRequest.new(app)
  end


  private

  # extract me to a api-wide superclass/module
  def api_call path, request, options = {}
    raw_request = request.to_json
    authenticity_token = options[:authenticity_token] || request[:authenticity_token]

    headers = {}
    # it's actually a 'Authorization: ' header that gets mapped internally by rack to HTTP_AUTHORIZATION
    authorizer_helper_options = {}
    if options[:secret]
      authorizer_helper_options[:secret] = options[:secret]
      authorizer_helper_options[:authenticity_token] = authenticity_token
    end
    headers['HTTP_AUTHORIZATION'] = InfoSig::Authorizer.mock_authorization_header(authenticity_token, path, raw_request, authorizer_helper_options)

    response = post path, raw_request, headers

    rv = nil
    begin
      rv = JSON.parse(response.body)
    rescue Exception
      fail "expected to see a JSON body, got #{response.inspect}"
    end

    rv.symbolize_keys
  end

end

# Load the helpers
InfoSig.require_files "./test/helpers/*.rb"

# Load the module tests
InfoSig.require_files "./modules/*/test/test_helper.rb"

# Wipe the database before you start
DB.tables.each{ |table| DB[table].truncate(cascade: true) if table != :schema_info }

# Drop & Load PSQL
Psql::Dropper.call(false){ |sql| DB.execute sql }
Psql::Loader.call{ |sql| DB.execute sql }

# Check if we're at last migration
Sequel.extension :migration
Sequel::Migrator.check_current(DB, InfoSig.root+'/db/migrations')

# Set up mailer to test mode:
Mail.defaults do
  delivery_method :test
end

# Print statistics in the end
unless $PARALLEL_EXECUTION
  Minitest.after_run do
    puts
    # TODO: custom reporters
  end
end
