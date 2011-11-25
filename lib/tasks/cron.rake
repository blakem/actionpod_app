require "heroku_backup_task"
require 'heroku_san/tasks'

desc "This task is called by the Heroku cron add-on"
task :cron => [:environment, :queueevents, :herokubackupdb, :clean_functional_testing_data, :schedule_emails]

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
task :clean_functional_testing_data => :environment do
  user = User.find_by_email('blakem@blakem.com')
  user.conferences.select { |c| c.status == 'in_progress' }.map { |c| c.status = 'completed'; c.save } if user
end

desc "Schedules Emails to Members"
task :schedule_emails => :environment do
  member_tracker = MemberTracker.new
  date = next_time_offset_by(8.hours)

  # if [1,2,3,4,5].include?(date.wday)
  #   member_tracker.delay(
  #     :run_at => date - 5.minutes, 
  #     :obj_jobtype => 'send_team_focus_email',
  #   ).send_team_focus_email(date)
  # end

  member_tracker.delay(
    :run_at => next_time_offset_by(10.hours + 30.minutes),
    :obj_jobtype => 'contact_stranded_users'
  ).contact_stranded_members
end

def next_time_offset_by(offset)
  date = Time.now.in_time_zone('Pacific Time (US & Canada)').beginning_of_day + offset
  date = date + 1.day if date < Time.now
  date
end