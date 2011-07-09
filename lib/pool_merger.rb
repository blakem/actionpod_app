class PoolMerger

  # Wait until all calls have been answered or hung-up on
  # Get list of new participants
  # Four gets split into two groups of two
  # Split them into groups of 3 using old participants first
    # Put groups of three into a conference room
  
  # Three Cases:
    # 0 left - You're done
    # 1 left
       # leave him there if there is no existing conference
       # leave him there if he's new
       # put him in the smallest conference room if he's old
    # 2 left
       # unite them into a group

  def merge_calls_for_pool(pool, pool_runs_at, data)
    data = initialize_data(data)
    participants_on_hold_for_pool = find_participants_on_hold(pool)
    log_message("STEP A")
    update_meta_data_for_timeslot(participants_on_hold_for_pool, pool, data)
    log_message("STEP B")
    if data[:waiting_for_events].empty? or pool_runs_at < Time.now - self.max_wait_time_to_answer.seconds
      log_message("STEP c")
      (new_participants, placed_participants) = filter_new_participants_that_have_been_placed(participants_on_hold_for_pool, data)
      log_message("STEP d")
      new_participants = sort_participants(new_participants, data)
      log_message("STEP e")
      handle_placed_participants(placed_participants, pool, pool_runs_at, data)
      log_message("STEP f")
      handle_new_participants(new_participants, pool, pool_runs_at, data)
      log_message("STEP g")
    else
      log_message("STEP h")
      participants_on_hold_for_pool.each { |participant| put_on_hold(participant, data) }
      log_message("STEP i")
    end
    log_message("STEP j")    
    log_message(data.inspect)
    data
  end

  def find_participants_on_hold(pool)
    CallSession.where(
      :pool_id => pool.id,
      :call_state => 'on_hold',
    )
  end

  def max_wait_time_to_answer() 60 end
  def rolling_window_size()     12 end

  def update_meta_data_for_timeslot(participants, pool, data)
    remove_stale_on_hold_records(participants, data)
    remove_events_from_waiting_list(participants, pool, data)
  end

  def remove_stale_on_hold_records(participants, data)
    participants_on_hold = data[:on_hold].keys
    new_participant_sids = participants.map{ |p| p.session_id }
    participants_on_hold.each do |sid|
      data[:on_hold].delete(sid) unless new_participant_sids.include?(sid)
    end
  end

  def remove_events_from_waiting_list(participants, pool, data)
    if data[:waiting_for_events].any?
      log_message("Before:" + data[:waiting_for_events].inspect)
      participants.each do |p|
        data[:waiting_for_events].delete(participant_event_id(p))
      end
      log_message("Between:" + data[:waiting_for_events].inspect)
      calls = Call.where("created_at >= ?", Time.now - pool.timelimit.minutes)
      calls.each do |call|
        data[:waiting_for_events].delete(call.event_id) if call.status =~ /completed|onhold/
      end
      log_message("After:" + data[:waiting_for_events].inspect)
    end
  end
  
  def log_message(message)
    puts message if Rails.env.production?
  end

  def handle_new_participants(participants, pool, pool_runs_at, data)
    while participants.count > 2 do
      if participants.count == 4
        handle_four_new_participants(participants, pool, pool_runs_at, data)
      else
        three_participants = pick_three_participants(participants, pool)
        handle_three_new_participants(three_participants, pool, pool_runs_at, data)
      end
    end
    return if participants.empty?

    if participants.count == 1
      handle_one_new_participant(participants.shift, pool, pool_runs_at, data)
    else
      handle_two_new_participants(participants.shift(2), pool, pool_runs_at, data)
    end
  end

  def handle_one_new_participant(participant, pool, pool_runs_at, data)
    if on_hold?(participant, data) && data[:placed].any?
      add_single_participant_to_conference(participant, pool, pool_runs_at, data)
    else
      if hold_count(participant, data) >= max_hold_count && !on_apologized?(participant, data)
        apologize_to_participant(participant, pool, pool_runs_at, data)
      else
        put_on_hold(participant, data)
      end
    end
  end
  
  def handle_two_new_participants(participants, pool, pool_runs_at, data)
    create_new_group(participants, pool, pool_runs_at, data)
  end

  def handle_three_new_participants(participants, pool, pool_runs_at, data)
    create_new_group(participants.shift(3), pool, pool_runs_at, data)
  end

  def handle_four_new_participants(participants, pool, pool_runs_at, data)
    all_participants = participants.shift(4)
    sorted = sort_participants_by_placed_count(all_participants)
    if sorted[0][:user].placed_count == 0
       participant_groups = [all_participants]
    else 
       participant_groups = group_four_by_preference(sorted)
    end
    participant_groups.each do |participant_group|
      create_new_group(participant_group, pool, pool_runs_at, data)
    end
  end
  
  def group_four_by_preference(sorted)
    score1a = compute_pref_score([sorted[0][:user], sorted[1][:user]]) 
    score1b = compute_pref_score([sorted[2][:user], sorted[3][:user]])
    score1 = [score1a[0] + score1b[0], score1a[1] + score1b[1], score1a[2]]
    score2a = compute_pref_score([sorted[0][:user], sorted[2][:user]]) 
    score2b = compute_pref_score([sorted[1][:user], sorted[3][:user]]) 
    score2 = [score2a[0] + score2b[0], score2a[1] + score2b[1], score2a[2]]
    score3a = compute_pref_score([sorted[0][:user], sorted[3][:user]]) 
    score3b = compute_pref_score([sorted[1][:user], sorted[2][:user]]) 
    score3 = [score3a[0] + score3b[0], score3a[1] + score3b[1], score3a[2]]
    score4 = compute_pref_score(sorted.map{ |s| s[:user] })

    sorted_scores = [[score1, 1], [score2, 2], [score3, 3], [score4, 4]].sort_by{ |s|
      [ -s[0][0], s[0][2], s[0][1], -s[1] ]
    }
    best_match = sorted_scores[0][1]
    best_match = 3 if sorted_scores.select { |ss| ss[0][0] != 0 }.empty?
    if best_match == 4
      return [[
        sorted[0][:participant],
        sorted[1][:participant],
        sorted[2][:participant],
        sorted[3][:participant],
      ]]
    elsif best_match == 3
      return [[
        sorted[0][:participant],
        sorted[3][:participant],
      ], [
        sorted[1][:participant],
        sorted[2][:participant],
      ]]
    elsif best_match == 2
      return [[
        sorted[0][:participant],
        sorted[2][:participant],
      ], [
        sorted[1][:participant],
        sorted[3][:participant],
      ]]
    else
      return [[
        sorted[0][:participant],
        sorted[1][:participant],
      ], [
        sorted[2][:participant],
        sorted[3][:participant],
      ]]      
    end
  end
  
  def compute_pref_score(users)
    score = 0
    user_id_diff = 0
    lowest_user_id = users.first.id
    do_pref_check = users.select{ |u| u.preferences.any? }.any?
    users.each do |a|
      lowest_user_id = a.id if a.id < lowest_user_id
      users.each do |b|
        next if a.id == b.id
        user_id_diff += a.id - b.id if a.id > b.id
        if do_pref_check
          score += 1 if a.prefers?(b)
          score -= 2 if a.avoids?(b)
        end
      end
    end
    [score, user_id_diff, users.count, lowest_user_id]
  end

  def sort_participants_by_placed_count(participants)
    participants.map{ |participant|
      {
        :user => User.find_by_id(participant_user_id(participant)),
        :participant => participant,
      }
    }.sort{ |a,b|
      first = a[:user].placed_count <=> b[:user].placed_count
      first != 0 ? first : a[:user].id <=> b[:user].id
    }
  end

  def pick_three_participants(participants, pool)
    index = 0
    users = []
    admin = nil
    newbie = nil
    participants.each do |participant|
      user = User.find_by_id(participant_user_id(participant))
      users.push({
        :user => user,
        :index => index,
      })
      if user.admin
        admin ||= user
      elsif user.placed_count == 0
        newbie ||= user
      end
      index += 1
    end

    if admin
      admin_hash = users.select{ |h| h[:user] == admin}.first
      users.delete_if{ |h| h[:user] == admin }
      sorted = users.sort_by{ |u| u[:user].placed_count }
      picked_indices = [admin_hash, sorted[0], sorted[1]].map { |h| h[:index] }
    elsif newbie
      newbie_hash = users.select{ |h| h[:user] == newbie }.first
      users.delete_if{ |h| h[:user] == newbie }
      sorted = users.sort_by{ |u| u[:user].placed_count }
      picked_indices = [newbie_hash[:index]]
      pick_users_with_minimum_placed_count(picked_indices, sorted, 16)
      pick_users_with_minimum_placed_count(picked_indices, sorted, 1)
      pick_users_with_minimum_placed_count(picked_indices, sorted, 0)
    else
      print_debug_info = true if Rails.env.production?
      puts "Computing highest score for #{users.size}" if print_debug_info
      count = 0
      highest_score = pick_default_three(users, pool)
      users[0..self.rolling_window_size-1].combination(3).each do |combo|
        new_score = compute_pref_score(combo.map { |a| a[:user] })
        # puts "ExistingScore: " + highest_score.inspect + " - NewScore: " + new_score.inspect
        highest_score = [new_score, combo.map { |a| a[:index] }] if highest_score.empty? or 
          new_score_is_higher?(new_score, highest_score[0], pool)
          # puts "PickedScore:   " + highest_score.inspect
        count += 1
      end
      picked_indices = highest_score[1]
      puts "Done Computing highest score for #{users.size} : #{count} computations" if print_debug_info
    end
    
    picked = []
    picked_indices.sort.reverse.each do |i|
      picked << participants.slice!(i)
    end
    return picked.reverse
  end

  def pick_default_three(users_data, pool)
    if pool.merge_type == 1
      picks = [0, 1, 2]
    elsif pool.merge_type == 2
      picks = pick_three_random_numbers_below(users_data.count)
    end
    [
      compute_pref_score([
        users_data[picks[0]][:user], 
        users_data[picks[1]][:user],
        users_data[picks[2]][:user],
      ]), picks
    ]
  end
  
  def pick_three_random_numbers_below(count)
    (0..count-1).to_a.shuffle[0..2]
  end
  
  def new_score_is_higher?(new_score, old_score, pool)
    return true if new_score[0] > old_score[0]
    return false if pool.merge_type == 2
    if new_score[0] == old_score[0]
      return true if new_score[1] < old_score[1]
      if new_score[1] == old_score[1]
        return true if new_score[3] < old_score[3]
      end
    end
    return false
  end

  def pick_users_with_minimum_placed_count(picked_indices, sorted, value)
    return if picked_indices.count >= 3
    delete_ids = []
    sorted.each do |data|
      user = data[:user]
      if picked_indices.count < 3 and user.placed_count >= value
        picked_indices << data[:index]
        delete_ids << user.id
      end
    end
    sorted.delete_if{ |h| delete_ids.include?(h[:user].id) }
  end

  def apologize_to_participant(participant, pool, pool_runs_at, data)
    put_on_apologized(participant, data)
    put_on_hold(participant, data)
    event = Event.find(participant_event_id(participant))
    TropoCaller.new.apologize_no_other_participants(participant.session_id, event.id, data[:total])
    if (event.send_sms_reminder)
      TropoCaller.new.send_sms(
        Event.find(participant_event_id(participant)).user.primary_phone.number,
        "Sorry about that... I couldn't find anyone else for the call.  That shouldn't happen once we reach critical mass. ;-)",
      )
    end
    conference = Conference.create(
      :pool_id    => pool.id,
      :started_at => pool_runs_at,
      :ended_at   => Time.now,
      :status     => 'only_one_answered'
    )
    conference.users = [event.user]
  end
      
  def on_hold?(participant, data)
    hold_count(participant, data) == 0 ? false : true
  end

  def on_apologized?(participant, data)
    apologized_count(participant, data) == 0 ? false : true
  end
  
  def max_hold_count
    2
  end

  def hold_count(participant, data)
    data[:on_hold][participant.session_id] || 0
  end

  def apologized_count(participant, data)
    data[:apologized][participant.session_id] || 0
  end

  def placed?(participant, data)
    find_placed_data_for_participant(participant, data).any?
  end
  
  def find_placed_data_for_participant(participant, data)
    event_id = participant_event_id(participant)
    data[:placed].values.select{ |p| p[:event_id] == event_id }
  end

  def handle_placed_participants(participants, pool, pool_runs_at, data)
    participants.each do |participant|
      if hold_count(participant, data) > 1
        add_single_participant_to_conference(participant, pool, pool_runs_at, data)
      else
        put_on_hold(participant, data)
      end
    end
  end
  
  def filter_new_participants_that_have_been_placed(participants, data)
    return [participants.select { |p| !placed?(p, data) }, participants.select { |p| placed?(p, data) }] 
  end
  
  def sort_participants(participants, data)
    participants.sort{ |a,b| 
      participant_user_id(a) <=> participant_user_id(b)
    }
  end

  def put_on_hold(participant, data)
    session_id = participant.session_id
    data[:on_hold][session_id] ||= 0
    data[:on_hold][session_id] += 1 
  end

  def put_on_apologized(participant, data)
    session_id = participant.session_id
    data[:apologized][session_id] ||= 0
    data[:apologized][session_id] += 1 
  end
  
  def take_off_hold(participant, data)
    data[:on_hold].delete(participant.session_id)
    participant.call_state = 'placed'
    participant.save
  end
      
  def place_into_conference(participant, room_name, timelimit, start_time, data, event_ids = [])
    end_time = start_time + timelimit.minutes + 1.minute
    timelimit_insec = (end_time - Time.now).to_i
    timelimit_insec = timelimit * 60 if timelimit_insec <= 0;
    log_message("TimeLimit:" + timelimit_insec.to_s + " UserID:" + participant_user_id(participant).to_s)
    TropoCaller.new.place_participant_in_conference(participant.session_id, room_name, timelimit_insec, participant_event_id(participant), event_ids)
    user = User.find_by_id(participant_user_id(participant))
    if user
      user.placed_count += 1
      user.save
    end
    take_off_hold(participant, data)
    data[:placed][participant.session_id] = {
      :room_name => room_name,
      :event_id  => participant_event_id(participant),
      :time => Time.now,
    }
  end

  def create_new_group(list, pool, pool_runs_at, data)
    room_name = next_room(pool, data)
    event_ids = list.map { |p| participant_event_id(p) }
    conference = Conference.create(
      :room_name  => room_name,
      :status     => 'in_progress',
      :pool_id    => pool.id,
      :started_at => pool_runs_at,
    )
    conference.users = event_ids.map{ |eid| event = Event.find_by_id(eid); event ? event.user : nil }.select{ |u| u }
    list.each do |participant|
      place_into_conference(participant, room_name, pool.timelimit, pool_runs_at, data, event_ids)
    end
    send_email_for_new_conference(conference)
  end

  def send_email_for_new_conference(conference)
    conference.users.each do |user|
      send_conference_email_to_user(user, conference.users, conference.pool)
    end
  end

  def send_conference_email_to_user(user, participants, pool)
    return unless Rails.env.production? && pool.send_conference_email
    UserMailer.deliver_conference_email(user, participants)
  end

  def add_single_participant_to_conference(participant, pool, pool_runs_at, data)
    room_name = pick_room_for_single_participant(participant, data)
    if room_name
      participant_event_id = participant_event_id(participant)
      event_ids = event_ids_for_conference_room(room_name, data)
      place_into_conference(participant, room_name, pool.timelimit, pool_runs_at, data, event_ids)
      conference = Conference.where(:room_name => room_name, :status => 'in_progress', :pool_id => pool.id, :started_at => pool_runs_at)[0]
      event = Event.find_by_id(participant_event_id)
      if (event and conference)
        user = event.user
        unless conference.users.include?(user)
          conference.users << user 
          send_conference_email_to_user(user, conference.users, conference.pool)
        end
      end
    else
      other_participant = pluck_out_participant(data)
      create_new_group([other_participant, participant], pool, pool_runs_at, data)
    end
  end
  
  def pluck_out_participant(data)
    room_name = largest_conference_room(data)
    participant = participants_in_room(room_name, data).sort{ |a,b| a[:time] <=> b[:time] }.last
    CallSession.find_by_event_id(participant[:event_id])
  end

  def participants_in_room(room_name, data)
    participants = []
    data[:placed].each_pair do |sid, v|
      next unless v[:room_name] == room_name
      participants.push(v.merge({:sid => sid}))
    end
    participants
  end

  def pick_room_for_single_participant(participant, data)
    if placed?(participant, data)
      last_room_name = find_placed_data_for_participant(participant, data).first[:room_name]
      if conference_has_other_callers(last_room_name, participant, data)
        last_room_name
      else
        available_small_conference(data)
      end        
    else
      available_small_conference(data)
    end
  end
  
  def available_small_conference(data)
    if smallest_conference_room_size(data) < 4
      smallest_conference_room(data)
    else
      nil
    end
  end
  
  def conference_has_other_callers(room_name, participant, data)
    participants = participants_still_on_call(room_name, data)
    participants.delete(participant.session_id)
    participants.any?
  end
  
  def participants_still_on_call(room_name, data)
    participants = []
    data[:placed].each_pair do |sid, v|
      next unless v[:room_name] == room_name
      call = Call.find_by_Sid(sid)
      next unless call && !call.Duration
      participants.push(sid)
    end
    participants
  end
    
  def smallest_conference_room(data)
    conferences_from_placed(data).first[0]
  end    

  def largest_conference_room(data)
    conferences_from_placed(data).last[0]
  end    

  def smallest_conference_room_size(data)
    conferences_from_placed(data).first[1][:members]
  end

  def conferences_from_placed(data)
    conferences = {}
    event_ids = []
    data[:placed].each_value do |v|
      next if event_ids.include?(v[:event_id])
      event_ids.push(v[:event_id])
      conferences[v[:room_name]] ||= {}
      conferences[v[:room_name]][:members] ||= 0
      conferences[v[:room_name]][:members] += 1
    end
    conferences.sort{ |a,b| a[1][:members] <=> b[1][:members] }
  end

  def event_ids_for_conference_room(room_name, data)
    data[:placed].select{ |k,v| v[:room_name] == room_name }.values.map{ |p| p[:event_id] }.uniq
  end

  def participant_event_id(participant)
    participant.event_id.to_i
  end

  def participant_user_id(participant)
    participant.user_id.to_i
  end

  def next_room(pool, data)
    room_number = data[:next_room]
    data[:next_room] += 1
    conference_name = "15mcPool#{pool.id}Room#{room_number}"
    conference_name
  end

  def initialize_data(data)
    data = {} if data.empty?
    data[:total]              = 0 unless data.has_key?(:total)
    data[:waiting_for_events] = [] unless data.has_key?(:waiting_for_events)
    data[:next_room]          = 1  unless data.has_key?(:next_room)
    data[:on_hold]            = {} unless data.has_key?(:on_hold)
    data[:placed]             = {} unless data.has_key?(:placed)
    data[:apologized]         = {} unless data.has_key?(:apologized)
    data
  end

end