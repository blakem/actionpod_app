namespace :create do
  desc "Create an Invite Code"
  task :invite_code, [:name] => :environment do |t, args|
    invite_code = InviteCode.create(:name => args[:name])
    puts "#{invite_code.id}: #{invite_code.name}"
  end
end
