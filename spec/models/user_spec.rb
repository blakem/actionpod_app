require 'spec_helper'

describe User do
  it "Should have a secret invite code" do
    User.secret_invite_code.should_not be_empty
  end

  it "has many phones and a primary_phone" do
    user = Factory(:user)
    phone1 = Factory(:phone, :user_id => user.id)
    phone2 = Factory(:phone, :user_id => user.id, :primary => true)
    user.phones.should include(phone1, phone2)
    user.primary_phone.should == phone2
    user.primary_phone.number.should == phone2.number
    user.primary_phone.string.should == phone2.string
  end
  
  it "has with_phone" do
    user = Factory(:user)
    user.phones.should be_empty
    user = user.with_phone
    user.phones[0].kind_of?(Phone)
    user.phones[0].user_id.should == user.id
  end

  it "requires a name" do
    user = User.new
    user.valid?
    user.errors[:name].should include("can't be blank")
  end
  
  it "should have an admin attribute" do
    user = Factory(:user)
    user.admin?.should be_false
    user.admin = true
    user.admin?.should be_true
  end

  it "should have a soft delete" do
    user = Factory(:user)
    user.deleted_at.should     be_nil
    user.soft_delete
    user.deleted_at.should_not be_nil
  end
  
  it "should have many events" do
    user = Factory(:user)
    event1 = Factory(:event, :user_id => user.id)
    event2 = Factory(:event, :user_id => user.id)
    event3 = Factory(:event)
    user.events.should include(event1, event2)
    user.events.should_not include(event3)
  end

  it "can have zero or more pools" do
    user = Factory(:user)
    user.pools.count.should == 0
    pool1 = Factory(:pool, :user_id => user.id)
    pool2 = Factory(:pool, :user_id => user.id)
    pool3 = Factory(:pool)
    user.pools.should include(pool1, pool2)
    user.pools.should_not include(pool3)
  end
  
  it "should have a time_zone that defaults to 'Pacific Time (US & Canada)'" do
    user1 = User.create()
    user1.time_zone.should == 'Pacific Time (US & Canada)'
    user2 = User.create(:time_zone => 'Mountain Time (US & Canada)')
    user2.time_zone.should == 'Mountain Time (US & Canada)'
  end
  
  it "should have a name" do
    user = Factory(:user, :name => 'Bob Jones')
    user.name.should == 'Bob Jones'
  end

  it "should have a title" do
    user = Factory(:user, :title => 'Software Developer')
    user.title.should == 'Software Developer'
  end

  it "updates it's events timezones when the user.time_zone is changes" do
    pacific_time_zone = 'Pacific Time (US & Canada)'
    mountain_time_zone = 'Mountain Time (US & Canada)'
    user = Factory(:user, :time_zone => pacific_time_zone)
    event = Factory(:event, :user_id => user.id, :pool_id => Factory(:pool).id)
    event.schedule
    event.save
    event.reload

    event.schedule.start_time.time_zone.to_s.should == "(GMT-08:00) " + pacific_time_zone
    user.time_zone = mountain_time_zone
    user.save
    event.reload
    event.schedule.start_time.time_zone.to_s.should == "(GMT-07:00) " + mountain_time_zone
  end
  
  it "has a first_name" do
    user = Factory(:user, :name => "Bob Jones", :email => 'abc@123.com')
    user.first_name.should == 'Bob'
    user.name = 'Sally'
    user.first_name.should == 'Sally'
    user.name = ' sally smith'
    user.first_name.should == 'Sally'
    user.name = nil
    user.first_name.should == 'abc'
    user.name = ''
    user.first_name.should == 'abc'
    user.email.should == 'abc@123.com'
  end
  
  it "has many conferences" do
    conference1 = Conference.create
    conference2 = Conference.create
    user = Factory(:user)
    user.conferences = [conference1, conference2]
    user.conferences.should include(conference1, conference2)
  end
  
  describe "handle" do
    it "can be generated from the email address" do
      user1 = Factory(:user, :email => 'foobar@example.com')
      user1.handle.should == 'foobar'
      user2 = Factory(:user, :email => 'foobar@example.net')
      user2.handle.should == 'foobar2'
    end

    it "doesn't get overwritten when they change their email" do
      user1 = Factory(:user, :email => 'foo-Bar@example.com')
      user1.handle.should == 'foobar'
      user1.email = 'bob@example.com'
      user1.save
      user1.reload
      user1.handle.should == 'foobar'
      user2 = Factory(:user, :email => 'foo-Bar@example.net')
      user2.handle.should == 'foobar2'      
      user2.email = 'sally@example.com'
      user2.save
      user2.reload
      user2.handle.should == 'foobar2'      
    end
  end
end
