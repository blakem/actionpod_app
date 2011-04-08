class PoolMerger

  def merge_calls_for_pool(pool, data)
    @tc = TwilioCaller.new
    @tc.participants_on_hold_for_pool(pool).each do |participant|
      @tc.place_participant_in_conference(participant[:call_sid], "Pool#{pool.id}Room1", pool.timelimit)
    end
  end

end