# Quiet some warnings we see when running in warning mode:
# RUBYOPT=-w bundle exec sidekiq
$TESTING = false

require_relative 'set_rack_env_and_load_gems'

class SidekiqRunner

  attr_accessor :pids

  def initialize
    @hostname = `hostname`.strip
    @process_count = Integer(ENV['SIDEKIQ_PROCESSES'] || 1)
  end

  def run
    notice "Firing up #{@process_count} child processes"
    @pids = Concurrent::Array.new(
      @process_count.times.map do |process_id|
        fork_child process_id
      end
    )
    @running = true

    run_the_children_keepalive_thread

    # we'll kill children in the end of the happy path, but we really need them dead in +every+ case
    at_exit{ wait_for_children_death }
    Signal.trap('INT')  { throw :sigint }
    Signal.trap('TERM') { throw :sigint }

    catch(:sigint) do
      while(@running)
        Process.wait
        sleep 1
      end
    end

    wait_for_children_death
  end


  private

  def run_the_children_keepalive_thread
    @children_keepalive_thread =
      Thread.new do
        while @running
          begin
            pids.each_with_index do |pid, process_id|
              pid_active = Process.kill(0, pid) rescue nil
              next if pid_active

              notice "#{process_id} with pid #{pid} died, restarting"
              pids[process_id] = fork_child(process_id)
            end
            sleep 1

          rescue => e
            error "Sidekiq spawner, keep-alive thread: #{e}"
            error e.message
            error e.backtrace.join("\n")

          end
        end

      end
  end

  def fork_child process_id
    pid = Process.fork do
      $MASTER_SIDEKIQ_PROCESS = true if process_id == 0 && ENV['PRIMARY_NODE']

      begin
        require 'sidekiq/cli'

        args = build_argv(process_id)
        notice "Sidekiq spawner, process #{process_id}: #{args} #{$MASTER_SIDEKIQ_PROCESS ? 'MASTER' : ''}"
        cli = Sidekiq::CLI.instance
        cli.parse(args)
        cli.run

      rescue => e
        error "Sidekiq spawner, process #{process_id}: #{e}"
        error e.message
        error e.backtrace.join("\n")
        error "Sidekiq spawner, process #{process_id}: exit 1"
        Kernel.exit!(1)

      ensure
        notice "Sidekiq spawner, process #{process_id}: exit 0"
        Kernel.exit!(0)

      end
    end

    pid
  end

  def active_pids
    pids.map{|pid| (Process.kill(0, pid) && pid) rescue nil}.compact
  end

  # -c, --concurrency INT            processor threads to use
  # -d, --daemon                     Daemonize process
  # -e, --environment ENV            Application environment
  # -g, --tag TAG                    Process tag for procline
  # -i, --index INT                  unique process index on this machine
  # -q, --queue QUEUE[,WEIGHT]       Queues to process with optional weights
  # -r, --require [PATH|DIR]         Location of Rails application with workers or file to require
  # -t, --timeout NUM                Shutdown timeout
  # -v, --verbose                    Print more verbose output
  # -C, --config PATH                path to YAML config file
  # -L, --logfile PATH               path to writable logfile
  # -P, --pidfile PATH               path to pidfile
  # -V, --version                    Print version and exit
  # -h, --help                       Show help
  def build_argv(process_id)
    tag = APPLICATION_NAME
    tag += " MASTER" if master_process?

    [
      # -r, --require [PATH|DIR]         Location of Rails application with workers or file to require
      "-r", "./config/environment.rb",
      # -e, --environment ENV            Application environment
      "-e", RACK_ENV.to_s,
      # -P, --pidfile PATH               path to pidfile
      "-P", "tmp/pids/sidekiq_#{process_id}",
      # -i, --index INT                  unique process index on this machine
      "-i", process_id.to_s,
      # -g, --tag TAG                    Process tag for procline
      "-g", tag,
    ] +
      # -q, --queue QUEUE[,WEIGHT]       Queues to process with optional weights
      [
        "-q", "#{@hostname},7",
        "-q", "import_market_pairs,3",
        "-q", "default,3"
      ]
  end

  def master_process?
    $MASTER_SIDEKIQ_PROCESS
  end

  def wait_for_children_death
    notice "Waiting for children to die..."
    @running = false

    # just in case
    pids.each{ Process.kill('SIGTERM', pid) rescue nil }

    Timeout.timeout(30) do
      notice "Active PIDs: #{active_pids}"

      # make sure we tell the OS we want to know what's up with the children
      active_pids.each{|pid| Process.wait(pid) rescue nil }
    end

    pids.map{|pid| (Process.kill(0, pid) && pid) rescue nil}.compact
    return if active_pids.empty?

    # any remaining living children need to DIE
    error "timeout exceeded, killing remaining children: #{active_pids}"
    active_pids.each{ Process.kill('SIGKILL', pid) rescue nil }
  end

  def notice str
    STDOUT.puts "#{Process.pid} #{str}"
  end

  def error str
    STDERR.puts "#{Process.pid} #{str}"
  end

