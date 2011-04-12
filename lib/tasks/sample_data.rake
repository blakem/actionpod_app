require 'faker'

namespace :db do
  desc "Fill database with sample data"
  task :populate => :environment do
    if Rails.env.development?
      Rake::Task['db:reset'].invoke
      make_users
    else
      puts "DONT RUN OUTSIDE OF DEVELOPMENT!"
    end
  end
end

def make_users
  invite_code = InviteCode.create!(:name => 'xyzzy')

  admin = User.create!(
    :invite_code => invite_code.name,
    :name => "Example User",
    :email => 'blakem30@yahoo.com',
    :primary_phone_string => '415 314 1222',
    :password => 'foobar',
  )
  admin.toggle!(:admin)
  admin.save!
  pool = Pool.create!(:name => 'Default Pool', :user_id => admin.id)
  event = Event.create!(:name => "Test Event 1", :user_id => admin.id, :pool_id => pool.id)

  5.times do |n|
    name = Faker::Name.name
    email = "example-#{n+2}@example.com"
    password = "password"
    user = User.create!(
      :invite_code => invite_code.name,
      :name => name,
      :email => email, 
      :password => password,
      :primary_phone_string => '222 333 4444',
    ) 
    user.save!
    event = Event.create!(:name => "Test Event #{n+2}", :user_id => user.id, :pool_id => pool.id)
  end

  3.times do |n|
    name = Faker::Name.name
    email = "example-#{n+2+5}@example.com"
    password = "password"
    user = User.create!(
      :invite_code => invite_code.name,
      :name => name,
      :email => email, 
      :password => password,
      :primary_phone_string => '222 333 4444',
    )
    event = Event.create!(:name => "Test Event #{n+2+5}", :user_id => user.id, :pool_id => pool.id)
    event.time = '9:00am'
    event.save
  end
  1.times do |n|
    name = Faker::Name.name
    email = "example-#{n+2+5+3}@example.com"
    password = "password"
    user = User.create!(
      :invite_code => invite_code.name,
      :name => name,
      :email => email, 
      :password => password,
      :primary_phone_string => '222 333 4444',
      :time_zone => 'Mountain Time (US & Canada)',
    )
    event = Event.create!(:name => "Test Event #{n+2+5+3}", :user_id => user.id, :pool_id => pool.id)
    event.time = '10:00am'
    event.save
  end
  
  ActiveRecord::Base.connection.execute("update users set confirmed_at=NOW()")
end
