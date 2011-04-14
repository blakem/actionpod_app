namespace :show do
  desc "Show information about currently Delayed Jobs"
  task :delayed_jobs => :environment do
    DelayedJob.all.sort { |a,b| a.run_at <=> b.run_at }.each do |j|
      string = ''
      if (j.obj_id)
        obj = Kernel.const_get(j.obj_type).find_by_id(j.obj_id)
        string = obj.name
        if obj.respond_to?('user')
          string = sprintf('%-25s', string) + " (#{obj.user.name})"
        end
      end
      puts "#{sprintf('%6s',j.id)}:#{sprintf('%-2s',j.pool_id)} #{j.run_at.in_time_zone('Pacific Time (US & Canada)')} " +
           "#{sprintf('%-11s', j.obj_type)} #{sprintf('%-25s',j.obj_jobtype)} #{sprintf('%3s',j.obj_id)} #{string}"
    end
  end

  desc "Show information about current Users"
  task :users => :environment do
    User.all.sort { |a,b| a.id <=> b.id }.each do |u|
      event_count = u.events.count
      admin = u.admin? ? '*' : ' '
      not_confirmed = u.confirmed_at.blank? ? 'NC' : '  '
      time = event_count == 1 ? u.events.first.time : ''
        
      puts "#{sprintf('%3s',u.id)}:#{admin}#{not_confirmed} #{sprintf('%-25s',u.name)} " +
           "has #{sprintf('%2s',event_count)}e #{sprintf('%-27s',u.time_zone)} #{sprintf('%7s',time)} #{u.invite_code}"
    end
  end

  desc "Show information about current InviteCodes"
  task :invitecodes => :environment do
    InviteCode.all.each do |i|
      puts "#{i.id}: #{i.name}"
    end
  end

  desc "Show information about conferences"
  task :conferences => :environment do
    Conference.all.sort{ |a,b| a.started_at <=> b.started_at }.each do |c|
      users = c.users
      names = users.map(&:name).join(',')
      date = c.started_at.strftime("%a %b %e")
      puts "#{c.id}: #{date} #{c.started_at.strftime("%l:%M%p")}-#{c.ended_at.strftime("%l:%M%p")} " + 
           "#{sprintf("%-18s", c.status)} #{sprintf("%-12s", c.room_name)} P:#{users.count} #{names}"
    end
  end

  desc "Show information about calls"
  task :calls => :environment do
    calls = Call.all.sort{ |a,b| a.created_at <=> b.created_at }
    calls[-20..-1].each do |c|
      time = c.created_at.in_time_zone('Pacific Time (US & Canada)')
      date = time.strftime("%a %b %e")
      user = ''
      if c.event_id
        event = Event.find_by_id(c.event_id)
        user = event.user.name if event
      end
      puts "#{c.id}: #{date} #{time.strftime("%l:%M%p")} #{c.To} #{c.From} #{sprintf("%-12s", c.Direction)} #{sprintf("%-4s", c.Duration)} #{user}"
    end
  end
end