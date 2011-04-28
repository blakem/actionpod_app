require 'spec_helper'

describe PoolQueuer do
  before(:each) do
    @pq = PoolQueuer.new
  end

  it "has time_before_calls_go_out" do
    @pq.time_before_calls_go_out.should == 10.minutes
  end

  describe "queue_pool" do
    it "schedules a check_before_calls_go_out" do
      pool = Factory(:pool)
      now = Time.now.utc
      expect {
        @pq.queue_pool(pool, now)
      }.to change(DelayedJob, :count).by(1)
      delay_args = {
        :obj_type    => 'PoolQueuer', 
        :obj_jobtype => 'check_before_calls_go_out',
        :run_at      => now - @pq.time_before_calls_go_out,
        :pool_id     => pool.id,
      }
      DelayedJob.where(delay_args).count.should == 1
      expect {
        @pq.queue_pool(pool, now)
      }.to_not change(DelayedJob, :count)
    end
  end

  describe "check_before_calls_go_out" do
    before(:each) do
      @pool = Factory(:pool)
      @user = Factory(:user)
      @phone = Factory(:phone, :user_id => @user.id, :primary => true)
      @event = Factory(:event, :pool_id => @pool.id, :user_id => @user.id, :send_sms_reminder => false)
      @now = Time.now.utc
      @delay_args = {
        :obj_type    => 'Event',
        :obj_jobtype => 'make_call',
        :run_at      => @now + 5.minutes,
        :pool_id     => @pool.id
      }
      
    end
    
    it "deletes a queued make_call if it's the only one scheduled" do
      dj = DelayedJob.create(@delay_args)
      dj_id = dj.id
      expect {
        @pq.check_before_calls_go_out(@pool, @now + 5.minutes)
      }.to change(DelayedJob, :count).by(-1)
      DelayedJob.find_by_id(dj_id).should be_nil
    end
    
    it "Sends an SMS apology if it's the only one scheduled" do
      @event.send_sms_reminder = true
      @event.save
      dj = DelayedJob.create(@delay_args.merge(:obj_id => @event.id))
      response = mock('HTTPResponse')
      response.should_receive(:body).and_return('{"foo":"bar"}')
      account = mock('TwilioAccount', :request => response)
      account.should_receive(:request).with(TwilioCaller.new.sms_uri, 'POST', {
        :From => TwilioCaller.new.caller_id,
        :To   => @user.primary_phone.number, 
        :Body => "Sorry.  No one else is scheduled for the 8:00am slot.  This shouldn't happen after we reach a critical mass of users. ;-)"        
      })
      Twilio::RestAccount.should_receive(:new).with("AC2e57bf710b77d765d280786bc07dbacc", "fc9bd67bb8deee6befd3ab0da3973718").and_return(account)
      pool_runs_at = @now + 5.minutes
      @pq.check_before_calls_go_out(@pool, pool_runs_at)
      conference = Conference.where(:pool_id => @pool.id, :started_at => pool_runs_at, :ended_at => pool_runs_at, :status => 'only_one_scheduled')[0]
      conference.users.should == [@user]
    end

    it "Don't send SMS apology if sms reminders are turned off" do
      @event.send_sms_reminder = false
      @event.save
      dj = DelayedJob.create(@delay_args.merge(:obj_id => @event.id))
      Twilio::RestAccount.should_not_receive(:new)
      pool_runs_at = @now + 5.minutes
      @pq.check_before_calls_go_out(@pool, pool_runs_at)
      conference = Conference.where(:pool_id => @pool.id, :started_at => pool_runs_at, :ended_at => pool_runs_at, :status => 'only_one_scheduled')[0]
      conference.users.should == [@user]
    end

    it "Sends an SMS reminder if it's successful and the event has sms_reminder_message turned on" do
      user2 = Factory(:user)
      phone2 = Factory(:phone, :user_id => user2.id, :primary => true)
      event1 = @event
      event2 = Factory(:event, :pool_id => @pool.id, :user_id => user2.id, :send_sms_reminder => true)
      event1.send_sms_reminder.should == false
      event2.send_sms_reminder.should == true
      dj1 = DelayedJob.create(@delay_args.merge(:obj_id => event1.id))
      dj2 = DelayedJob.create(@delay_args.merge(:obj_id => event2.id))
      response = mock('HTTPResponse')
      response.should_receive(:body).and_return('{"foo":"bar"}')
      account = mock('TwilioAccount', :request => response)
      account.should_receive(:request).with(TwilioCaller.new.sms_uri, 'POST', {
        :From => TwilioCaller.new.caller_id,
        :To   => @user.primary_phone.number, 
        :Body => "Your #{event2.name_in_second_person} will begin at 8:00am.  Expect a call in 10 minutes."        
      })
      Twilio::RestAccount.should_receive(:new).with("AC2e57bf710b77d765d280786bc07dbacc", "fc9bd67bb8deee6befd3ab0da3973718").and_return(account)
      pool_runs_at = @now + 5.minutes
      @pq.check_before_calls_go_out(@pool, pool_runs_at)
    end

    it "Doesn't sends an SMS reminder if it's past the call window" do
      TwilioCaller.should_not_receive(:new)
      @pq.check_before_calls_go_out(@pool, Time.now.utc - 1.minute - @event.pool.timelimit.minutes)
    end

    it "should have a time_between_merges" do
      @pq.time_between_merges.should == 5.seconds
    end
    
    it "should have a time_before_first_merge" do
      @pq.time_before_first_merge.should == 15.seconds
    end
    
    it "should queue merge_calls_for_pool on success" do
      DelayedJob.create(@delay_args.merge(:obj_id => @event.id))
      DelayedJob.create(@delay_args.merge(:obj_id => @event.id))
      expect {
        @pq.check_before_calls_go_out(@pool, @now + 5.minutes)
      }.to change(DelayedJob, :count).by(1)
      DelayedJob.where(
        :obj_type    => 'PoolMerger',
        :pool_id     => @pool.id,
        :obj_jobtype => 'merge_calls_for_pool',
        :run_at      => @now + 5.minutes + @pq.time_before_first_merge
      ).count.should == 1
    end

    it "should send total to queue_merge_calls_for_pool" do
      DelayedJob.create(@delay_args.merge(:obj_id => @event.id))
      DelayedJob.create(@delay_args.merge(:obj_id => @event.id))
      @pq.should_receive(:queue_merge_calls_for_pool).with(@pool, @now + 5.minutes, 0, {:total => 2})
      @pq.check_before_calls_go_out(@pool, @now + 5.minutes)
    end
  end
  
  describe "queue_merge_calls_for_pool" do
    before(:each) do
      @pool = Factory(:pool, :timelimit => 15)
      @user = Factory(:user)
      @event = Factory(:event, :pool_id => @pool.id, :user_id => @user.id)
      @now = Time.now.utc
      @delay_args = {
        :obj_type    => 'Event',
        :obj_jobtype => 'make_call',
        :run_at      => @now + 5.minutes,
        :pool_id     => @pool.id
      }
    end
      
    it "should call merge_calls_for_pool" do
      pool_runs_at = @now + 5.minutes
      pool_merger = mock('PoolMerger')
      pool_merger.should_receive(:merge_calls_for_pool).with(@pool, pool_runs_at, {}).and_return({:foo => 'foo'})
      pool_merger.should_receive(:merge_calls_for_pool).with(@pool, pool_runs_at, {:foo => 'foo'})
      PoolMerger.should_receive(:new).twice.and_return(pool_merger)
      expect {
        @pq.queue_merge_calls_for_pool(@pool, pool_runs_at, 1, {})
      }.to change(DelayedJob, :count).by(1)
      djs = DelayedJob.where(
        :obj_type    => 'PoolMerger',
        :pool_id     => @pool.id,
        :obj_jobtype => 'merge_calls_for_pool',
        :run_at      => pool_runs_at + @pq.time_before_first_merge + (@pq.time_between_merges * 1)
      )
      djs.count.should == 1
      YAML.load(djs[0].handler).perform
      DelayedJob.where(
        :obj_type    => 'PoolMerger',
        :pool_id     => @pool.id,
        :obj_jobtype => 'merge_calls_for_pool',
        :run_at      => pool_runs_at + @pq.time_before_first_merge + (@pq.time_between_merges * 2)
      ).count.should == 1
    end
    
    it "should run on the 177th time" do
      pool_runs_at = @now + 5.minutes
      pool_merger = mock('PoolMerger')
      pool_merger.should_receive(:merge_calls_for_pool).with(@pool, pool_runs_at, {})
      PoolMerger.should_receive(:new).and_return(pool_merger)
      expect {
        @pq.queue_merge_calls_for_pool(@pool, pool_runs_at, 177, {})
      }.to change(DelayedJob, :count).by(1)
      DelayedJob.where(
        :obj_type    => 'PoolMerger',
        :pool_id     => @pool.id,
        :obj_jobtype => 'merge_calls_for_pool',
        :run_at      => pool_runs_at + @pq.time_before_first_merge + (@pq.time_between_merges * 177)
      ).count.should == 1
    end

    it "should exit and update the conference on the 178th time" do
      user1 = Factory(:user)
      user2 = Factory(:user)
      user3 = Factory(:user)
      user4 = Factory(:user)
      event1 = Factory(:event, :user_id => user1.id)
      event2 = Factory(:event, :user_id => user2.id)
      event3 = Factory(:event, :user_id => user3.id)
      event4 = Factory(:event, :user_id => user4.id)
      ran_at = @now - 5.minutes
      conference1 = Conference.create(
        :pool_id => @pool.id, 
        :started_at => ran_at, 
        :room_name => "15mcPool#{@pool.id}Room1", 
        :status => 'in_progress'
      )
      conference2 = Conference.create(
        :pool_id => @pool.id, 
        :started_at => ran_at, 
        :room_name => "15mcPool#{@pool.id}Room2", 
        :status => 'in_progress'
      )
      data = {
        :on_hold => {},
        :next_room => 5,
        :placed      => {
          "CA9fa67e8696b60ee1ca1e75ec81ef85e7XXX11" => {
            :room_name => "15mcPool#{@pool.id}Room1",
            :event_id => event1.id,
          },
          "CA9fa67e8696b60ee1ca1e75ec81ef85e7XXX12" => {
            :room_name => "15mcPool#{@pool.id}Room1",
            :event_id => event2.id,
          },
          "CA9fa67e8696b60ee1ca1e75ec81ef85e7XXX21" => {
            :room_name => "15mcPool#{@pool.id}Room2",
            :event_id => event3.id,
          },
          "CA9fa67e8696b60ee1ca1e75ec81ef85e7XXX22" => {
            :room_name => "15mcPool#{@pool.id}Room2",
            :event_id => event4.id,
          },
          "CA9fa67e8696b60ee1ca1e75ec81ef85e7XXX22999" => {
            :room_name => "15mcPool#{@pool.id}Room2",
            :event_id => 7788990,
          },
        },
      }
      expect {
        rv = @pq.queue_merge_calls_for_pool(@pool, ran_at, 178, data)
        rv.should == true
      }.to_not change(DelayedJob, :count)
      conference1.reload
      conference1.status.should == 'completed'
      conference1.ended_at.should < Time.now
      conference1.ended_at.should > ran_at
      conference2.reload
      conference2.status.should == 'completed'
      conference2.ended_at.should < Time.now
      conference2.ended_at.should > ran_at
    end
  end
end
