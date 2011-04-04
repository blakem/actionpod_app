desc "This task is called by the Heroku cron add-on"
task :cron => :environment do
  puts "Running Cron at: " + Time.now.to_s
  count = EventQueuer.new.queue_events(Time.now.utc)
  puts "Cron Finished queuing #{count} events at: " + Time.now.to_s
end