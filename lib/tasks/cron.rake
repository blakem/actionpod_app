desc "This task is called by the Heroku cron add-on"
task :cron => :environment do
  puts "Running Cron at: " + Time.now.to_s
  if Time.now.hour % 4 == 0 # run every four hours
    puts "Every Four Hours?"
  end

  if Time.now.hour == 0 # run at midnight
    puts "Run at midnight?"
  end
end