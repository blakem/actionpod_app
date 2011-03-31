require 'spec_helper'

describe Event do
  it "should have a user" do
    user = Factory(:user)
    event = Factory(:event, :user_id => user.id)
    event.user.should == user
  end
  
  it "should have a schedule" do
    event = Factory(:event)
    event.schedule.should be_a_kind_of(IceCube::Schedule)
  end

  it "should have a default schedule of weekdays at 8am" do
    user = Factory(:user)
    pool = Factory(:pool)
    event = Event.create(:name => 'NewEvent775', :user_id => user.id, :pool_id => pool.id)
    event.schedule.to_s.should == 
      'Weekly on Mondays, Tuesdays, Wednesdays, Thursdays, and Fridays on the 8th hour of the day on the 0th minute of the hour'
  end
  
  it "belongs to a pool" do
    pool = Factory(:pool)
    event = Factory(:event, :pool_id => pool.id)
    event.pool.should == pool    
  end
  
  it "pretty prints with schedule_str and can be modified with alter_schedule" do
    event = Factory(:event)
    event.schedule_str.should ==
      '8:00am on Mondays, Tuesdays, Wednesdays, Thursdays, and Fridays'
    event.alter_schedule(:hour_of_day => [10])
    event.schedule_str.should ==
      '10:00am on Mondays, Tuesdays, Wednesdays, Thursdays, and Fridays'
    event.alter_schedule(:hour_of_day => [14], :minute_of_hour => [15])
    event.schedule_str.should ==
      '2:15pm on Mondays, Tuesdays, Wednesdays, Thursdays, and Fridays'
    event.alter_schedule(:hour_of_day => [12], :minute_of_hour => [15])
    event.schedule_str.should ==
      '12:15pm on Mondays, Tuesdays, Wednesdays, Thursdays, and Fridays'
    event.alter_schedule(:hour_of_day => [0], :minute_of_hour => [15])
    event.schedule_str.should ==
      '12:15am on Mondays, Tuesdays, Wednesdays, Thursdays, and Fridays'
    event.alter_schedule(:day => [2,3,4], :minute_of_hour => [15])
    event.schedule_str.should ==
      '12:15am on Tuesdays, Wednesdays, and Thursdays'
    test_str = 'Weekly on the 8th hour of the day on Mondays, Tuesdays, Wednesdays, Thursdays, and Fridays on the 0th minute of the hour'      
    event.schedule_str(test_str).should  ==
      '8:00am on Mondays, Tuesdays, Wednesdays, Thursdays, and Fridays'
  end
end
