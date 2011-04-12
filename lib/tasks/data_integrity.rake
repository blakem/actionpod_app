desc "Check integrity of data"
task :data_integrity => :environment do
  # Counts
  puts "ok - Users:       #{User.count}"
  puts "ok - Events:      #{Event.count}"
  puts "ok - Pools:       #{Pool.count}"
  puts "ok - InviteCodes: #{InviteCode.count}"
  puts

  # must have a default pool
  if Pool.find_by_name('Default Pool')
    puts "  ok - Default Pool"
  else
    puts "ERROR - No Default Pool!"
  end
  puts
  
  # pools
  pools = Pool.all
  puts "  ok - Pool Count: #{pools.count}"
  pools.each do |p|
    puts "ERROR: Pool'#{p.id}:#{p.name}' is invalid!" unless p.valid?
    user = User.find_by_id(p.user_id)
    if user
      puts "    ok - Pool'#{p.id}:#{p.name}' has a user"
    else
      puts "ERROR: Pool'#{p.id}:#{p.name}' has no user! user_id = #{p.user_id}"
    end
  end
  puts

  # users
  users = User.all
  puts "  ok - User Count: #{users.count}"
  users.each do |u|
    puts "ERROR: User'#{u.id}:#{u.name}' is invalid!" unless u.valid?
  end
  puts
  
  # events
  events = Event.all
  puts "  ok - Event Count: #{events.count}"
  events.each do |e|
    puts "ERROR: Event'#{e.id}:#{e.name}' is invalid!" unless e.valid?
    user = User.find_by_id(e.user_id)
    if user
      puts "    ok - Event'#{e.id}:#{e.name}' has a user"
    else
      puts "ERROR: Event'#{e.id}:#{e.name}' has no user! user_id = #{e.user_id}"
    end

    pool = Pool.find_by_id(e.pool_id)
    if pool
      puts "    ok - Event'#{e.id}:#{e.name}' has a pool"
    else
      puts "ERROR: Event'#{e.id}:#{e.name}' has no pool! user_id = #{e.pool_id}"
    end
  end
  puts
    
  # invite_codes
  invites = InviteCode.all
  puts "  ok - InviteCode Count: #{invites.count}"
  invites.each do |i|
    puts "ERROR: InviteCode'#{i.id}:#{i.name}' is invalid!" unless i.valid?
    if i.name && i.name == i.name.downcase
      puts "    ok - InviteCode'#{i.id}:#{i.name}' has a lowercase name"
    else
      puts "ERROR: InviteCode'#{i.id}' has no name!"
    end
  end
end

desc "Show information about currently Delayed Jobs"
task :delayed_jobs => :environment do
  DelayedJob.all.sort { |a,b| a.run_at <=> b.run_at }.each do |j|
    obj = Kernel.const_get(j.obj_type).find_by_id(j.obj_id)
    string = obj.name
    if obj.respond_to?('user')
      string += " (#{obj.user.name})"
    end
    puts "#{j.id}:#{j.pool_id} #{j.run_at} #{sprintf('%-11s', j.obj_type)} #{sprintf('%-25s',j.obj_jobtype)} #{j.obj_id} #{string}"
  end
end
