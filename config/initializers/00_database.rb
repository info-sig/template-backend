require 'sequel/connection_pool/threaded'

opts = {}
if ENV['PSQL_DEBUG']
  opts.merge!(
    notice_receiver: proc{|r| DB.log_info r.try(:result_error_message).try(:split, "\n").try(:first)},
    client_min_messages: :notice
  )
end

if RACK_ENV.to_s == 'test'
  opts.merge!(
    :max_connections => 90
  )
end

if Sidekiq.server?
  opts.merge!(
    :max_connections => ( ENV['MAX_WORKER_THREADS']*10 || 4 ).to_i + 1
  )

else
  opts.merge!(
    :max_connections => ( ENV['MAX_THREADS'] || 1 ).to_i + 1
  )

end

puts "CONNECTING TO #{RACK_ENV}"
default_db = "postgres://test:test@127.0.0.1:5432/__my_app___#{RACK_ENV}"
DB = Sequel.connect(
  ENV['JRUBY_DATABASE_URL'] || ENV['DATABASE_URL'] || default_db,
  opts
)

Sequel.extension :core_extensions
Sequel.extension :pg_json
Sequel.extension :pg_json_ops

DB.extension(:pagination)
DB.extension(:connection_validator)

# PSQL stuff:
# DB.extension(:pg_array, :pg_row)

# FIXME: -1 means that connections will be validated every time, which avoids errors
# when databases are restarted and connections are killed.  This has a performance
# penalty, so consider increasing this timeout if building a frequently accessed service.
DB.pool.connection_validation_timeout = 30

Sequel::Model.plugin :timestamps, update_on_create: true

if ENV['SQL_LOGGING']
  DB.loggers << Logger.new($stdout)
end
