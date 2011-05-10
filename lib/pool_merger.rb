class PoolMerger

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
       # if either is old unite them
       # if they are both new leave them there

  def merge_calls_for_pool(pool, pool_runs_at, data)
    @tc = TwilioCaller.new
    data = initialize_data(data)
    participants_on_hold_for_pool = @tc.participants_on_hold_for_pool(pool)
    update_meta_data_for_timeslot(participants_on_hold_for_pool, pool, data)
    if data[:waiting_for_events].empty? or pool_runs_at < Time.now - self.max_wait_time_to_answer.seconds
      (new_participants, placed_participants) = filter_new_participants_that_have_been_placed(participants_on_hold_for_pool, data)
      new_participants = sort_participants(new_participants, data)
      handle_placed_participants(placed_participants, pool, pool_runs_at, data)
      handle_new_participants(new_participants, pool, pool_runs_at, data)
    end
    data
  end

  def max_wait_time_to_answer
    35
  end

  def update_meta_data_for_timeslot(participants, pool, data)
    remove_stale_on_hold_records(participants, data)
    remove_events_from_waiting_list(participants, pool, data)
  end

  def remove_stale_on_hold_records(participants, data)
    participants_on_hold = data[:on_hold].keys
    new_participant_sids = participants.map{ |p| p[:call_sid] }
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
        three_participants = pick_three_participants(participants)
        handle_three_new_participants(three_participants, pool, pool_runs_at, data)
      end
    end
    return if participants.empty?

    if participants.count == 1
      handle_one_new_participant(participants[0], pool, pool_runs_at, data)
    else
      handle_two_new_participants(participants, pool, pool_runs_at, data)
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
    if on_hold?(participants[0], data) || on_hold?(participants[1], data)
      create_new_group(participants, pool, pool_runs_at, data)
    else
      participants.each do |participant|
        put_on_hold(participant, data)
      end
    end
  end

  def handle_three_new_participants(participants, pool, pool_runs_at, data)
    create_new_group(participants.shift(3), pool, pool_runs_at, data)
  end

  def handle_four_new_participants(participants, pool, pool_runs_at, data)
    users = {}
    all_participants = participants.shift(4)
    all_participants.each_with_index do |participant, i|
      user = User.find_by_id(participant_user_id(participant))
      users[user.id] = {
        :user => user,
        :index => i,
      }
    end
    sorted = users.sort{ |a,b| 
      first = a[1][:user].placed_count <=> b[1][:user].placed_count
      first != 0 ? first : a[0] <=> b[0]
    }
    if sorted[0][1][:user].placed_count == 0
      create_new_group(all_participants, pool, pool_runs_at, data)
    else
      handle_two_new_participants([all_participants[sorted[0][1][:index]], all_participants[sorted[3][1][:index]]], pool, pool_runs_at, data)
      handle_two_new_participants([all_participants[sorted[1][1][:index]], all_participants[sorted[2][1][:index]]], pool, pool_runs_at, data)
    end
  end

  def pick_three_participants(participants)
    index = 0
    users = {}
    admin = nil
    newbie = nil
    participants.each do |participant|
      user = User.find_by_id(participant_user_id(participant))
      users[user.id] = {
        :user => user,
        :index => index,
      }
      if user.admin
        admin ||= user
      elsif user.placed_count == 0
        newbie ||= user
      end
      index += 1
    end

    if admin
      admin_hash = users.delete(admin.id)
      sorted = users.sort{ |a,b| a[1][:user].placed_count <=> b[1][:user].placed_count }
      picked_indices = [admin_hash[:index], sorted[0][1][:index], sorted[1][1][:index]]
    elsif newbie
      newbie_hash = users.delete(newbie.id)
      sorted = users.sort{ |a,b| a[1][:user].placed_count <=> b[1][:user].placed_count }
      picked_indices = [newbie_hash[:index]]
      pick_users_with_minimum_placed_count(picked_indices, sorted, 16)
      pick_users_with_minimum_placed_count(picked_indices, sorted, 1)
      pick_users_with_minimum_placed_count(picked_indices, sorted, 0)
    else
      picked_indices = [0,1,2]
    end
    
    picked = []
    picked_indices.sort.reverse.each do |i|
      picked << participants.slice!(i)
    end
    return picked.reverse
  end

  def pick_users_with_minimum_placed_count(picked_indices, sorted, value)
    return if picked_indices.count >= 3
    delete_ids = []
    sorted.each do |data|
      user = data[1][:user]
      if picked_indices.count < 3 and user.placed_count >= value
        picked_indices << data[1][:index]
        delete_ids << user.id
      end
    end
    delete_ids.each { |i| sorted.delete(i) }
  end

  def apologize_to_participant(participant, pool, pool_runs_at, data)
    put_on_apologized(participant, data)
    put_on_hold(participant, data)
    event = Event.find(participant_event_id(participant))
    @tc.apologize_no_other_participants(participant[:call_sid], event.id, data[:total])
    if (event.send_sms_reminder)
      @tc.send_sms(
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
    8
  end

  def hold_count(participant, data)
    data[:on_hold][participant['call_sid']] || 0
  end

  def apologized_count(participant, data)
    data[:apologized][participant['call_sid']] || 0
  end

  def placed?(participant, data)
    data[:placed][participant['call_sid']] ? true : false
  end

  def incoming?(participant)
    participant['conference_friendly_name'] =~ /Incoming/
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
      first_check = hold_count(b, data) <=> hold_count(a, data)
      first_check != 0 ? first_check : participant_user_id(a) <=> participant_user_id(b)
    }
  end

  def put_on_hold(participant, data)
    data[:on_hold][participant['call_sid']] ||= 0
    data[:on_hold][participant['call_sid']] += 1 
  end

  def put_on_apologized(participant, data)
    data[:apologized][participant['call_sid']] ||= 0
    data[:apologized][participant['call_sid']] += 1 
  end
  
  def take_off_hold(participant, data)
    data[:on_hold].delete(participant['call_sid'])
  end
      
  def place_into_conference(participant, room_name, timelimit, start_time, data, event_ids = [])
    end_time = start_time + timelimit.minutes + 1.minute
    timelimit_insec = (end_time - Time.now).to_i
    timelimit_insec = timelimit * 60 if timelimit_insec <= 0;
    @tc.place_participant_in_conference(participant[:call_sid], room_name, timelimit_insec, participant_event_id(participant), event_ids)
    user = User.find_by_id(participant_user_id(participant))
    if user
      user.placed_count += 1
      user.save
    end
    take_off_hold(participant, data)
    data[:placed][participant['call_sid']] = {
      :room_name => room_name,
      :event_id  => participant_event_id(participant)
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
      send_conference_email_to_user(user, conference.users)
    end
  end

  def send_conference_email_to_user(user, participants)
    return unless Rails.env.production?
    UserMailer.deliver_conference_email(user, participants)
  end

  def add_single_participant_to_conference(participant, pool, pool_runs_at, data)
    room_name = pick_room_for_single_participant(participant, data)
    participant_event_id = participant_event_id(participant)
    event_ids = event_ids_for_conference_room(room_name, data)
    place_into_conference(participant, room_name, pool.timelimit, pool_runs_at, data, event_ids)
    conference = Conference.where(:room_name => room_name, :status => 'in_progress', :pool_id => pool.id, :started_at => pool_runs_at)[0]
    event = Event.find_by_id(participant_event_id)
    if (event and conference)
      user = event.user
      unless conference.users.include?(user)
        conference.users.each do |other_participant|
          send_conference_email_to_user(other_participant, [user])
        end
        conference.users << user 
        send_conference_email_to_user(user, conference.users)
      end
    end
  end

  def pick_room_for_single_participant(participant, data)
    if placed?(participant, data)
      last_room_name = data[:placed][participant[:call_sid]][:room_name]
      if conference_has_other_callers(last_room_name, participant, data)
        last_room_name
      else
        smallest_conference_room(data)
      end        
    else
      smallest_conference_room(data)
    end
  end
  
  def conference_has_other_callers(room_name, participant, data)
    participants = participants_still_on_call(room_name, data)
    participants.delete(participant[:call_sid])
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
    conferences = {}
    data[:placed].each_value do |v|
      conferences[v[:room_name]] ||= {}
      conferences[v[:room_name]][:members] ||= 0
      conferences[v[:room_name]][:members] += 1
    end
    conferences.sort { |a,b| a[1][:members] <=> b[1][:members]}.first[0]
  end    

  def event_ids_for_conference_room(room_name, data)
    data[:placed].select{ |k,v| v[:room_name] == room_name }.values.map{ |p| p[:event_id] }.uniq
  end

  def participant_event_id(participant)
    participant[:conference_friendly_name] =~ /Event(\d+)/; 
    $1.to_i
  end

  def participant_user_id(participant)
    participant[:conference_friendly_name] =~ /User(\d+)/; 
    $1.to_i
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