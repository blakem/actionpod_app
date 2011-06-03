desc "Check integrity of data"
task :data_integrity => :environment do
  # Counts
  puts "ok - Users:       #{User.count}"
  puts "ok - Phones:      #{Phone.count}"
  puts "ok - Plans:       #{Plan.count}"
  puts "ok - Events:      #{Event.count}"
  puts "ok - Pools:       #{Pool.count}"
  puts "ok - InviteCodes: #{InviteCode.count}"
  puts

  # must have a default group
  if Pool.find_by_name('Default Group')
    puts "  ok - Default Group"
  else
    puts "ERROR - No Default Group!"
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
    primary_phones = Phone.where(:user_id => u.id, :primary => true)
    if primary_phones.count == 1
      puts "    ok - User'#{u.id}:#{u.name}' has a primary_phone"
    elsif primary_phones.count == 0
      puts "ERROR - User'#{u.id}:#{u.name}' has no primary_phone!!"
    else
      puts "ERROR - User'#{u.id}:#{u.name}' has more than one primary_phone!!"
    end
  end
  puts

  # phones
  phones = Phone.all
  puts "  ok - Phone Count: #{phones.count}"
  phones.each do |p|
    puts "ERROR: Phone'#{p.id}:#{p.number}' is invalid!" unless p.valid?
    user = User.find_by_id(p.user_id)
    if user
      puts "    ok - Phone'#{p.id}:#{p.number}' has a user"
    else
      puts "ERROR: Phone'#{p.id}:#{p.number}' has no user! user_id = #{p.user_id}"
    end
  end

  # plans
  plans = Plan.all
  puts "  ok - Plan Count: #{plans.count}"
  plans.each do |p|
    puts "ERROR: Plan'#{p.id}:#{p.user_id}' is invalid!" unless p.valid?
    user = User.find_by_id(p.user_id)
    if user
      puts "    ok - Plan'#{p.id}:#{p.user_id}' has a user"
    else
      puts "ERROR: Plan'#{p.id}:#{p.user_id}' has no user! user_id = #{p.user_id}"
    end
  end
  
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
