require 'spec_helper'

describe PoolMerger do
  before(:each) do
    @pm = PoolMerger.new
    @pool = Factory(:pool)
    @tc = mock('TwilioCaller')
    TwilioCaller.stub(:new).and_return(@tc)
    offset_time = 5.minutes
    @pool_runs_at = Time.now - offset_time
    @timelimit_insec = (((@pool.timelimit + 1) * 60) - offset_time) - 1
  end

  describe "merge_calls_for_pool" do
    it "does nothing with zero new participants" do
      @tc.should_receive(:participants_on_hold_for_pool).with(@pool).and_return(participant_list(0))
      @pm.merge_calls_for_pool(@pool, @pool_runs_at, {}).should == {
        :next_room   => 1,
        :on_hold     => {},
        :placed      => {},
        :apologized  => {},
      }
    end

    it "initializes the hash even when passed :total" do
      @tc.should_receive(:participants_on_hold_for_pool).with(@pool).and_return(participant_list(0))
      @pm.merge_calls_for_pool(@pool, @pool_runs_at, {:total => 3}).should == {
        :next_room   => 1,
        :total => 3,
        :on_hold     => {},
        :placed      => {},
        :apologized  => {},
      }
    end
    
    describe "zero participants" do
      it "should clear out the on_hold status of anyone who's not currently there" do
        new_participants = participant_list(0)
        data = @pm.initialize_data({})
        data[:on_hold] = {
          "CA9fa67e8696b60ee1ca1e75ec81ef85e7XXX1" => 1,          
        }
        @tc.should_receive(:participants_on_hold_for_pool).with(@pool).and_return(new_participants)
        @pm.merge_calls_for_pool(@pool, @pool_runs_at, data).should == {
          :next_room   => 1,
          :on_hold     => {},
          :placed      => {},
          :apologized  => {},
        }
      end
    end
    
    describe "single participant" do      
      it "should carry over if we haven't seen them" do
        new_participants = participant_list(1)
        @tc.should_receive(:participants_on_hold_for_pool).with(@pool).and_return(new_participants)
        @pm.merge_calls_for_pool(@pool, @pool_runs_at, {}).should == {
          :next_room   => 1,
          :on_hold     => {
            "CA9fa67e8696b60ee1ca1e75ec81ef85e7XXX1" => 1,
          },
          :placed      => {},
          :apologized  => {},
        }
      end

      it "should carry over if there is no existing conference room even if he's old" do
        new_participants = participant_list(1)
        @tc.should_receive(:participants_on_hold_for_pool).with(@pool).and_return(new_participants)
        data = @pm.initialize_data({})
        data[:on_hold] = {
          "CA9fa67e8696b60ee1ca1e75ec81ef85e7XXX1" => 1,          
        }
        @pm.merge_calls_for_pool(@pool, @pool_runs_at, data).should == {
          :next_room   => 1,
          :on_hold     => {
            "CA9fa67e8696b60ee1ca1e75ec81ef85e7XXX1" => 2,
          },
          :placed      => {},
          :apologized  => {},
        }
      end

      it "should tell him sorry and end call if he's been waiting a long time" do
        user = Factory(:user)
        phone = Factory(:phone, :user_id => user.id, :primary => true)
        event = Factory(:event, :user_id => user.id, :pool_id => @pool.id, :send_sms_reminder => true)
        new_participants = participant_list(1)
        new_participants[0][:conference_friendly_name] = "15mcHoldEvent#{event.id}User#{user.id}Pool555"
        @tc.should_receive(:participants_on_hold_for_pool).exactly(3).times.with(@pool).and_return(new_participants)
        @tc.should_receive(:apologize_no_other_participants).with('CA9fa67e8696b60ee1ca1e75ec81ef85e7XXX1', event.id, 2)
        @tc.should_receive(:send_sms).with(phone.number,
          "Sorry about that... I couldn't find anyone else for the call.  That shouldn't happen once we reach critical mass. ;-)"
        )
        data = @pm.initialize_data({})
        data[:on_hold] = {
          "CA9fa67e8696b60ee1ca1e75ec81ef85e7XXX1" => 7,
        }
        data[:total] = 2
        data = @pm.merge_calls_for_pool(@pool, @pool_runs_at, data)
        data.should == {
          :total       => 2,
          :next_room   => 1,
          :on_hold     => {
            "CA9fa67e8696b60ee1ca1e75ec81ef85e7XXX1" => 8,
          },
          :placed      => {},
          :apologized  => {},
        }
        data = @pm.merge_calls_for_pool(@pool, @pool_runs_at, data)
        data.should == {
          :total       => 2,
          :next_room   => 1,
          :on_hold     => {
            "CA9fa67e8696b60ee1ca1e75ec81ef85e7XXX1" => 9,
          },
          :apologized  => {
            "CA9fa67e8696b60ee1ca1e75ec81ef85e7XXX1" => 1,
          },
          :placed      => {},
        }
        data = @pm.merge_calls_for_pool(@pool, @pool_runs_at, data)
        data.should == {
          :total       => 2,
          :next_room   => 1,
          :on_hold     => {
            "CA9fa67e8696b60ee1ca1e75ec81ef85e7XXX1" => 10,
          },
          :apologized  => {
            "CA9fa67e8696b60ee1ca1e75ec81ef85e7XXX1" => 1,
          },
          :placed      => {},
        }
        conference = Conference.where(
          :pool_id    => event.pool_id,
          :started_at => @pool_runs_at,
          :status     => 'only_one_answered'
        )[0]
        conference.ended_at.should > @pool_runs_at
        conference.ended_at.should < Time.now
        conference.users.should == [user]
        user.reload
        user.placed_count.should == 0
      end

      it "don't send sms apology if send_sms_reminders is turned off" do
        user = Factory(:user)
        phone = Factory(:phone, :user_id => user.id, :primary => true)
        event = Factory(:event, :user_id => user.id, :pool_id => @pool.id, :send_sms_reminder => false)
        new_participants = participant_list(1)
        new_participants[0][:conference_friendly_name] = "15mcHoldEvent#{event.id}User#{user.id}Pool555"
        @tc.should_receive(:participants_on_hold_for_pool).twice.with(@pool).and_return(new_participants)
        @tc.should_receive(:apologize_no_other_participants).with('CA9fa67e8696b60ee1ca1e75ec81ef85e7XXX1', event.id, 2)
        @tc.should_not_receive(:send_sms)
        data = @pm.initialize_data({})
        data[:on_hold] = {
          "CA9fa67e8696b60ee1ca1e75ec81ef85e7XXX1" => 7,
        }
        data[:total] = 2
        data = @pm.merge_calls_for_pool(@pool, @pool_runs_at, data)
        data.should == {
          :total       => 2,
          :next_room   => 1,
          :on_hold     => {
            "CA9fa67e8696b60ee1ca1e75ec81ef85e7XXX1" => 8,
          },
          :placed      => {},
          :apologized  => {},
        }
        data = @pm.merge_calls_for_pool(@pool, @pool_runs_at, data)
        data.should == {
          :total       => 2,
          :next_room   => 1,
          :on_hold     => {
            "CA9fa67e8696b60ee1ca1e75ec81ef85e7XXX1" => 9,
          },
          :placed      => {},
          :apologized  => {
            "CA9fa67e8696b60ee1ca1e75ec81ef85e7XXX1" => 1,
          },
        }
        conference = Conference.where(
          :pool_id    => event.pool_id,
          :started_at => @pool_runs_at,
          :status     => 'only_one_answered'
        )[0]
        conference.ended_at.should > @pool_runs_at
        conference.ended_at.should < Time.now
        conference.users.should == [user]
      end

      it "should put him in the smallest conference room if he's old (bit flaky with timelimit 2458 is ok)" do
        user = Factory(:user)
        phone = Factory(:phone, :user_id => user.id, :primary => true)
        event = Factory(:event, :user_id => user.id, :pool_id => @pool.id)
        new_participants = participant_list(1)
        new_participants[0][:conference_friendly_name] = "15mcHoldEvent#{event.id}User#{user.id}Pool555"
        conference = Conference.create(
          :room_name  => "15mcPool#{@pool.id}Room3",
          :pool_id    => @pool.id,
          :started_at => @pool_runs_at,
          :status     => 'in_progress'
        )
        conference.users = [Factory(:user), Factory(:user)]
        @tc.should_receive(:participants_on_hold_for_pool).twice.with(@pool).and_return(new_participants)
        @tc.should_receive(:place_participant_in_conference).twice.with(
          "CA9fa67e8696b60ee1ca1e75ec81ef85e7XXX1",
          "15mcPool#{@pool.id}Room3",
          @timelimit_insec,
          event.id,
          [32, 33],
        )
        data = {
          :on_hold => {"CA9fa67e8696b60ee1ca1e75ec81ef85e7XXX1" => 1},
          :next_room => 5,
          :apologized  => {},
          :placed      => {
            "CA9fa67e8696b60ee1ca1e75ec81ef85e7XXX11" => {
              :room_name => "15mcPool#{@pool.id}Room1",
              :event_id => 11,
            },
            "CA9fa67e8696b60ee1ca1e75ec81ef85e7XXX12" => {
              :room_name => "15mcPool#{@pool.id}Room1",
              :event_id => 12,
            },
            "CA9fa67e8696b60ee1ca1e75ec81ef85e7XXX13" => {
              :room_name => "15mcPool#{@pool.id}Room1",
              :event_id => 13,
            },
            "CA9fa67e8696b60ee1ca1e75ec81ef85e7XXX21" => {
              :room_name => "15mcPool#{@pool.id}Room2",
              :event_id => 21,
            },
            "CA9fa67e8696b60ee1ca1e75ec81ef85e7XXX22" => {
              :room_name => "15mcPool#{@pool.id}Room2",
              :event_id => 22,
            },
            "CA9fa67e8696b60ee1ca1e75ec81ef85e7XXX23" => {
              :room_name => "15mcPool#{@pool.id}Room2",
              :event_id => 23,
            },
            "CA9fa67e8696b60ee1ca1e75ec81ef85e7XXX32" => {
              :room_name => "15mcPool#{@pool.id}Room3",
              :event_id => 32,
            },
            "CA9fa67e8696b60ee1ca1e75ec81ef85e7XXX33" => {
              :room_name => "15mcPool#{@pool.id}Room3",
              :event_id => 33,
            },
            "CA9fa67e8696b60ee1ca1e75ec81ef85e7XXX41" => {
              :room_name => "15mcPool#{@pool.id}Room4",
              :event_id => 41,
            },
            "CA9fa67e8696b60ee1ca1e75ec81ef85e7XXX42" => {
              :room_name => "15mcPool#{@pool.id}Room4",
              :event_id => 42,
            },
            "CA9fa67e8696b60ee1ca1e75ec81ef85e7XXX43" => {
              :room_name => "15mcPool#{@pool.id}Room4",
              :event_id => 43,
            },
          },
        }
        data2 = Marshal.load(Marshal.dump(data))
        expected = Marshal.load(Marshal.dump(data))
        got = @pm.merge_calls_for_pool(@pool, @pool_runs_at, data)
        expected[:placed]["CA9fa67e8696b60ee1ca1e75ec81ef85e7XXX1"] = {
          :room_name => "15mcPool#{@pool.id}Room3",
          :event_id => event.id,          
        }
        expected[:on_hold] = {}
        got.should == expected
        conference.reload
        conference.users.should include(user)
        conference.users.count.should == 3
        user.reload
        user.placed_count.should == 1

        # Don't add them to the conference object twice
        @pm.merge_calls_for_pool(@pool, @pool_runs_at, data2)
        conference.reload
        conference.users.should include(user)
        conference.users.count.should == 3
        user.reload
        user.placed_count.should == 2
      end
    end
    
    describe "two participants" do

      it "should carry over if we haven't seen either one of them" do
        new_participants = participant_list(2)
        @tc.should_receive(:participants_on_hold_for_pool).with(@pool).and_return(new_participants)
        @pm.merge_calls_for_pool(@pool, @pool_runs_at, {}).should == {
          :next_room   => 1,
          :on_hold     => {
            "CA9fa67e8696b60ee1ca1e75ec81ef85e7XXX1" => 1,
            "CA9fa67e8696b60ee1ca1e75ec81ef85e7XXX2" => 1,
          },
          :placed      => {},
          :apologized  => {},
        }
      end

      it "should join them together if we've seen one of them before" do
        user1  = Factory(:user)
        event1 = Factory(:event, :user_id => user1.id, :pool_id => @pool.id)
        user2  = Factory(:user)
        event2 = Factory(:event, :user_id => user2.id, :pool_id => @pool.id)
        new_participants = participant_list(2)
        new_participants[0][:conference_friendly_name] = "15mcHoldEvent#{event1.id}User#{user1.id}Pool555"
        new_participants[1][:conference_friendly_name] = "15mcHoldEvent#{event2.id}User#{user1.id}Pool555"
        @tc.should_receive(:participants_on_hold_for_pool).with(@pool).and_return(new_participants)
        data = @pm.initialize_data({})
        data[:on_hold] = {
          "CA9fa67e8696b60ee1ca1e75ec81ef85e7XXX1" => 1,          
        }
        @tc.should_receive(:place_participant_in_conference).with("CA9fa67e8696b60ee1ca1e75ec81ef85e7XXX1", "15mcPool#{@pool.id}Room1", @timelimit_insec, 
          event1.id, [event1.id, event2.id])
        @tc.should_receive(:place_participant_in_conference).with("CA9fa67e8696b60ee1ca1e75ec81ef85e7XXX2", "15mcPool#{@pool.id}Room1", @timelimit_insec, 
          event2.id, [event1.id, event2.id])
        @pm.merge_calls_for_pool(@pool, @pool_runs_at, data).should == {
          :next_room   => 2,
          :on_hold     => {},
          :apologized  => {},
          :placed      => {
            "CA9fa67e8696b60ee1ca1e75ec81ef85e7XXX1" => {
              :room_name => "15mcPool#{@pool.id}Room1",
              :event_id => event1.id,
            },
            "CA9fa67e8696b60ee1ca1e75ec81ef85e7XXX2" => {
              :room_name => "15mcPool#{@pool.id}Room1",
              :event_id => event2.id,
            }
          },
        }
        conference = Conference.where(
          :room_name  => "15mcPool#{@pool.id}Room1",
          :pool_id    => @pool.id,
          :started_at => @pool_runs_at,
          :status     => 'in_progress'
        )[0]
        conference.users.should include(user1, user2)
      end

      it "should join them together if we've seen both of them before" do
        new_participants = participant_list(2)
        @tc.should_receive(:participants_on_hold_for_pool).with(@pool).and_return(new_participants)
        data = @pm.initialize_data({})
        data[:on_hold] = {
          "CA9fa67e8696b60ee1ca1e75ec81ef85e7XXX1" => 1,          
          "CA9fa67e8696b60ee1ca1e75ec81ef85e7XXX2" => 1,          
        }
        @tc.should_receive(:place_participant_in_conference).with("CA9fa67e8696b60ee1ca1e75ec81ef85e7XXX1", "15mcPool#{@pool.id}Room1", @timelimit_insec,
         1, [1, 2])
        @tc.should_receive(:place_participant_in_conference).with("CA9fa67e8696b60ee1ca1e75ec81ef85e7XXX2", "15mcPool#{@pool.id}Room1", @timelimit_insec, 
         2, [1, 2])
        @pm.merge_calls_for_pool(@pool, @pool_runs_at, data).should == {
          :next_room   => 2,
          :on_hold     => {},
          :apologized  => {},
          :placed      => {
            "CA9fa67e8696b60ee1ca1e75ec81ef85e7XXX1" => {
              :room_name => "15mcPool#{@pool.id}Room1",
              :event_id => 1,
            },
            "CA9fa67e8696b60ee1ca1e75ec81ef85e7XXX2" => {
              :room_name => "15mcPool#{@pool.id}Room1",
              :event_id => 2,
            },
          },
        }
      end
    end

    describe "three participants" do
      it "should form a new conference" do
        new_participants = participant_list(3)
        @tc.should_receive(:participants_on_hold_for_pool).with(@pool).and_return(new_participants)
        @tc.should_receive(:place_participant_in_conference).with("CA9fa67e8696b60ee1ca1e75ec81ef85e7XXX1", "15mcPool#{@pool.id}Room1", @timelimit_insec, 
          1, [1, 2, 3])
        @tc.should_receive(:place_participant_in_conference).with("CA9fa67e8696b60ee1ca1e75ec81ef85e7XXX2", "15mcPool#{@pool.id}Room1", @timelimit_insec, 
          2, [1, 2, 3])
        @tc.should_receive(:place_participant_in_conference).with("CA9fa67e8696b60ee1ca1e75ec81ef85e7XXX3", "15mcPool#{@pool.id}Room1", @timelimit_insec, 
          3, [1, 2, 3])
        @pm.merge_calls_for_pool(@pool, @pool_runs_at, {}).should == {
          :next_room   => 2,
          :on_hold     => {},
          :apologized  => {},
          :placed      => {
            "CA9fa67e8696b60ee1ca1e75ec81ef85e7XXX1" => {
              :room_name => "15mcPool#{@pool.id}Room1",
              :event_id => 1,
            },
            "CA9fa67e8696b60ee1ca1e75ec81ef85e7XXX2" => {
              :room_name => "15mcPool#{@pool.id}Room1",
              :event_id => 2,
            },            
            "CA9fa67e8696b60ee1ca1e75ec81ef85e7XXX3" => {
              :room_name => "15mcPool#{@pool.id}Room1",
              :event_id => 3,
            },
          },
        }
      end

      it "with six we should get two new conferences ordered by user_id" do
        events = create_events(6)
        new_participants = participant_list_for_events(events).reverse # reverse tests the sorting by user_id
        @tc.should_receive(:participants_on_hold_for_pool).with(@pool).and_return(new_participants)
        @tc.should_receive(:place_participant_in_conference).with("CA9fa67e8696b60ee1ca1e75ec81ef85e7XXX1", "15mcPool#{@pool.id}Room1", 
          be_within(3).of(@timelimit_insec),
          events[0].id, [events[0].id, events[1].id, events[2].id])
        @tc.should_receive(:place_participant_in_conference).with("CA9fa67e8696b60ee1ca1e75ec81ef85e7XXX2", "15mcPool#{@pool.id}Room1",
          be_within(3).of(@timelimit_insec),
          events[1].id, [events[0].id, events[1].id, events[2].id])
        @tc.should_receive(:place_participant_in_conference).with("CA9fa67e8696b60ee1ca1e75ec81ef85e7XXX3", "15mcPool#{@pool.id}Room1",
          be_within(3).of(@timelimit_insec),
          events[2].id, [events[0].id, events[1].id, events[2].id])
        @tc.should_receive(:place_participant_in_conference).with("CA9fa67e8696b60ee1ca1e75ec81ef85e7XXX4", "15mcPool#{@pool.id}Room2",
          be_within(3).of(@timelimit_insec),
          events[3].id, [events[3].id, events[4].id, events[5].id])
        @tc.should_receive(:place_participant_in_conference).with("CA9fa67e8696b60ee1ca1e75ec81ef85e7XXX5", "15mcPool#{@pool.id}Room2",
          be_within(3).of(@timelimit_insec),
          events[4].id, [events[3].id, events[4].id, events[5].id])
        @tc.should_receive(:place_participant_in_conference).with("CA9fa67e8696b60ee1ca1e75ec81ef85e7XXX6", "15mcPool#{@pool.id}Room2",
          be_within(3).of(@timelimit_insec),
          events[5].id, [events[3].id, events[4].id, events[5].id])
        @pm.merge_calls_for_pool(@pool, @pool_runs_at, {}).should == {
          :next_room   => 3,
          :on_hold     => {},
          :apologized  => {},
          :placed      => {
            "CA9fa67e8696b60ee1ca1e75ec81ef85e7XXX1" => {
              :room_name => "15mcPool#{@pool.id}Room1",
              :event_id => events[0].id,
            },
            "CA9fa67e8696b60ee1ca1e75ec81ef85e7XXX2" => {
              :room_name => "15mcPool#{@pool.id}Room1",
              :event_id => events[1].id,
            },            
            "CA9fa67e8696b60ee1ca1e75ec81ef85e7XXX3" => {
              :room_name => "15mcPool#{@pool.id}Room1",
              :event_id => events[2].id,
            },
            "CA9fa67e8696b60ee1ca1e75ec81ef85e7XXX4" => {
              :room_name => "15mcPool#{@pool.id}Room2",
              :event_id => events[3].id,
            },
            "CA9fa67e8696b60ee1ca1e75ec81ef85e7XXX5" => {
              :room_name => "15mcPool#{@pool.id}Room2",
              :event_id => events[4].id,
            },            
            "CA9fa67e8696b60ee1ca1e75ec81ef85e7XXX6" => {
              :room_name => "15mcPool#{@pool.id}Room2",
              :event_id => events[5].id,
            },
          },
        }
      end
      
      it "should skip participants that have already been placed" do
        new_participants = participant_list(3)
        @tc.should_receive(:participants_on_hold_for_pool).with(@pool).and_return(new_participants)
        data = @pm.initialize_data({})
        data[:on_hold] = {
          "CA9fa67e8696b60ee1ca1e75ec81ef85e7XXX1" => 1,          
        }
        data[:placed] = {
          "CA9fa67e8696b60ee1ca1e75ec81ef85e7XXX3" => {
            :room_name => "15mcPool34Event123",          
            :event_id => 3,
          },
        }
        @tc.should_receive(:place_participant_in_conference).with("CA9fa67e8696b60ee1ca1e75ec81ef85e7XXX1", "15mcPool#{@pool.id}Room1", @timelimit_insec,
          1, [1, 2])
        @tc.should_receive(:place_participant_in_conference).with("CA9fa67e8696b60ee1ca1e75ec81ef85e7XXX2", "15mcPool#{@pool.id}Room1", @timelimit_insec,
          2, [1, 2])
        @pm.merge_calls_for_pool(@pool, @pool_runs_at, data).should == {
          :next_room   => 2,
          :on_hold     => {
            "CA9fa67e8696b60ee1ca1e75ec81ef85e7XXX3" => 1,
          },
          :apologized  => {},
          :placed      => {
            "CA9fa67e8696b60ee1ca1e75ec81ef85e7XXX3" => {
              :room_name => "15mcPool34Event123",
              :event_id => 3,
            },
            "CA9fa67e8696b60ee1ca1e75ec81ef85e7XXX1" => {
              :room_name => "15mcPool#{@pool.id}Room1",
              :event_id => 1,
            },
            "CA9fa67e8696b60ee1ca1e75ec81ef85e7XXX2" => {
              :room_name => "15mcPool#{@pool.id}Room1",
              :event_id => 2,
            },
          },
        }
      end

      it "should skip participants that have already been placed and are Incoming when they're on hold for 1" do
        new_participants = participant_list(3)
        new_participants[2][:conference_friendly_name] = "15mcHoldEvent3User3Pool#{@pool.id}Incoming"
        @tc.should_receive(:participants_on_hold_for_pool).with(@pool).and_return(new_participants)
        data = @pm.initialize_data({})
        data[:on_hold] = {
          "CA9fa67e8696b60ee1ca1e75ec81ef85e7XXX1" => 1,          
          "CA9fa67e8696b60ee1ca1e75ec81ef85e7XXX3" => 1,
        }
        data[:placed] = {
          "CA9fa67e8696b60ee1ca1e75ec81ef85e7XXX3" => {
            :room_name => "15mcPool34Room1",          
            :event_id => 3,
          },
        }
        @tc.should_receive(:place_participant_in_conference).with("CA9fa67e8696b60ee1ca1e75ec81ef85e7XXX1", "15mcPool#{@pool.id}Room1", @timelimit_insec,
          1, [1, 2])
        @tc.should_receive(:place_participant_in_conference).with("CA9fa67e8696b60ee1ca1e75ec81ef85e7XXX2", "15mcPool#{@pool.id}Room1", @timelimit_insec,
          2, [1, 2])
        @pm.merge_calls_for_pool(@pool, @pool_runs_at, data).should == {
          :next_room   => 2,
          :on_hold     => {
            "CA9fa67e8696b60ee1ca1e75ec81ef85e7XXX3" => 2,
          },
          :apologized  => {},
          :placed      => {
            "CA9fa67e8696b60ee1ca1e75ec81ef85e7XXX3" => {
              :room_name => "15mcPool34Room1",
              :event_id => 3,
            },
            "CA9fa67e8696b60ee1ca1e75ec81ef85e7XXX1" => {
              :room_name => "15mcPool#{@pool.id}Room1",
              :event_id => 1,
            },
            "CA9fa67e8696b60ee1ca1e75ec81ef85e7XXX2" => {
              :room_name => "15mcPool#{@pool.id}Room1",
              :event_id => 2,
            },
          },
        }
      end

      it "should place participants that have already been placed and are Incoming when they're on hold for 2" do
        new_participants = participant_list(3)
        new_participants[2][:conference_friendly_name] = "15mcHoldEvent3User3Pool#{@pool.id}Incoming"
        @tc.should_receive(:participants_on_hold_for_pool).with(@pool).and_return(new_participants)
        data = @pm.initialize_data({})
        data[:next_room] = 2
        data[:on_hold] = {
          "CA9fa67e8696b60ee1ca1e75ec81ef85e7XXX1" => 1,          
          "CA9fa67e8696b60ee1ca1e75ec81ef85e7XXX3" => 2,
        }
        data[:placed] = {
          "CA9fa67e8696b60ee1ca1e75ec81ef85e7XXX3" => {
            :room_name => "15mcPool#{@pool.id}Room1",
            :event_id => 3,
          },
          "CA9fa67e8696b60ee1ca1e75ec81ef85e7XXX4" => {
            :room_name => "15mcPool#{@pool.id}Room1",
            :event_id => 4,
          },
          "CAThisGuyCalledBackFromADifferentPhoneXXX4" => {
            :room_name => "15mcPool#{@pool.id}Room1",
            :event_id => 4,
          },
          "CA9fa67e8696b60ee1ca1e75ec81ef85e7XXX5" => {
            :room_name => "15mcPool#{@pool.id}Room1",
            :event_id => 5,
          },
        }
        @tc.should_receive(:place_participant_in_conference).with("CA9fa67e8696b60ee1ca1e75ec81ef85e7XXX1", "15mcPool#{@pool.id}Room2", @timelimit_insec,
          1, [1, 2])
        @tc.should_receive(:place_participant_in_conference).with("CA9fa67e8696b60ee1ca1e75ec81ef85e7XXX2", "15mcPool#{@pool.id}Room2", @timelimit_insec,
          2, [1, 2])
        @tc.should_receive(:place_participant_in_conference).with("CA9fa67e8696b60ee1ca1e75ec81ef85e7XXX3", "15mcPool#{@pool.id}Room1", @timelimit_insec,
          3, [3, 4, 5])
        @pm.merge_calls_for_pool(@pool, @pool_runs_at, data).should == {
          :next_room   => 3,
          :on_hold     => {},
          :apologized  => {},
          :placed      => {
            "CA9fa67e8696b60ee1ca1e75ec81ef85e7XXX1" => {
              :room_name => "15mcPool#{@pool.id}Room2",
              :event_id => 1,
            },
            "CA9fa67e8696b60ee1ca1e75ec81ef85e7XXX2" => {
              :room_name => "15mcPool#{@pool.id}Room2",
              :event_id => 2,
            },
            "CA9fa67e8696b60ee1ca1e75ec81ef85e7XXX3" => {
              :room_name => "15mcPool#{@pool.id}Room1",
              :event_id => 3,
            },
            "CA9fa67e8696b60ee1ca1e75ec81ef85e7XXX4" => {
              :room_name => "15mcPool#{@pool.id}Room1",
              :event_id => 4,
            },
            "CAThisGuyCalledBackFromADifferentPhoneXXX4" => {
              :room_name => "15mcPool#{@pool.id}Room1",
              :event_id => 4,
            },
            "CA9fa67e8696b60ee1ca1e75ec81ef85e7XXX5" => {
              :room_name => "15mcPool#{@pool.id}Room1",
              :event_id => 5,
            },
          },
        }
      end

      it "should not duplicate the event_ids when merging in a callback" do
        new_participants = participant_list(1)
        new_participants[0][:conference_friendly_name] = "15mcHoldEvent1User1Pool#{@pool.id}Incoming"
        @tc.should_receive(:participants_on_hold_for_pool).with(@pool).and_return(new_participants)
        @tc.should_receive(:place_participant_in_conference).with("CA9fa67e8696b60ee1ca1e75ec81ef85e7XXX1", "15mcPool#{@pool.id}Room1", @timelimit_insec,
          1, [1, 2, 3])
        data = @pm.initialize_data({})
        data[:on_hold] = {
          "CA9fa67e8696b60ee1ca1e75ec81ef85e7XXX1" => 2,
        }
        data[:placed] = {
          "CA9fa67e8696b60ee1ca1e75ec81ef85e7XXX1" => {
            :room_name => "15mcPool#{@pool.id}Room1",
            :event_id => 1,
          },
          "CA9fa67e8696b60ee1ca1e75ec81ef85e7XXX2" => {
            :room_name => "15mcPool#{@pool.id}Room1",
            :event_id => 2,
          },
          "CA9fa67e8696b60ee1ca1e75ec81ef85e7XXX3" => {
            :room_name => "15mcPool#{@pool.id}Room1",
            :event_id => 3,
          },
        }
        @pm.merge_calls_for_pool(@pool, @pool_runs_at, data)
      end

      it "should merge callbacks into the same room they were in before" do
        new_participants = participant_list(1)
        new_participants[0][:conference_friendly_name] = "15mcHoldEvent1User1Pool#{@pool.id}Incoming"
        @tc.should_receive(:participants_on_hold_for_pool).with(@pool).and_return(new_participants)
        @tc.should_receive(:place_participant_in_conference).with("CA9fa67e8696b60ee1ca1e75ec81ef85e7XXX1", "15mcPool#{@pool.id}Room1", @pool.timelimit * 60, 
          1, [1, 2, 3])
        data = @pm.initialize_data({})
        data[:on_hold] = {
          "CA9fa67e8696b60ee1ca1e75ec81ef85e7XXX1" => 2,
        }
        data[:placed] = {
          "CA9fa67e8696b60ee1ca1e75ec81ef85e7XXX1" => {
            :room_name => "15mcPool#{@pool.id}Room1",
            :event_id => 1,
          },
          "CA9fa67e8696b60ee1ca1e75ec81ef85e7XXX2" => {
            :room_name => "15mcPool#{@pool.id}Room1",
            :event_id => 2,
          },
          "CA9fa67e8696b60ee1ca1e75ec81ef85e7XXX3" => {
            :room_name => "15mcPool#{@pool.id}Room1",
            :event_id => 3,
          },
          "CA9fa67e8696b60ee1ca1e75ec81ef85e7XXX4" => {
            :room_name => "15mcPool#{@pool.id}Room2",
            :event_id => 4,
          },
          "CA9fa67e8696b60ee1ca1e75ec81ef85e7XXX5" => {
            :room_name => "15mcPool#{@pool.id}Room2",
            :event_id => 5,
          },
        }
        Call.create(
          :Sid => 'CA9fa67e8696b60ee1ca1e75ec81ef85e7XXX1',
          :event_id => 1,
          :Duration => 66,
        )
        Call.create(
          :Sid => 'CA9fa67e8696b60ee1ca1e75ec81ef85e7XXX2',
          :event_id => 2,
          :Duration => nil,
        )
        Call.create(
          :Sid => 'CA9fa67e8696b60ee1ca1e75ec81ef85e7XXX3',
          :event_id => 3,
          :Duration => nil,
        )
        @pm.merge_calls_for_pool(@pool, @pool_runs_at - 3.hours, data)
      end

      it "should merge callbacks into a new room if it's old room is empty" do
        new_participants = participant_list(1)
        new_participants[0][:conference_friendly_name] = "15mcHoldEvent1User1Pool#{@pool.id}Incoming"
        @tc.should_receive(:participants_on_hold_for_pool).with(@pool).and_return(new_participants)
        @tc.should_receive(:place_participant_in_conference).with("CA9fa67e8696b60ee1ca1e75ec81ef85e7XXX1", "15mcPool#{@pool.id}Room2", @pool.timelimit * 60, 
          1, [4, 5])
        data = @pm.initialize_data({})
        data[:on_hold] = {
          "CA9fa67e8696b60ee1ca1e75ec81ef85e7XXX1" => 2,
        }
        data[:placed] = {
          "CA9fa67e8696b60ee1ca1e75ec81ef85e7XXX1" => {
            :room_name => "15mcPool#{@pool.id}Room1",
            :event_id => 1,
          },
          "CA9fa67e8696b60ee1ca1e75ec81ef85e7XXX2" => {
            :room_name => "15mcPool#{@pool.id}Room1",
            :event_id => 2,
          },
          "CA9fa67e8696b60ee1ca1e75ec81ef85e7XXX3" => {
            :room_name => "15mcPool#{@pool.id}Room1",
            :event_id => 3,
          },
          "CA9fa67e8696b60ee1ca1e75ec81ef85e7XXX4" => {
            :room_name => "15mcPool#{@pool.id}Room2",
            :event_id => 4,
          },
          "CA9fa67e8696b60ee1ca1e75ec81ef85e7XXX5" => {
            :room_name => "15mcPool#{@pool.id}Room2",
            :event_id => 5,
          },
        }
        Call.create(
          :Sid => 'CA9fa67e8696b60ee1ca1e75ec81ef85e7XXX1',
          :event_id => 1,
          :Duration => nil,
        )
        Call.create(
          :Sid => 'CA9fa67e8696b60ee1ca1e75ec81ef85e7XXX2',
          :event_id => 2,
          :Duration => 66,
        )
        Call.create(
          :Sid => 'CA9fa67e8696b60ee1ca1e75ec81ef85e7XXX3',
          :event_id => 3,
          :Duration => 66,
        )
        got = @pm.merge_calls_for_pool(@pool, @pool_runs_at - 3.hours, data)
        got[:on_hold].should == {}
        got[:placed].should == {
          "CA9fa67e8696b60ee1ca1e75ec81ef85e7XXX1" => {
            :room_name => "15mcPool#{@pool.id}Room2",
            :event_id => 1,
          },
          "CA9fa67e8696b60ee1ca1e75ec81ef85e7XXX2" => {
            :room_name => "15mcPool#{@pool.id}Room1",
            :event_id => 2,
          },
          "CA9fa67e8696b60ee1ca1e75ec81ef85e7XXX3" => {
            :room_name => "15mcPool#{@pool.id}Room1",
            :event_id => 3,
          },
          "CA9fa67e8696b60ee1ca1e75ec81ef85e7XXX4" => {
            :room_name => "15mcPool#{@pool.id}Room2",
            :event_id => 4,
          },
          "CA9fa67e8696b60ee1ca1e75ec81ef85e7XXX5" => {
            :room_name => "15mcPool#{@pool.id}Room2",
            :event_id => 5,
          },          
        }
      end
    end

    describe "four participants" do
      it "should form two new conference of two participants each sorted by placed_id" do
        events = create_events(4)
        events[2].user.placed_count = 11
        events[3].user.placed_count = 12
        events[1].user.placed_count = 13
        events[0].user.placed_count = 14
        events.each { |e| e.save; e.user.save }
        new_participants = participant_list(4, events)
        @tc.should_receive(:participants_on_hold_for_pool).twice.with(@pool).and_return(new_participants)
        @tc.should_receive(:place_participant_in_conference).with("CA9fa67e8696b60ee1ca1e75ec81ef85e7XXX1", "15mcPool#{@pool.id}Room1", 
          be_within(3).of(@timelimit_insec), 
          events[0].id, [events[2].id, events[0].id])
        @tc.should_receive(:place_participant_in_conference).with("CA9fa67e8696b60ee1ca1e75ec81ef85e7XXX3", "15mcPool#{@pool.id}Room1",
           be_within(3).of(@timelimit_insec), 
           events[2].id, [events[2].id, events[0].id])
        @tc.should_receive(:place_participant_in_conference).with("CA9fa67e8696b60ee1ca1e75ec81ef85e7XXX2", "15mcPool#{@pool.id}Room2",
          be_within(3).of(@timelimit_insec),
          events[1].id, [events[3].id, events[1].id])
        @tc.should_receive(:place_participant_in_conference).with("CA9fa67e8696b60ee1ca1e75ec81ef85e7XXX4", "15mcPool#{@pool.id}Room2",
          be_within(3).of(@timelimit_insec), 
          events[3].id, [events[3].id, events[1].id])
        @pm.merge_calls_for_pool(@pool, @pool_runs_at, @pm.merge_calls_for_pool(@pool, @pool_runs_at, {})).should == {
          :next_room   => 3,
          :on_hold     => {},
          :apologized  => {},
          :placed      => {
            "CA9fa67e8696b60ee1ca1e75ec81ef85e7XXX1" => {
              :room_name => "15mcPool#{@pool.id}Room1",
              :event_id => events[0].id,
            },
            "CA9fa67e8696b60ee1ca1e75ec81ef85e7XXX3" => {
              :room_name => "15mcPool#{@pool.id}Room1",
              :event_id => events[2].id,
            },            
            "CA9fa67e8696b60ee1ca1e75ec81ef85e7XXX2" => {
              :room_name => "15mcPool#{@pool.id}Room2",
              :event_id => events[1].id,
            },
            "CA9fa67e8696b60ee1ca1e75ec81ef85e7XXX4" => {
              :room_name => "15mcPool#{@pool.id}Room2",
              :event_id => events[3].id,
            },
          },
        }
      end

      it "another way to write the handle_four test..... Needs plumbing test to go along with it" do
        events = create_events(4)
        events[2].user.placed_count = 11
        events[3].user.placed_count = 12
        events[1].user.placed_count = 13
        events[0].user.placed_count = 14
        events.each { |e| e.save; e.user.save }
        new_participants = participant_list(4, events)
        pool = Pool.default_pool
        pool_runs_at = Time.now
        @pm.should_receive(:handle_two_new_participants).with([new_participants[2], new_participants[0]], pool, pool_runs_at, {})
        @pm.should_receive(:handle_two_new_participants).with([new_participants[3], new_participants[1]], pool, pool_runs_at, {})
        @pm.handle_four_new_participants(new_participants, pool, pool_runs_at, {})
        new_participants.should be_empty
      end

      it "groups all four together if there is a newbie" do
        events = create_events(4)
        events[0].user.placed_count = 0
        events[1].user.placed_count = 1
        events[2].user.placed_count = 2
        events[3].user.placed_count = 3
        events.each { |e| e.save; e.user.save }
        new_participants = participant_list(4, events)
        pool = Pool.default_pool
        pool_runs_at = Time.now
        @pm.should_receive(:create_new_group).with([new_participants[0], new_participants[1], new_participants[2], new_participants[3]], 
          pool, pool_runs_at, {})
        @pm.handle_four_new_participants(new_participants, pool, pool_runs_at, {})
        new_participants.should be_empty
      end
    end
    
    describe "Handle those who are on hold first" do
      it "should put someone who's on hold at the front of the list" do
        events = create_events(5)
        new_participants = participant_list_for_events(events)
        @tc.should_receive(:participants_on_hold_for_pool).with(@pool).and_return(new_participants)
        @tc.should_receive(:place_participant_in_conference).with("CA9fa67e8696b60ee1ca1e75ec81ef85e7XXX4", "15mcPool#{@pool.id}Room1",
          be_within(3).of(@timelimit_insec), 
          events[3].id, [events[3].id, events[0].id, events[1].id]).ordered
        @tc.should_receive(:place_participant_in_conference).with("CA9fa67e8696b60ee1ca1e75ec81ef85e7XXX1", "15mcPool#{@pool.id}Room1",
          be_within(3).of(@timelimit_insec), 
          events[0].id, [events[3].id, events[0].id, events[1].id]).ordered
        @tc.should_receive(:place_participant_in_conference).with("CA9fa67e8696b60ee1ca1e75ec81ef85e7XXX2", "15mcPool#{@pool.id}Room1",
          be_within(3).of(@timelimit_insec), 
          events[1].id, [events[3].id, events[0].id, events[1].id]).ordered
        data = @pm.initialize_data({})
        data[:on_hold] = {
          "CA9fa67e8696b60ee1ca1e75ec81ef85e7XXX4" => 2,
          "CA9fa67e8696b60ee1ca1e75ec81ef85e7XXX1" => 1,
        }
        @pm.merge_calls_for_pool(@pool, @pool_runs_at, data).should == {
          :next_room   => 2,
          :on_hold     => { 
            "CA9fa67e8696b60ee1ca1e75ec81ef85e7XXX5" => 1,
            "CA9fa67e8696b60ee1ca1e75ec81ef85e7XXX3" => 1,
          },
          :apologized  => {},
          :placed      => {
            "CA9fa67e8696b60ee1ca1e75ec81ef85e7XXX4" => {
              :room_name => "15mcPool#{@pool.id}Room1",
              :event_id => events[3].id,
            },
            "CA9fa67e8696b60ee1ca1e75ec81ef85e7XXX1" => {
              :room_name => "15mcPool#{@pool.id}Room1",
              :event_id => events[0].id,
            },
            "CA9fa67e8696b60ee1ca1e75ec81ef85e7XXX2" => {
              :room_name => "15mcPool#{@pool.id}Room1",
              :event_id => events[1].id,
            },
          },
        }
      end
    end
  end
  
  describe "pick_three_participants" do
    it "grabs the first three from the list" do
      events = create_events(3)
      participants = participant_list_for_events(events)

      three = @pm.pick_three_participants(participants)

      extract_event_names(three).should == [events[0], events[1], events[2]].map(&:name)
      extract_event_names(participants).should == []
    end

    it "it teams a admin user with the two users with the lowest placed_count" do
      events = create_events(6)
      events[4].name += ': Admin'
      events[4].user.admin = true
      events[0].user.placed_count = 10
      events[1].user.placed_count = 0
      events[1].name += ': Newbie'
      events[2].user.placed_count = 33
      events[3].user.placed_count = 6
      events[4].user.placed_count = 100
      events[5].user.placed_count = 2
      events[5].name += ': FirstWeek'
      events.each { |e| e.save; e.user.save }
      participants = participant_list_for_events(events)

      three = @pm.pick_three_participants(participants)

      extract_event_names(three).should == [events[1], events[4], events[5]].map(&:name)
      extract_event_names(participants).should == [events[0], events[2], events[3]].map(&:name)
    end

    it "it splits new newbies apart" do
      events = create_events(6)
      events[0].user.placed_count = 103
      events[0].name += ': OldSchool'
      events[1].user.placed_count = 102
      events[1].name += ': OldSchool'
      events[2].user.placed_count = 20
      events[2].name += ': Teen'
      events[3].user.placed_count = 12
      events[3].name += ': Trial'
      events[4].user.placed_count = 0
      events[4].name += ': Newbie'
      events[5].user.placed_count = 0
      events[5].name += ': Newbie'
      events.each { |e| e.save; e.user.save }
      participants = participant_list_for_events(events)

      three = @pm.pick_three_participants(participants)

      extract_event_names(three).should == [events[1], events[2], events[4]].map(&:name)
      extract_event_names(participants).should == [events[0], events[3], events[5]].map(&:name)
    end

    it "it pairs newbies with trials if there's no oldschoolers around" do
      events = create_events(6)
      events[0].user.placed_count = 7
      events[0].name += ': Trial'
      events[1].user.placed_count = 6
      events[1].name += ': Trial'
      events[2].user.placed_count = 5
      events[2].name += ': Trial'
      events[3].user.placed_count = 4
      events[3].name += ': Trial'
      events[4].user.placed_count = 0
      events[4].name += ': Newbie'
      events[5].user.placed_count = 0
      events[5].name += ': Newbie'
      events.each { |e| e.save; e.user.save }
      participants = participant_list_for_events(events)

      three = @pm.pick_three_participants(participants)

      extract_event_names(three).should == [events[2], events[3], events[4]].map(&:name)
      extract_event_names(participants).should == [events[0], events[1], events[5]].map(&:name)
    end
  end

  describe "initialize_data" do
    it "should initialize the empty hash" do
      @pm.initialize_data({}).should == {
        :next_room   => 1,
        :on_hold     => {},
        :placed      => {},
        :apologized  => {},
      }
    end

    it "should leave existing values alone" do
      data = {:next_room => 1, :placed => {1 => 2}, :on_hold => {2 => 3}}
      @pm.initialize_data(data).should == data
    end
  end
