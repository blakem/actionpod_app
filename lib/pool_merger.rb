class PoolMerger

  # Get list of new participants
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
    new_participants = filter_new_participants_that_have_been_placed(participants_on_hold_for_pool, data)
    new_participants = sort_participants(new_participants, data)
    increment_on_hold_count_for_filtered_participants(participants_on_hold_for_pool, data)
    while new_participants.count > 2 do
      create_new_group(new_participants.shift(3), pool, pool_runs_at, data)
    end
    return data if new_participants.empty?

    if new_participants.count == 1
      participant = new_participants[0]
      if on_hold?(participant, data) && data[:placed].any?
        add_single_participant_to_conference(participant, pool, pool_runs_at, data)
      else
        if hold_count(participant, data) >= max_hold_count
          apologize_to_participant(participant, pool, pool_runs_at, data)
        else
          put_on_hold(participant, data)
        end
      end
    else
      if on_hold?(new_participants[0], data) || on_hold?(new_participants[1], data)
        create_new_group(new_participants, pool, pool_runs_at, data)
      else
        new_participants.each do |participant|
          put_on_hold(participant, data)
        end
      end
    end
    data
  end

  def apologize_to_participant(participant, pool, pool_runs_at, data)
    take_off_hold(participant, data)
    @tc.apologize_no_other_participants(participant[:call_sid], data[:total])
    @tc.send_sms(
      Event.find(participant_event_id(participant)).user.primary_phone,
      "Sorry about that... I couldn't find anyone else for the call.  That shouldn't happen once we reach critical mass. ;-)",
    )
    event = Event.find(participant_event_id(participant))
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
  
  def max_hold_count
    4
  end

  def hold_count(participant, data)
    data[:on_hold][participant['call_sid']] || 0
  end

  def placed?(participant, data)
    data[:placed][participant['call_sid']] ? true : false
  end

  def incoming?(participant)
    participant['conference_friendly_name'] =~ /Incoming/
  end

  def increment_on_hold_count_for_filtered_participants(participants, data)
    participants.select { |p| (incoming?(p) && hold_count(p, data) <= 1)}.each do |p|
      put_on_hold(p, data)
    end
  end
  
  def filter_new_participants_that_have_been_placed(participants, data)
    participants.select { |p| !placed?(p, data) || (incoming?(p) && hold_count(p, data) > 1)}
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
  
  def take_off_hold(participant, data)
    data[:on_hold].delete(participant['call_sid'])
  end
      
  def place_into_conference(participant, room_name, timelimit, data, event_ids = [])
    @tc.place_participant_in_conference(participant[:call_sid], room_name, timelimit, event_ids)
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
      place_into_conference(participant, room_name, pool.timelimit, data, event_ids)
    end
  end

  def add_single_participant_to_conference(participant, pool, pool_runs_at, data)
    room_name = smallest_conference_room(data)
    participant_event_id = participant_event_id(participant)
    event_ids = [participant_event_id] + event_ids_for_conference_room(room_name, data)
    place_into_conference(participant, room_name, pool.timelimit, data, event_ids)
    conference = Conference.where(:room_name => room_name, :status => 'in_progress', :pool_id => pool.id, :started_at => pool_runs_at)[0]
    event = Event.find_by_id(participant_event_id)
    conference.users << event.user if event
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
    data[:placed].select{ |k,v| v[:room_name] == room_name }.values.map{ |p| p[:event_id] }
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
    conference_name = "Pool#{pool.id}Room#{room_number}"
    conference_name
  end

  def initialize_data(data)
    data = {} if data.empty?
    data[:next_room]   = 1  unless data.has_key?(:next_room)
    data[:on_hold]     = {} unless data.has_key?(:on_hold)
    data[:placed]      = {} unless data.has_key?(:placed)
    data
  end

end