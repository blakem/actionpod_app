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
      puts "#{u.id}:#{sprintf('%20s',u.name)} has #{sprintf('%-2s',event_count)} Events."
    end
  end
end
