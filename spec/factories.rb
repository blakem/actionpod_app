# XXX RESTART SPORK XXX #

Factory.sequence :email do |n|
  "person-#{n+1}@example.com"
end

Factory.sequence :phone do |n|
  "+1415#{sprintf( '%07i', n+1 )}"
end

# XXX RESTART SPORK XXX #

Factory.sequence :event_name do |n|
  "TestEvent#{n+1}"
end

Factory.sequence :user_name do |n|
  "TestName#{n+1}"
end

# XXX RESTART SPORK XXX #

Factory.sequence :user_title do |n|
  "TestTitle#{n+1}"
end

Factory.sequence :pool_name do |n|
  "TestPool#{n+1}"
end

Factory.sequence :plan_body do |n|
  "TestPlanBody#{n+1}"
end

# XXX RESTART SPORK XXX #

Factory.define :user do |user|
  user.sequence(:email)         { Factory.next(:email) }
  user.sequence(:name)          { Factory.next(:user_name) }
  user.sequence(:title)         { Factory.next(:user_title) }
  user.time_zone                "Pacific Time (US & Canada)"
  user.password                 "foobar"
  user.invite_code              User.secret_invite_code
  user.confirmed_at             (Time.now - 5.minutes)
end

# XXX RESTART SPORK XXX #

Factory.define :event do |event|
  event.sequence(:name)  { Factory.next(:event_name) }
  event.association :user_id, :factory => :user
  event.association :pool_id, :factory => :pool
end

Factory.define :phone do |phone|
  phone.sequence(:number)     { Factory.next(:phone) }
  phone.string                "444 555 6666"
  phone.association :user_id, :factory => :user
end

# XXX RESTART SPORK XXX #

Factory.define :plan do |plan|
  plan.sequence(:body)     { Factory.next(:plan_body) }
  plan.association :user_id, :factory => :user
end

Factory.define :pool do |pool|
  pool.sequence(:name)  { Factory.next(:pool_name) }
  pool.association :admin_id, :factory => :user
  pool.timelimit  30
  pool.merge_type 1
end

# XXX RESTART SPORK XXX #

Factory.define :delayed_job do |dj|
  dj.obj_type    "User"
  dj.obj_id      456
  dj.obj_jobtype "pingme"
end

Factory.define :call do |c|
  c.status          'foo'
  c.sequence(:To)   { Factory.next(:phone) }
  c.sequence(:From) { Factory.next(:phone) }
  c.Duration        45
end
