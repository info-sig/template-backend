def without_sequel_logging
  loggers = DB.loggers
  DB.loggers = []
  yield
ensure
  DB.loggers = loggers
end

namespace :db do

  task :migrations_environment do
    $migrations_running = true
    Rake::Task["environment"].invoke

    DB.loggers << Logger.new($stdout)
    Sequel.extension :migration
    DB.extension :schema_dumper
  end

  desc "Run migrations"
  task :migrate, [:version] => :migrations_environment do |t, args|
    if args[:version]
      puts "Migrating to version #{args[:version]}"
      Sequel::Migrator.run(DB, InfoSig.root+"/db/migrations", target: args[:version].to_i)
    else
      puts "Migrating to latest"
      Sequel::Migrator.run(DB, InfoSig.root+"/db/migrations")
    end

    Rake::Task["db:schema:dump"].invoke
  end

  namespace :schema do

    task :dump => :migrations_environment do
      schema = without_sequel_logging{ DB.dump_schema_migration }
      File.open(InfoSig.root+"/db/schema.rb", 'w') {|f| f.write(schema) }
    end

    # does not work and is not intended to work:
    #    https://stackoverflow.com/questions/48299054/rake-dbschemadump-and-rake-dbschemaload-equivalent-in-sequel/48304704#48304704
    #
    # task :load => :migrations_environment do
    #   Sequel::Migrator.run(DB, InfoSig.root+"/db/schema.rb")
    # end

  end

  task :seed => :environment do
    InfoSig.require_files "./db/seed.rb"
    Seed.call
  end

  desc "Drops the database, recreates it, and runs seeds"
  task :setup => :environment do
    # Drop
    without_sequel_logging do
      Rake::Task["db:migrate"].invoke(0)
    end

    # Migrate
    Rake::Task["db:migrate"].reenable
    Rake::Task["db:migrate"].invoke

    # Seed
    without_sequel_logging do
      Rake::Task["db:seed"].invoke
    end
  end

end
