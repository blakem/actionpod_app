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
    new_participants = @tc.participants_on_hold_for_pool(pool)
    return data if new_participants.empty?
    room_name = next_room(pool, data)
    new_participants.each do |participant|
      @tc.place_participant_in_conference(participant[:call_sid], room_name, pool.timelimit)
      data[:conferences][0][:members] += 1
    end
    data
  end

  def next_room(pool, data)
    room_number = data[:next_room]
    data[:next_room] += 1
    conference = "Pool#{pool.id}Room#{room_number}"
    data[:conferences] << { :name => conference, :members => 0 }
    conference
  end

  def initialize_data(data)
    if data.empty?
      return {
        :next_room => 1,
        :conferences => [],
        :on_hold => [],
      }
    else
      return  data
    end
  end

end