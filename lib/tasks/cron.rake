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
  user1 = User.find_by_email('blakem@15minutecalls.com')
  user2 = User.find_by_email('tommy2hats@gmail.com')
  user3 = User.find_by_email('damian@damiansol.com')
  user4 = User.find_by_email('touchbrian@gmail.com')
  date = Time.now.in_time_zone('Pacific Time (US & Canada)').beginning_of_day + 8.hours
  date = date + 1.day if date < Time.now
  if [1,2,3,4,5].include?(date.wday)
    date_string = date.strftime("%A, %B #{date.day.ordinalize}")  
    UserMailer.delay(:run_at => date - 5.minutes, :obj_jobtype => 'deliver_conference_email').deliver_conference_email(
      user1, 
      [user1, user2, user3, user4], 
      "Team Focus Lists for #{date_string}",
      'deltachallenge-team-focus@googlegroups.com'
    )
  end
  date = date.beginning_of_day + 11.hours
  MemberTracker.new.delay(:run_at => date, :obj_jobtype => 'contact_stranded_users').contact_stranded_members
end