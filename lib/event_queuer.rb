class EventQueuer
  def queue_events(time = Time.now)
    Event.all.each do |event|
      if event.schedule.occurs_on?(time)
        event.delay.make_call
      end
    end
  end
end