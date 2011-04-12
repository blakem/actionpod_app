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
      @event = Factory(:event, :pool_id => @pool.id, :user_id => @user.id)
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
    
    it "Sends and SMS if it's the only one scheduled" do
      dj = DelayedJob.create(@delay_args.merge(:obj_id => @event.id))
      response = mock('HTTPResponse')
      response.should_receive(:body).and_return('{"foo":"bar"}')
      account = mock('TwilioAccount', :request => response)
      account.should_receive(:request).with(TwilioCaller.new.sms_uri, 'POST', {
        :From => TwilioCaller.new.caller_id,
        :To   => @user.primary_phone, 
        :Body => "Sorry.  No one else is scheduled for the 8:00am slot.  This shouldn't happen after we reach a critical mass of users. ;-)"        
      })
      Twilio::RestAccount.should_receive(:new).with("AC2e57bf710b77d765d280786bc07dbacc", "fc9bd67bb8deee6befd3ab0da3973718").and_return(account)
      @pq.check_before_calls_go_out(@pool, @now + 5.minutes)
    end

    it "should have a call_duration" do
      @pq.call_duration.should == 15.minutes
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
        :obj_type    => 'Pool',
        :obj_id      => @pool.id,
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
      @pool = Factory(:pool)
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
      pool_merger = mock('PoolMerger')
      pool_merger.should_receive(:merge_calls_for_pool).with(@pool, {}).and_return({:foo => 'foo'})
      pool_merger.should_receive(:merge_calls_for_pool).with(@pool, {:foo => 'foo'})
      PoolMerger.should_receive(:new).twice.and_return(pool_merger)
      expect {
        @pq.queue_merge_calls_for_pool(@pool, @now + 5.minutes, 1, {})
      }.to change(DelayedJob, :count).by(1)
      djs = DelayedJob.where(
        :obj_type    => 'Pool',
        :obj_id      => @pool.id,
        :obj_jobtype => 'merge_calls_for_pool',
        :run_at      => @now + 5.minutes + @pq.time_before_first_merge + (@pq.time_between_merges * 1)
      )
      djs.count.should == 1
      YAML.load(djs[0].handler).perform
      DelayedJob.where(
        :obj_type    => 'Pool',
        :obj_id      => @pool.id,
        :obj_jobtype => 'merge_calls_for_pool',
        :run_at      => @now + 5.minutes + @pq.time_before_first_merge + (@pq.time_between_merges * 2)
      ).count.should == 1
    end
    
    it "should run on the 177th time" do
      pool_merger = mock('PoolMerger')
      pool_merger.should_receive(:merge_calls_for_pool).with(@pool, {})
      PoolMerger.should_receive(:new).and_return(pool_merger)
      expect {
        @pq.queue_merge_calls_for_pool(@pool, @now + 5.minutes, 177, {})
      }.to change(DelayedJob, :count).by(1)
      DelayedJob.where(
        :obj_type    => 'Pool',
        :obj_id      => @pool.id,
        :obj_jobtype => 'merge_calls_for_pool',
        :run_at      => @now + 5.minutes + @pq.time_before_first_merge + (@pq.time_between_merges * 177)
      ).count.should == 1
    end

    it "should exit on the 178th time" do
      expect {
        rv = @pq.queue_merge_calls_for_pool(@pool, @now + 5.minutes, 178, {})
        rv.should == true
      }.to_not change(DelayedJob, :count)
    end

  end
end
