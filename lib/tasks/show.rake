namespace :show do
  desc "Show information about currently Delayed Jobs"
  task :delayed_jobs => :environment do
    jobs = DelayedJob.all
    puts "No DelayedJobs...." if jobs.empty?
    jobs.sort { |a,b| a.run_at <=> b.run_at }.each do |j|
      string = ''
      if (j.obj_id)
        obj = Kernel.const_get(j.obj_type).find_by_id(j.obj_id)
        string = obj.name
        if obj.respond_to?('user')
          string = sprintf('%-25s', string) + " (#{obj.user.name})"
        end
      end
      run_time = j.run_at.in_time_zone('Pacific Time (US & Canada)')
      puts "#{sprintf('%6s',j.id)}:#{sprintf('%-2s',j.pool_id)} #{run_time.strftime("%a %b %e")} #{run_time.strftime("%l:%M%p").downcase} " +
           "#{sprintf('%-11s', j.obj_type)} #{sprintf('%-25s',j.obj_jobtype)} #{sprintf('%3s',j.obj_id)} #{string}"
    end
  end

  desc "Show information about current Users"
  task :users => :environment do
    User.all.sort { |a,b| a.id <=> b.id }.each do |u|
      event_count = u.normal_events.count
      plan_count = u.plans.count
      admin = u.admin? ? '*' : ' '
      not_confirmed = u.confirmed_at.blank? ? 'NC' : '  '
      time = event_count == 1 ? u.events.first.time : ''
      primary_phones = Phone.where(:user_id => u.id, :primary => true)
      if primary_phones.count > 1
        puts "ERROR: #{u.name} has multiple primary phones"
      elsif primary_phones.count == 0
        puts "ERROR: #{u.name} has no primary phone"
      end
      phones = Phone.where(:user_id => u.id)
        
      puts "#{sprintf('%3s',u.id)}:#{admin}#{not_confirmed} #{sprintf('%-25s',u.name)} " +
           "has #{sprintf('%2s',event_count)}e #{sprintf('%2s',plan_count)}pl " +
           "#{sprintf('%-27s',u.time_zone)} #{sprintf('%7s',time)} " +
           "#{phones.count}ph #{primary_phones[0].number} #{sprintf("%10s", u.invite_code)} #{u.handle}"
    end
  end

  desc "Show information about current InviteCodes"
  task :invite_codes => :environment do
    InviteCode.all.each do |i|
      puts "#{i.id}: #{i.name}"
    end
  end

  desc "Show information about current Phones"
  task :phones => :environment do
    Phone.all.each do |p|
      primary = p.primary ? '*' : ' '
      puts "#{sprintf"%3s",p.id}:#{primary} #{p.number} #{sprintf("%15s",p.string)} #{p.user_id}:#{p.user.name}"
    end
  end

  desc "Show information about current Plans"
  task :plans => :environment do
    Plan.all.each do |p|
      puts "#{sprintf"%3s",p.id}:#{p.user_id} #{sprintf"%5s",p.body.length} #{p.user.name}"
    end
  end

  desc "Show information about current Events"
  task :events => :environment do
    Event.all.each do |e|
      sms = e.send_sms_reminder ? 'sms' : '   '
      puts "#{sprintf"%3s",e.id}:#{sprintf"%-2s",e.pool_id} #{sprintf"%-25s",e.name} #{sprintf"%7s",e.time}:" +
           "#{sprintf"%-7s",e.days.join('')} #{sms} #{sprintf"%3s",e.user.id}:#{sprintf"%-15s",e.user.name}"
    end
  end

  desc "Show information about conferences"
  task :conferences => :environment do
    Conference.all.sort{ |a,b| a.started_at <=> b.started_at }.each do |c|
      users = c.users
      names = users.map(&:name).join(',')
      date = c.started_at.strftime("%a %b %e")
      ended_at_time = c.ended_at ? c.ended_at.in_time_zone('Pacific Time (US & Canada)').strftime("%l:%M%p").downcase : 'Not Yet'
      puts "#{sprintf("%3s", c.id)}: #{date} #{c.started_at.in_time_zone('Pacific Time (US & Canada)').strftime("%l:%M%p").downcase}" +
           "-#{ended_at_time} #{sprintf("%-18s", c.status)} #{sprintf("%-12s", c.room_name)} P:#{users.count} #{names}"
    end
  end

  desc "Show information about calls"
  task :calls, [:count]  => :environment do |t, args|
    args.with_defaults(:count => '20')
    calls = Call.all.sort{ |a,b| a.created_at <=> b.created_at }
    if args[:count] == 'all'
    elsif args[:count].to_i < calls.count
      calls = calls[(0-args[:count].to_i)..-1]
    end
    calls.each do |c|
      time = c.created_at.in_time_zone('Pacific Time (US & Canada)')
      date = time.strftime("%a %b %e")
      user = ''
      if c.event_id
        event = Event.find_by_id(c.event_id)
        user = event.user.name if event
      end
      puts "#{sprintf("%3s", c.id)}: #{date} #{time.strftime("%l:%M:%S%p").downcase} #{c.To} #{c.From} " +
           "#{sprintf("%-12s", c.Direction)} #{sprintf("%-4s", c.Duration)} #{sprintf("%17s",user)} " +
           "#{c.status}"
    end
  end
  
  desc "Show information about preferences"
  task :preferences => :environment do
    Preference.all.sort { |a,b| a.updated_at <=> b.updated_at }.each do |p|
      puts "#{p.user.first_name} #{p.preference_string} #{p.other_user.first_name} at #{p.updated_at.strftime("%A %B #{p.updated_at.day.ordinalize} %l:%M%p").downcase.titleize}"
    end
  end
end
