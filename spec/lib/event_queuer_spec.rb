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
    DelayedJob.all.each { |dj| dj.destroy }

    pool_queuer = mock('PoolQueuer')
    pool_queuer.should_receive(:queue_pool).with(event1.pool, event1.schedule.next_occurrence.utc)
    pool_queuer.should_receive(:queue_pool).with(event2.pool, event2.schedule.next_occurrence.utc)
    PoolQueuer.should_receive(:new).twice.and_return(pool_queuer)

    rv = nil
    expect { 
      rv = EventQueuer.new.queue_events(Time.now.utc).sort { |a,b| a[:obj_id] <=> b[:obj_id] }
      rv.count.should == 2
    }.to change(DelayedJob, :count).by(2)

    event1_run_time = now + 5.minutes - now.sec.seconds
    event2_run_time = now + 23.hours - now.sec.seconds
    event1_dj = DelayedJob.where(:obj_type => 'Event', :obj_id => event1.id, :obj_jobtype => 'make_call')[0]
    event2_dj = DelayedJob.where(:obj_type => 'Event', :obj_id => event2.id, :obj_jobtype => 'make_call')[0]
    event1_dj.run_at.utc.to_s.should == event1_run_time.utc.to_s
    event2_dj.run_at.utc.to_s.should == event2_run_time.utc.to_s

    rv[0][:run_at] = rv[0][:run_at].to_s
    rv[0].should == {
      :obj_type => "Event", 
      :obj_id => event1.id, 
      :obj_jobtype => "make_call", 
      :run_at      => (now + 5.minutes - now.sec.seconds).utc.to_s,
      :id          => event1_dj.id,
      :pool_id     => event1.pool.id,
    }
    rv[1][:run_at] = rv[1][:run_at].to_s
    rv[1].should == {
      :obj_type => "Event", 
      :obj_id => event2.id, 
      :obj_jobtype => "make_call", 
      :run_at      => (now + 23.hours - now.sec.seconds).utc.to_s,        
      :id          => event2_dj.id,
      :pool_id     => event2.pool.id,
    }

    # Skip jobs that are already queued
    expect { 
      rv = EventQueuer.new.queue_events(Time.now.utc)
      rv.count.should == 0
    }.to_not change(DelayedJob, :count)
  end
end

def create_event_at(time, user)
  pool = Factory(:pool)
  event = Factory(:event, :user_id => user.id, :pool_id => pool.id)
  event.alter_schedule(:hour_of_day => [time.hour], :minute_of_hour => [time.min], :day => [time.wday])
  event.save
  event
end
