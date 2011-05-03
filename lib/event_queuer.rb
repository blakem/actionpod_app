class EventQueuer
  def queue_events(time = Time.now.utc)
    rv = []
    Event.all.each do |event|
      delayed_job_args = queue_event(event, time)
      rv << delayed_job_args if delayed_job_args
    end
    rv
  end
  
  def queue_event(event, time = Time.now.utc)
    next_run_time = event.next_occurrence
    return nil unless next_run_time
    next_run_time = next_run_time.utc
    if next_run_time < time.tomorrow.utc
      delay_args = {
        :obj_type    => 'Event', 
        :obj_id      => event.id, 
        :obj_jobtype => 'make_call',
        :run_at      => next_run_time,
        :pool_id     => event.pool.id
      }
      return nil if DelayedJob.where(delay_args)[0]
      delayed_job = event.delay(delay_args).make_call(next_run_time)
      PoolQueuer.new.queue_pool(event.pool, next_run_time)
      delay_args.merge({:id => delayed_job.id})
    end
  end
end