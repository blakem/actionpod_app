class EventQueuer
  def queue_events(time = Time.now.utc)
    rv = []
    Event.all.each do |event|
      next_run_time = event.schedule.next_occurrence.utc
      if next_run_time < time.tomorrow.utc
        delay_args = {
          :obj_type    => 'Event', 
          :obj_id      => event.id, 
          :obj_jobtype => 'make_call',
          :run_at      => next_run_time
        }
        next if DelayedJob.where(delay_args)[0]
        delayed_job = event.delay(delay_args).make_call
        rv << delay_args.merge({:id => delayed_job.id})
      end
    end
    rv
  end
  
end