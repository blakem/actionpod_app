desc "Schedule a call between home and cell in 1 minute"
task :call_phones, [:event1_id, :event2_id, :event3_id, :event4_id, :event5_id] => :environment do |t, args|
  events = []
  if args[:event1_id] && args[:event2_id]
    event1 = Event.find(args[:event1_id].to_i)
    event2 = Event.find(args[:event2_id].to_i)
    events = [event1, event2]
    event3 = Event.find_by_id(args[:event3_id].to_i)
    events << event3 if event3
    event3 = Event.find_by_id(args[:event4_id].to_i)
    events << event4 if event4
    event3 = Event.find_by_id(args[:event5_id].to_i)
    events << event5 if event5
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
      events = [event1, event2]
    end
  end

  DelayedJob.where(:obj_jobtype => 'merge_calls_for_pool', :pool_id => events[0].pool.id).each { |dj| dj.destroy }
  
  run_time = Time.now + 1.minute
  run_time = run_time + 1.minute if run_time.min == 0
  events.each do |event|
    event.days = [run_time.wday]
    event.time = run_time.in_time_zone(event.user.time_zone).strftime("%I:%M%p")
    event.save
  end

  puts "Scheduled call for " + run_time.strftime("%I:%M%p")
end
