namespace :create do
  desc "Create an Invite Code"
  task :invite_code, [:name] => :environment do |t, args|
    invite_code = InviteCode.create!(:name => args[:name])
    puts "#{invite_code.id}: #{invite_code.name}"
  end

  desc "Create a Tip"
  task :tip, [:body] => :environment do |t, args|
    tip = Tip.create!(:body => args[:body])
    puts "#{tip.id}: #{tip.body}"
  end
end