end

class JRubySidekiqRunner

  def initialize
    @hostname = `hostname`.strip
  end

  def run
    notice "Firing up sidekiq"
    require 'sidekiq/cli'

    $MASTER_SIDEKIQ_PROCESS = true if ENV['PRIMARY_NODE']

    begin
      args = build_argv
      notice "Sidekiq spawner: #{args} #{$MASTER_SIDEKIQ_PROCESS ? 'MASTER' : ''}"
      cli = Sidekiq::CLI.instance
      cli.parse(args)
      cli.run
    rescue => e
      error "Sidekiq spawner: #{e}"
      error e.message
      error e.backtrace.join("\n")
      error "Sidekiq spawner: exit 1"
      Kernel.exit!(1)

    ensure
      notice "Sidekiq spawner: exit 0"
      Kernel.exit!(0)

    end
  end


  private

  # -c, --concurrency INT            processor threads to use
  # -d, --daemon                     Daemonize process
  # -e, --environment ENV            Application environment
  # -g, --tag TAG                    Process tag for procline
  # -i, --index INT                  unique process index on this machine
  # -q, --queue QUEUE[,WEIGHT]       Queues to process with optional weights
  # -r, --require [PATH|DIR]         Location of Rails application with workers or file to require
  # -t, --timeout NUM                Shutdown timeout
  # -v, --verbose                    Print more verbose output
  # -C, --config PATH                path to YAML config file
  # -L, --logfile PATH               path to writable logfile
  # -P, --pidfile PATH               path to pidfile
  # -V, --version                    Print version and exit
  # -h, --help                       Show help
  def build_argv
    tag = APPLICATION_NAME
    tag += " MASTER" if master_process?
    process_id = 0

    [
      # -r, --require [PATH|DIR]         Location of Rails application with workers or file to require
      "-r", "./config/environment.rb",
      # -e, --environment ENV            Application environment
      "-e", RACK_ENV.to_s,
      # -P, --pidfile PATH               path to pidfile
      "-P", "tmp/pids/sidekiq_#{process_id}",
      # -i, --index INT                  unique process index on this machine
      "-i", process_id.to_s,
      # -g, --tag TAG                    Process tag for procline
      "-g", tag,
    ] +
      # -q, --queue QUEUE[,WEIGHT]       Queues to process with optional weights
      [
        "-q", "#{@hostname},7",
        "-q", "import_market_pairs,3",
        "-q", "default,3"
      ]
  end

  def master_process?
    $MASTER_SIDEKIQ_PROCESS
  end

  def notice str
    STDOUT.puts "#{Process.pid} #{str}"
  end

  def error str
    STDERR.puts "#{Process.pid} #{str}"
  end

end

if defined?(JRUBY_VERSION)
  @runner = JRubySidekiqRunner.new
  @runner.run
else
  @runner = SidekiqRunner.new
  @runner.run
end

