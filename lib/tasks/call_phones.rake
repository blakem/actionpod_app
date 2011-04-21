desc "Schedule a call between home and cell in 1 minute"
task :call_phones, [:event1_id, :event2_id] => :environment do |t, args|
  if args[:event1_id] && args[:event2_id]
    event1 = Event.find(args[:event1_id].to_i)
    event2 = Event.find(args[:event2_id].to_i)
  else
    user1 = User.find_by_email('blakem@15minutecalls.com')
    user2 = User.find_by_email('blakem@blakem.com')
    unless (user1 and user2)
      puts "Oops.... Couldn't find users"
      exit
    else
      event1 = Event.find_by_name_and_user_id('With Home', user1.id)
      event2 = Event.find_by_name_and_user_id('With Cell', user2.id)
      if event1.nil?
        event1 = Event.create(:name => 'With Home', :user_id => user1.id, :pool_id => Pool.find_by_name('Default Pool'))
      end
      if event2.nil?
        event2 = Event.create(:name => 'With Cell', :user_id => user2.id, :pool_id => Pool.find_by_name('Default Pool'))
      end
    end
  end
  event1.days = [0,1,2,3,4,5,6]
  event2.days = [0,1,2,3,4,5,6]

  run_time = Time.now + 1.minute
  event1.time = run_time.in_time_zone(user1.time_zone).strftime("%I:%M%p")
  if event1.minute_of_hour == 0
    run_time = run_time + 1.minute
    event1.time = run_time.in_time_zone(user1.time_zone).strftime("%I:%M%p")
  end
  event2.time = run_time.in_time_zone(user2.time_zone).strftime("%I:%M%p")

  DelayedJob.where(:obj_jobtype => 'merge_calls_for_pool', :pool_id => event1.pool.id).each { |dj| dj.destroy }

  event1.save
  event2.save

  puts "Scheduled call for " + run_time.strftime("%I:%M%p")
end
