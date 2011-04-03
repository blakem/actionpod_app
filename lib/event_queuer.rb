class EventQueuer
  def queue_events(time = Time.now.utc)
    Event.all.each do |event|
      schedule = event.schedule
      next_run_time = schedule.first.utc
      if next_run_time < Time.now.tomorrow.utc
        event.delay(:run_at => next_run_time).make_call
      end
    end
  end
end