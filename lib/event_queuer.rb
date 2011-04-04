class EventQueuer
  def queue_events(time = Time.now.utc)
    count = 0
    Event.all.each do |event|
      schedule = event.schedule
      next_run_time = schedule.first.utc
      if next_run_time < Time.now.tomorrow.utc
        event.delay(:run_at => next_run_time).make_call
        count += 1
      end
    end
    count
  end
end