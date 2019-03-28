module Psql
  class Dropper
    include Functional

    def call simulation = true, &block
      # 1. at least try to make sure we have the latest PSQL code in, that drops things nicely
      log_and_go { Psql::Loader.call(silent: true, &block) }

      # 2. drop it
      # rv1 = block.call "SELECT adm_drop_triggers();"
      # rv2 = block.call "SELECT adm_drop_functions(#{simulation.to_s});"

      # 3. announce it
      # puts "Dropped functions: #{rv1.inspect}"
      # puts "Dropped functions: #{rv2.inspect}"
    end


    private

    def log_and_go
      yield
    rescue Exception => e
      warn "Warning: #{e.class} #{e.message}".gsub("\n", ' ')
      nil
    end

  end

end