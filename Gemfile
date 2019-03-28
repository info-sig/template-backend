source "https://rubygems.org"

ruby '2.6.0'

gem 'puma'
gem 'roda'
gem 'roda-basic-auth'
gem 'nokogiri'
gem 'faraday'
gem 'json'
gem 'dotenv'
gem 'dry-types'
gem 'dry-struct'
gem 'activesupport', require: false
gem 'sequel'
gem 'mail'
gem 'pry', require: false
gem 'pg'
gem 'oj' # optimized json
gem 'rake'

# Future, functions, ...
gem 'ramda-ruby'
gem 'concurrent-ruby'
gem 'concurrent-ruby-ext'

# For redis, redis locking etc
gem 'redlock'
gem 'redis'
gem 'connection_pool'

# Sidekiq is not requirable via Bundler: https://github.com/info-sig/InfoSwitch/issues/212
gem 'sidekiq', require: false
gem 'sidekiq-scheduler', require: false

# Bread & Butter
gem 'selenium-webdriver'

group :development, :test do
  gem 'foreman', require: false
  gem 'ruby-prof' unless defined?(JRUBY_VERSION)
end

group :test do
  gem 'minitest'
  gem 'minitest-parallel_fork', require: false
  gem 'rack-test'
  gem "webmock"
  # gem 'vcr'
  gem 'm', '~> 1.5.0'
  gem 'timecop'
end
