require 'spec_helper'

describe EventQueuer do
  before(:each) do
    Event.all.each { |e| e.destroy }
    @user = Factory(:user)
  end
  
  it "Creates Delayed Jobs for Events that are ready to run in the next 24 hours" do
    now = Time.now.in_time_zone(@user.time_zone)
    event1 = create_event_at(now + 5.minutes, @user)
    event2 = create_event_at(now + 23.hours, @user)
    event3 = create_event_at(now + 25.hours, @user)
    expect { 
      count = EventQueuer.new.queue_events(Time.now.utc)
      count.should == 2
    }.to change(DelayedJob, :count).by(2)
    DelayedJob.all.count.should be 2
    run_at_list = DelayedJob.all.map { |dj| dj.run_at.utc.to_s }
    expected1 = (now + 5.minutes - now.sec.seconds).utc.to_s
    expected2 = (now + 23.hours - now.sec.seconds).utc.to_s
    run_at_list.should include(expected1, expected2)
  end
end

def create_event_at(time, user)
  event = Factory(:event, :user_id => user.id)
  event.alter_schedule(:hour_of_day => [time.hour], :minute_of_hour => [time.min], :day => [time.wday])
  event.save
  event
end
