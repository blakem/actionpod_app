desc "Schedule a call between home and cell in 1 minute"
task :call_phones => :environment do
  user1 = User.find_by_email('blakem30@yahoo.com')
  user2 = User.find_by_email('blakem@blakem.com')
  if (user1 and user2)
    event1 = Event.find_by_name_and_user_id('With Home', user1.id)
    event2 = Event.find_by_name_and_user_id('With Cell', user2.id)
    if event1.nil?
      Event.create(:name => 'With Home', :user_id => user1.id, :pool_id => Pool.find_by_name('Default Pool'))
    end
    if event2.nil?
      Event.create(:name => 'With Cell', :user_id => user2.id, :pool_id => Pool.find_by_name('Default Pool'))
    end
    event1.days = [0,1,2,3,4,5,6]
    event2.days = [0,1,2,3,4,5,6]
  
    run_time = Time.now + 1.minute
    event1.time = run_time.in_time_zone(user1.time_zone).strftime("%I:%M%p")
    event2.time = run_time.in_time_zone(user2.time_zone).strftime("%I:%M%p")

    DelayedJob.where(:obj_jobtype => 'merge_calls_for_pool', :obj_id => user1.pool.id).all { |dj| dj.destroy }
  
    event1.save
    event2.save
    
    puts "Scheduled call for " + run_time.strftime("%I:%M%p")
  else
    puts "Oops.... Couldn't find users"
  end
end