end

def one_participant_response
  '{"page":0,"num_pages":1,"page_size":50,"total":1,"start":0,"end":0,"uri":"\/2010-04-01\/Accounts\/AC2e57bf710b77d765d280786bc07dbacc\/Conferences\/' +
  'CF0cb07a25bdaf64828850b784ea2d1aa7\/Participants.json","first_page_uri":"\/2010-04-01\/Accounts\/AC2e57bf710b77d765d280786bc07dbacc\/Conferences\/' +
  'CF0cb07a25bdaf64828850b784ea2d1aa7\/Participants.json?Page=0&PageSize=50","previous_page_uri":null,"next_page_uri":null,"last_page_uri":"\/2010-04-01\/' +
  'Accounts\/AC2e57bf710b77d765d280786bc07dbacc\/Conferences\/CF0cb07a25bdaf64828850b784ea2d1aa7\/Participants.json?Page=0&PageSize=50",' +
  '"participants":[{"conference_sid":"CF0cb07a25bdaf64828850b784ea2d1aa7","account_sid":"AC2e57bf710b77d765d280786bc07dbacc",' +
  '"call_sid":"CA9fa67e8696b60ee1ca1e75ec81ef85e7","muted":false,"end_conference_on_exit":false,"start_conference_on_enter":true,' +
  '"date_created":"Wed, 06 Apr 2011 19:10:13 +0000","date_updated":"Wed, 06 Apr 2011 19:10:13 +0000","uri":"\/2010-04-01\/Accounts\/' +
  'AC2e57bf710b77d765d280786bc07dbacc\/Conferences\/CF0cb07a25bdaf64828850b784ea2d1aa7\/Participants\/CA9fa67e8696b60ee1ca1e75ec81ef85e7.json"}]}'
end

def participant_list(participant_count, events = [])
  list = []
  stub_participant = ActiveSupport::JSON.decode(one_participant_response).with_indifferent_access[:participants][0]
  (1..participant_count).each do |i|
    participant = stub_participant.dup
    participant[:call_sid] += "XXX" + i.to_s
    participant[:conference_sid] += "XXX" + i.to_s
    event_id = i
    user_id = i
    if events.any?
      event = events[i-1]
      event_id = event.id
      user_id = event.user_id
    end
    participant[:conference_friendly_name] = "15mcHoldEvent#{event_id}User#{user_id}Pool555"
    list << participant
  end
  list
end

def create_events(count)
  list = []
  i = 0
  count.times do
    user = Factory(:user)
    event = Factory(:event, :name => "Event #{i}", :user_id => user.id)
    list << event
    i += 1
  end
  list
end

def participant_list_for_events(events = [])
  participant_list(events.count, events)
end

def extract_events(participants)
  list = []
  participants.each do |participant|
    participant[:conference_friendly_name] =~ /Event(\d+)/
    list << Event.find($1.to_i)
  end
  list
end

def extract_event_names(participants)
  extract_events(participants).map(&:name)
end