Factory.sequence :email do |n|
  "personf-#{n+1}@example.com"
end

Factory.sequence :phone do |n|
  "+1415#{sprintf( '%07i', n+1 )}"
end

Factory.sequence :event_name do |n|
  "TestEvent#{n+1}"
end

Factory.sequence :user_name do |n|
  "TestNamme#{n+1}"
end

Factory.sequence :user_title do |n|
  "TestNamme#{n+1}"
end

Factory.define :user do |user|
  user.sequence(:email)  { Factory.next(:email) }
  user.sequence(:name)  { Factory.next(:user_name) }
  user.sequence(:title)  { Factory.next(:user_title) }
  user.password          "foobar"
  user.invite_code       User.secret_invite_code
end

Factory.define :event do |event|
  event.sequence(:name)  { Factory.next(:event_name) }
  event.association :user_id, :factory => :user
end
