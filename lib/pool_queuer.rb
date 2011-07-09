class PoolQueuer
  
  def time_before_calls_go_out() 10.minutes end
  def time_between_merges()       5.seconds end
  def time_before_first_merge()  15.seconds end

  def queue_pool(pool, run_time)
    queue_check_before_calls_go_out(pool, run_time)
  end
  
  def args_for_check_before_calls_go_out(pool_id, run_time)
    {
      :obj_type    => 'PoolQueuer', 
      :obj_jobtype => 'check_before_calls_go_out',
      :run_at      => run_time - time_before_calls_go_out,
      :pool_id     => pool_id,      
    }
  end

  def dequeue_pool(pool_id, run_time)
    DelayedJob.where(args_for_check_before_calls_go_out(pool_id, run_time)).each { |dj| dj.destroy }
  end
  
  def queue_check_before_calls_go_out(pool, run_time)
    delay_args = args_for_check_before_calls_go_out(pool.id, run_time)
    delay(delay_args).check_before_calls_go_out(pool, run_time) unless DelayedJob.where(delay_args)[0]
  end
  
  def check_before_calls_go_out(pool, pool_runs_at)
    return if pool.after_call_window(pool_runs_at)
    jobs = DelayedJob.where(
      :run_at => pool_runs_at,
      :pool_id => pool.id,
      :obj_type    => 'Event', 
      :obj_jobtype => 'make_call',
    )
    twilio_caller = TwilioCaller.new
    if jobs.count == 1
      job = jobs.first
      event = Event.find_by_id(job.obj_id)
      if (event)
        if (event.send_sms_reminder)
          twilio_caller.send_sms(event.user.primary_phone.number, 
            "Sorry.  No one else is scheduled for the #{event.time} slot.  This shouldn't happen after we reach a critical mass of users. ;-)")
        end
        conference = Conference.create(
          :pool_id => event.pool_id, 
          :started_at => pool_runs_at, 
          :ended_at => pool_runs_at, 
          :status => 'only_one_scheduled',
        )
        conference.users = [event.user]
      end
      job.destroy
    else
      jobs.each do |job|
        event = Event.find_by_id(job.obj_id)
        if (event and event.send_sms_reminder)
          twilio_caller.send_sms(event.user.primary_phone.number, event.sms_reminder_text)
        end
      end
      self.delay(
        :obj_type    => 'PoolQueuer',
        :obj_jobtype => 'set_heroku_dynos',
        :run_at      => pool_runs_at - 1.minute,
        :pool_id     => pool.id,
      ).set_heroku_dynos(jobs.count)
      self.delay(
        :obj_type    => 'PoolQueuer',
        :obj_jobtype => 'send_logs_to_blake',
        :run_at      => pool_runs_at + 5.minutes,
        :pool_id     => pool.id,
      ).send_logs_to_blake
      self.delay(
        :obj_type    => 'PoolQueuer',
        :obj_jobtype => 'send_one_minute_warning',
        :run_at      => pool_runs_at + pool.timelimit.minutes,
        :pool_id     => pool.id,
      ).send_one_minute_warning(pool.id)
      self.delay(
        :obj_type    => 'PoolQueuer',
        :obj_jobtype => 'end_calls_for_pool',
        :run_at      => pool_runs_at + (pool.timelimit + 1).minutes,
        :pool_id     => pool.id,
      ).end_calls_for_pool(pool.id)
      queue_merge_calls_for_pool(pool, pool_runs_at, 0, {
        :total => jobs.count,
        :waiting_for_events => jobs.map(&:obj_id).sort,
      })
    end
  end

  def send_one_minute_warning(pool_id)
    tropo_caller = TropoCaller.new
    call_sessions = CallSession.where(
      :pool_id => pool_id,
      :call_state => 'placed',
    )
    call_sessions.each { |cs| tropo_caller.send_signal_to_session('onemin', cs.session_id) }
  end

  def end_calls_for_pool(pool_id)
    tropo_caller = TropoCaller.new
    call_sessions = CallSession.where(:pool_id => pool_id)
    call_sessions.each { |cs| tropo_caller.send_signal_to_session('awesome', cs.session_id) }
  end
  
  def queue_merge_calls_for_pool(pool, pool_runs_at, count, data)
    if count > ((pool.timelimit.minutes - time_before_first_merge) / time_between_merges)
      update_conferences(pool, pool_runs_at, data)
      set_heroku_dynos(1)
      return true
    end
    data = PoolMerger.new.merge_calls_for_pool(pool, pool_runs_at, data) if count > 0  
    self.delay(
      :obj_type    => 'PoolMerger',
      :obj_jobtype => 'merge_calls_for_pool',
      :run_at      => pool_runs_at + (time_between_merges * count) + time_before_first_merge,
      :pool_id     => pool.id,
    ).queue_merge_calls_for_pool(pool, pool_runs_at, count+1, data)
  end
  
  def get_heroku_client
    Heroku::Client.new('blakem30@yahoo.com', 'biv1ukor')
  end
  def set_heroku_dynos(dynos)
    get_heroku_client.set_dynos('actionpods', dynos)
  end
  def send_logs_to_blake
    logs = ''
    get_heroku_client.read_logs('actionpods', ['num=500']) do |chunk|
      logs += chunk
    end
    date = Time.now
    UserMailer.deliver_message_to_blake(logs, '15mc Logs for: ' + date.strftime("%l:%M%p on %a %b #{date.day.ordinalize}"))
  end
  
  def update_conferences(pool, started_at, data)
    room_names = []
    data[:placed].each_value do |p|
      room_names.push(p[:room_name]) unless room_names.include?(p[:room_name])
    end
    ended_at = Time.now
    room_names.each do |room_name|
      conference = Conference.where(
        :room_name => room_name, 
        :status => 'in_progress',
        :pool_id => pool.id,
        :started_at => started_at,
      )[0]
      if conference
        conference.status = 'completed'
        conference.ended_at = ended_at
        conference.save
      end
    end 
  end
end