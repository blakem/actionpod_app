desc "Schedule a call between home and cell in 1 minute"
task :call_phones, [:event1_id, :event2_id, :event3_id, :event4_id, :event5_id] => :environment do |t, args|
  events = []
  if args[:event1_id] && !args[:event2_id]
    event = Event.find(args[:event1_id])
    event.make_call(Time.now.utc)
    user = event.user
    puts "Calling #{user.name} at #{user.primary_phone.number}..."
  else
    if args[:event1_id] && args[:event2_id]
      event1 = Event.find(args[:event1_id].to_i)
      event2 = Event.find(args[:event2_id].to_i)
      events = [event1, event2]
      event3 = Event.find_by_id(args[:event3_id].to_i)
      events << event3 if event3
      event4 = Event.find_by_id(args[:event4_id].to_i)
      events << event4 if event4
      event5 = Event.find_by_id(args[:event5_id].to_i)
      events << event5 if event5
    else
      user1 = User.find_by_email('blakem@15minutecalls.com')
      user2 = User.find_by_email('blakem@blakem.com')
      unless (user1 and user2)
        puts "Oops.... Couldn't find users"
        exit
      else
        pool = Pool.find_by_name('Testing Pool')
        event1 = Event.find_by_name_and_user_id_and_pool_id('With Home', user1.id, pool.id)
        event2 = Event.find_by_name_and_user_id_and_pool_id('With Cell', user2.id, pool.id)
        if event1.nil?
          event1 = Event.create!(:name => 'With Home', :user_id => user1.id, :pool_id => pool.id)
        end
        if event2.nil?
          event2 = Event.create!(:name => 'With Cell', :user_id => user2.id, :pool_id => pool.id)
        end
        events = [event1, event2]
      end
    end

    DelayedJob.where(:obj_jobtype => 'merge_calls_for_pool', :pool_id => events[0].pool.id).each { |dj| dj.destroy }
  
    run_time = Time.now + 1.minute
    run_time = run_time + 1.minute if run_time.min == 0
    events.each do |event|
      user_run_time = run_time.in_time_zone(event.user.time_zone)
      event.days = [user_run_time.wday]
      event.time = user_run_time.strftime("%I:%M%p")
    end
    events.each do |event|
      event.save
      puts "Scheduling Call for #{event.user.name} at #{event.user.primary_phone.number}..."
    end

    puts "Scheduled call for " + run_time.strftime("%I:%M%p")
  end
end

desc "Send out a test conference email"
task :send_conference_email => :environment do
  user1 = User.find_by_email('blakem@15minutecalls.com')
  user2 = User.find_by_email('blakem@blakem.com')
  if (user1 && user2)
    conference = nil
    Conference.all.reverse.each do |c|
      next unless c.users.count == 2
      next unless c.users.include?(user1)
      next unless c.users.include?(user2)
      conference ||= c
    end
    if (conference)
      message = UserMailer.deliver_conference_email(user2, conference.users);
      puts message.body
    else 
      puts "Couldn't find conference"
    end
  else
    puts "Couldn't find users"
  end
end

desc "Send out the confirmation instructions email"
task :send_confirmation_email, [:email] => :environment do |t, args|
  email = args[:email] || 'blakem@15minutecalls.com'
  user = User.find_by_email(email)
  if user
    Devise::Mailer.confirmation_instructions(user).deliver
    puts "Sent email to: #{user.email}"
  else
    puts "Couldn't find user"
  end
end

desc "Send out the next_steps instructions email"
task :send_next_steps_email, [:email] => :environment do |t, args|
  email = args[:email] || 'blakem@15minutecalls.com'
  user = User.find_by_email(email)
  if user
    type = 'next_steps'
    member_mail = MemberMail.find_by_user_id_and_email_type(user.id, type)
    member_mail.destroy if member_mail
    MemberTracker.new.send_email_once(user, type)
    puts "Sent email to: #{user.email}"
  else
    puts "Couldn't find user"
  end
end
