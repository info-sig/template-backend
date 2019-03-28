namespace :db do

  # Rake::Task["db:run_importers"].invoke
  task :setup_all do
    Rake::Task["db:setup"].invoke
    Rake::Task["db:run_importers"].invoke
  end

  task :run_importers => :environment do
    importers = ExchangeApi.implementations.map do |exchange_api_class|
      [
        exchange_api_class,
        Concurrent::Future.execute{ exchange_api_class.import_pairs }
      ]
    end

    importers.each do |i|
      klass, future = i
      future.value
      if future.rejected?
        puts "#{klass} failed with #{future.exception}"
      end
    end
  end

  desc "ques importers into sidekiq"
  task :import_async => :environment do
    ExchangeApi::ImportPairs::AllViaSidekiq.perform_async
  end

end
