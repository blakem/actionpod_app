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
    next_run_time = event.schedule.next_occurrence.utc
    if next_run_time < time.tomorrow.utc
      delay_args = {
        :obj_type    => 'Event', 
        :obj_id      => event.id, 
        :obj_jobtype => 'make_call',
        :run_at      => next_run_time
      }
      return nil if DelayedJob.where(delay_args)[0]
      delayed_job = event.delay(delay_args).make_call
      queue_merge_events_for_pool(event.pool, next_run_time)
      delay_args.merge({:id => delayed_job.id})
    end
  end
  
  def queue_merge_events_for_pool(pool, run_time)
    twilio_caller = TwilioCaller.new
    (1..180).each do |i|
      delay_args = {
        :obj_type    => 'Pool',
        :obj_id      => pool.id,
        :obj_jobtype => 'merge_calls_for_pool',
        :run_at      => run_time + (i*5).seconds
      }
      next if DelayedJob.where(delay_args)[0]
      delayed_job = twilio_caller.delay(delay_args).merge_calls_for_pool(pool)
    end
  end
end