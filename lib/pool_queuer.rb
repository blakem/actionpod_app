class PoolQueuer
  
  def time_before_calls_go_out
    5.minutes
  end
  
  def queue_pool(pool, run_time)
    true
  end
  
  def check_before_calls_go_out(pool, pool_runs_at)
    jobs = DelayedJob.where(
      :run_at => pool_runs_at,
      :pool_id => pool.id,
      :obj_type    => 'Event', 
      :obj_jobtype => 'make_call',
    )
    if jobs.count == 1
      jobs.first.destroy
      # Send SMS
    end
    # Schedule the next piece
  end
end