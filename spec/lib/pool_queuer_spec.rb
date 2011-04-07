require 'spec_helper'

describe PoolQueuer do
  it "should respond to queue_pool" do
    pq = PoolQueuer.new
    pool = Factory(:pool)
    pq.queue_pool(pool, Time.now.utc).should be_true
  end
end
