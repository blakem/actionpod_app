require 'spec_helper'

describe PoolQueuer do
  before(:each) do
    @pq = PoolQueuer.new
  end

  it "time_before_calls_go_out" do
    @pq.time_before_calls_go_out.should == 10.minutes
  end

  it "should respond to queue_pool" do
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
