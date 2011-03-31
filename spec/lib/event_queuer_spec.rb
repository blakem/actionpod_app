require 'spec_helper'

describe EventQueuer do
  before(:each) do
    Event.all.each { |e| e.destroy }
  end
  
  it "Created Delayed Jobs for Events that are ready to run" do
    now = Time.now
    event1 = create_event_at(now)
    event1.schedule.occurs_on?(now).should be_true
    event2 = create_event_at(now.yesterday)
    event2.schedule.occurs_on?(now).should be_false

    expect { 
      EventQueuer.new.queue_events(Time.now)
    }.to change(DelayedJob, :count).by(1)
  end
end

def create_event_at(time)
  event = Factory(:event)
  event.alter_schedule(:hour_of_day => [time.hour], :minute_of_hour => [time.min], :day => [time.wday])
  event.save
  event
end
