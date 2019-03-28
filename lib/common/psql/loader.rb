module Psql
  class Loader
    include Functional

    def call options = {}
      silent = options[:silent]

      Dir[InfoSig::Common.root + "/db/psql/*.sql"].sort.each do |sql_script_path|
        yield File.read(sql_script_path)
        puts "SUCCESS: #{File.basename(sql_script_path)} installed" unless silent
      end
    end

  end
end