require "heroku_backup_task"
require 'heroku_san/tasks'

desc "This task is called by the Heroku cron add-on"
task :cron => [:environment, :queueevents, :herokubackupdb, :clean_functional_testing_data]

desc "Queue up the scheduled events for the next 24 hours using delayed jobs"
task :queueevents => :environment do
  puts "Running EventQueuer at:       " + Time.now.to_s
  queue_rv = EventQueuer.new.queue_events(Time.now.utc)
  queue_rv.each do |hash|
    event = Event.find(hash[:obj_id])
    puts "  #{hash[:run_at]},#{hash[:run_at].in_time_zone('Pacific Time (US & Canada)')}: " +
         "#{hash[:id]} '#{event.user.name}' '#{event.name}' '#{hash[:obj_jobtype]}' '#{event.user.primary_phone.number}'"
  end
  puts "Finished queuing #{queue_rv.count} events at: " + Time.now.to_s
end

desc "Rotate the Heroku DB"
task :herokubackupdb => :environment do
  HerokuBackupTask.execute if Rails.env.production?
end

desc "Cleans up functional testing data"
task :clean_functional_testing_data
  user = User.find_by_email('blakem@blakem.com')
  user.conferences.each { |c| c.status='completed'; c.save } if user
end
