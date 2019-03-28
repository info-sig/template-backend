require 'dotenv'
Dotenv.load

workers_count = Integer(ENV['MAX_PROCESSES'] || 1)
workers workers_count unless defined?(JRUBY_VERSION)
threads_count = Integer(ENV['MAX_THREADS'] || 1)
threads threads_count, threads_count

preload_app!

rackup      DefaultRackup
port        ENV['PORT']     || 3000
environment ENV['RACK_ENV'] || 'development'


if !defined?(JRUBY_VERSION) && (workers_count > 1 || ENV['RACK_ENV'] == 'production')

  before_fork do
    Sequel::Model.db.disconnect
  end

  on_worker_boot do
    defined?(Sequel::Model) and
      Sequel::Model.db.connect(ENV['DATABASE_URL'] || throw("define a DATABASE_URL environment variable"))
  end

end
