Factory.sequence :email do |n|
  "personf-#{n+1}@example.com"
end

Factory.sequence :phone do |n|
  "+1415#{sprintf( '%07i', n+1 )}"
end

Factory.define :user do |user|
  user.sequence(:email)  { Factory.next(:email) }
  user.password          "foobar"
  user.invite_code       User.secret_invite_code
end
