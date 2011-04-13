class PoolQueuer
  
  def time_before_calls_go_out
    10.minutes
  end
  
  def time_between_merges
    5.seconds
  end

  def time_before_first_merge
    15.seconds
  end

  def call_duration
    15.minutes
  end
  
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
        TwilioCaller.new.send_sms(event.user.primary_phone, 
          "Sorry.  No one else is scheduled for the #{event.time} slot.  This shouldn't happen after we reach a critical mass of users. ;-)")
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
      queue_merge_calls_for_pool(pool, pool_runs_at, 0, {:total => jobs.count})
    end
  end
  
  def queue_merge_calls_for_pool(pool, pool_runs_at, count, data)
    if count > ((call_duration - time_before_first_merge) / time_between_merges)
      create_conferences(pool, pool_runs_at, data)
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

  def create_conferences(pool, started_at, data)
    conferences = {}
    data[:placed].each_value do |p|
      event = Event.find_by_id(p[:event_id])
      next unless event
      user_id = event.user.id
      conferences[p[:room_name]] ||= {}
      conferences[p[:room_name]][:user_ids] ||= []
      conferences[p[:room_name]][:user_ids].push(user_id)
      conferences[p[:room_name]][:room_name] = p[:room_name]
    end
    ended_at = Time.now
    conferences.each do |k,v|
      conference = Conference.create(
        :room_name => v[:room_name], 
        :status => 'completed',
        :pool_id => pool.id,
        :started_at => started_at,
        :ended_at => ended_at,
      )
      conference.users = v[:user_ids].map{ |user_id| User.find(user_id) }
    end 
  end
end