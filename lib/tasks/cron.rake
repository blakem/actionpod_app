require "heroku_backup_task"

desc "This task is called by the Heroku cron add-on"
task :cron => :environment do
  puts "Running Cron at: " + Time.now.to_s
  queue_rv = EventQueuer.new.queue_events(Time.now.utc)
  queue_rv.each do |hash|
    event = Event.find(hash[:obj_id])
    puts "  #{hash[:run_at]},#{hash[:run_at].in_time_zone('Pacific Time (US & Canada)')}: " +
         "#{hash[:id]} '#{event.user.name}' '#{event.name}' '#{hash[:obj_jobtype]}' '#{event.user.primary_phone}'"
  end
  puts "Cron Finished queuing #{queue_rv.count} events at: " + Time.now.to_s

  HerokuBackupTask.execute if Rails.env.production?
end