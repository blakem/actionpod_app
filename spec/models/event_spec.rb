require 'spec_helper'

describe Event do
  
  it "should require a name" do
    event = Event.new
    event.valid?
    event.errors[:name].should include("can't be blank")
  end
  
  it "should have a user" do
    user = Factory(:user)
    event = Factory(:event, :user_id => user.id)
    event.user.should == user
  end
  
  it "belongs to a pool" do
    pool = Factory(:pool)
    event = Factory(:event, :pool_id => pool.id)
    event.pool.should == pool    
  end

  describe "it's schedule" do
    before(:each) do
      user = Factory(:user, :time_zone => 'Mountain Time (US & Canada)')
      pool = Factory(:pool)
      @event = Event.create(:name => 'NewEvent', :user_id => user.id, :pool_id => pool.id)
    end
    
    it "should have a schedule" do
      @event.schedule.should be_a_kind_of(IceCube::Schedule)
    end
    
    it "should have a default schedule of weekdays at 8am" do
      @event.schedule.to_s.should == 
        'Weekly on Mondays, Tuesdays, Wednesdays, Thursdays, and Fridays on the 8th hour of the day on the 0th minute of the hour'
    end

    it "should have a start_date of today" do
      @event.schedule.to_hash[:start_date].to_date.should == Time.now.in_time_zone(@event.user.time_zone).to_date
    end
  
    it "should have a start_time of the beginning of today in the users timezone" do
      @event.schedule.start_time.should == Time.now.in_time_zone(@event.user.time_zone).beginning_of_day
    end

    it "pretty prints with schedule_str and can be modified with alter_schedule" do
      @event.schedule_str.should ==
        '8:00am on Mondays, Tuesdays, Wednesdays, Thursdays, and Fridays'
      @event.alter_schedule(:hour_of_day => [10])
      @event.schedule_str.should ==
        '10:00am on Mondays, Tuesdays, Wednesdays, Thursdays, and Fridays'
      @event.alter_schedule(:hour_of_day => [14], :minute_of_hour => [15])
      @event.schedule_str.should ==
        '2:15pm on Mondays, Tuesdays, Wednesdays, Thursdays, and Fridays'
      @event.alter_schedule(:hour_of_day => [12], :minute_of_hour => [15])
      @event.schedule_str.should ==
        '12:15pm on Mondays, Tuesdays, Wednesdays, Thursdays, and Fridays'
      @event.alter_schedule(:hour_of_day => [0], :minute_of_hour => [15])
      @event.schedule_str.should ==
        '12:15am on Mondays, Tuesdays, Wednesdays, Thursdays, and Fridays'
      @event.alter_schedule(:day => [2,3,4], :minute_of_hour => [15])
      @event.schedule_str.should ==
        '12:15am on Tuesdays, Wednesdays, and Thursdays'
      test_str = 'Weekly on the 8th hour of the day on Mondays, Tuesdays, Wednesdays, Thursdays, and Fridays on the 0th minute of the hour'      
      @event.schedule_str(test_str).should  ==
        '8:00am on Mondays, Tuesdays, Wednesdays, Thursdays, and Fridays'
    end
    
    it "should have time a time accessor to it's schedule" do
      @event.time.should == '8:00am'
    end

    it "should have time a time setter to it's schedule" do
      @event.time = '9:00am'
      @event.time.should == '9:00am'
      @event.save
      @event.reload
      @event.time.should == '9:00am'
    end

   
  end
end
