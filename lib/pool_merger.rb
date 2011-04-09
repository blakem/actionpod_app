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

  def merge_calls_for_pool(pool, data)
    @tc = TwilioCaller.new
    data = initialize_data(data)
    new_participants = sort_participants(@tc.participants_on_hold_for_pool(pool), data)
    while new_participants.count > 2 do
      create_new_group(new_participants.shift(3), pool, data)
    end
    return data if new_participants.empty?

    if new_participants.count == 1
      participant = new_participants[0]
      if data[:on_hold][participant['call_sid']] && data[:conferences].any?
        room_name = data[:conferences].sort { |a,b| a[1][:members] <=> b[1][:members]}.first[0]
        place_into_conference(participant, room_name, pool.timelimit, data)
      else
       put_on_hold(participant, data)
     end
    else
      if data[:on_hold][new_participants[0]['call_sid']] || data[:on_hold][new_participants[1]['call_sid']]
        create_new_group(new_participants, pool, data)
      else
        new_participants.each do |participant|
          put_on_hold(participant, data)
        end
      end
    end
    data
  end

  def sort_participants(participants, data)
    participants.select { |p|  data[:on_hold][p['call_sid']] } +
    participants.select { |p| !data[:on_hold][p['call_sid']] }
  end

  def put_on_hold(participant, data)
    data[:on_hold][participant['call_sid']] = participant['conference_sid']
  end

  def place_into_conference(participant, room_name, timelimit, data)
    @tc.place_participant_in_conference(participant[:call_sid], room_name, timelimit)
    data[:on_hold].delete(participant['call_sid'])
    data[:conferences][room_name][:members] += 1
  end

  def create_new_group(list, pool, data)
    room_name = next_room(pool, data)
    list.each do |participant|
      place_into_conference(participant, room_name, pool.timelimit, data)
    end
  end

  def next_room(pool, data)
    room_number = data[:next_room]
    data[:next_room] += 1
    conference_name = "Pool#{pool.id}Room#{room_number}"
    data[:conferences][conference_name] = { :name => conference_name, :members => 0 }
    conference_name
  end

  def initialize_data(data)
    if data.empty?
      return {
        :next_room => 1,
        :conferences => {},
        :on_hold => {},
      }
    else
      return  data
    end
  end

end