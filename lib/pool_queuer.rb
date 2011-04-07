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
      job = jobs.first
      event = Event.find_by_id(job.obj_id)
      if (event)
        TwilioCaller.new.send_sms(
          event.user.primary_phone, 
          "Sorry.  No one else is scheduled for the #{event.time} slot.  This shouldn't happen after we reach a critical mass of users. ;-)"
        )
      end
      job.destroy
    else 
      # Schedule the next piece
    end
  end
end