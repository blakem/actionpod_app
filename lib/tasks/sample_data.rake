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
    :name => "Blake Mills",
    :email => 'blakem30@yahoo.com',
    :password => 'foobar',
  )
  admin.toggle!(:admin)
  admin.save!
  Phone.create!(:user_id => admin.id, :string => '415 314 1222', :primary => true)
  Phone.create!(:user_id => admin.id, :string => '415 111 2222')
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
    ) 
    user.save!
    Phone.create!(:user_id => user.id, :string => "415 314 122#{n}", :primary => true)
    Phone.create!(:user_id => user.id, :string => "415 111 222#{n}")
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
    )
    Phone.create!(:user_id => user.id, :string => "415 314 123#{n}", :primary => true)
    Phone.create!(:user_id => user.id, :string => "415 111 223#{n}")
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
      :time_zone => 'Mountain Time (US & Canada)',
    )
    Phone.create!(:user_id => user.id, :string => "415 314 124#{n}", :primary => true)
    Phone.create!(:user_id => user.id, :string => "415 111 224#{n}")
    event = Event.create!(:name => "Test Event #{n+2+5+3}", :user_id => user.id, :pool_id => pool.id)
    event.time = '10:00am'
    event.save
  end
  ActiveRecord::Base.connection.execute("update users set confirmed_at=NOW()")
  
  now = Time.now
  conference = Conference.create(
    :started_at => now-30.minutes,
    :ended_at => now-15.minutes,
    :pool_id => pool.id,
    :room_name => "Pool1Room1",
    :status => 'completed',
  )
  all_users = User.all.sort_by(&:id)
  conference.users = all_users[0..2]

  conference = Conference.create(
    :started_at => now-90.minutes,
    :ended_at => now - 90.minutes + 20.seconds,
    :pool_id => pool.id,
    :room_name => "Pool1Room1",
    :status => 'only_one_answered',
  )
  conference.users = [all_users.first]

  conference = Conference.create(
    :started_at => now-290.minutes,
    :ended_at => now - 290.minutes,
    :pool_id => pool.id,
    :status => 'only_one_scheduled',
  )
  conference.users = [all_users.first]
  
end
