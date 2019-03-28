# Hmf, https://github.com/info-sig/InfoSwitch/issues/130
require_relative 'set_rack_env_and_load_gems'

# logging section
$stdout.sync = true
require_relative '../app/base/app_logger'
AppLogger.log_level = ENV['LOG_LEVEL'].try(:to_sym) || :debug

# load initializers in alphabetical order
Dir["./config/initializers/*.rb"].sort.each {|file| require file }

# load libraries
Dir["./lib/*.rb"].sort.each {|file| require file }

# load application base
InfoSig.require_files "./app/base/*.rb"

# load models
unless $migrations_running
  InfoSig.require_files "./app/models/**/*.rb"

  # load apis...
  # InfoSig.require_files "./app/api_v10/acts_as_api.rb"
  # InfoSig.require_files "./app/api_v10/*.rb"

  # load the module(s)
  Dir["./modules/*/environment.rb"].sort.each {|file| require file }
end

require_relative "redis_and_sidekiq"

# TODO: extract me so I'm only in the web process!
require 'sidekiq/web'
require 'sidekiq-scheduler/web'
