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
    
    it "deletes a queued make_call if it's the only one scheduled" do
      pool = Factory(:pool)
      now = Time.now.utc
      dj = DelayedJob.create(
        :obj_type    => 'Event',
        :obj_jobtype => 'make_call',
        :pool_id     => pool.id,
        :run_at      => now + 5.minutes,
      )
      dj_id = dj.id
      expect {
        @pq.check_before_calls_go_out(pool, now + 5.minutes)
      }.to change(DelayedJob, :count).by(-1)
      DelayedJob.find_by_id(dj_id).should be_nil
    end
    
    it "Sends and SMS if it's the only one scheduled" do
      pool = Factory(:pool)
      now = Time.now.utc
      user = Factory(:user)
      event = Factory(:event, :user_id => user.id)
      dj = DelayedJob.create(
        :obj_type    => 'Event',
        :obj_id      => event.id,
        :obj_jobtype => 'make_call',
        :pool_id     => pool.id,
        :run_at      => now + 5.minutes,
      )
      response = mock('HTTPResponse')
      response.should_receive(:body).and_return('{"foo":"bar"}')
      account = mock('TwilioAccount', :request => response)
      account.should_receive(:request).with(TwilioCaller.new.sms_uri, 'POST', {
        :From => TwilioCaller.new.caller_id,
        :To   => user.primary_phone, 
        :Body => "Sorry.  No one else is scheduled for the 8:00am slot.  This shouldn't happen after we reach a critical mass of users. ;-)"        
      })
      Twilio::RestAccount.should_receive(:new).with("AC2e57bf710b77d765d280786bc07dbacc", "fc9bd67bb8deee6befd3ab0da3973718").and_return(account)
      @pq.check_before_calls_go_out(pool, now + 5.minutes)
    end
    
    it "should queue queue_merge_calls_for_pool on success"
    
  end
end
