require 'spec_helper'

describe PoolMerger do
  before(:each) do
    @pm = PoolMerger.new
    @pool = Factory(:pool)
    @tc = mock('TropoCaller')
    TropoCaller.stub(:new).and_return(@tc)
    offset_time = 5.minutes
    @pool_runs_at = Time.now - offset_time
    @timelimit_insec = (((@pool.timelimit + 1) * 60) - offset_time) - 1
    @data = @pm.initialize_data({})
  end
  
  it "should have a max_wait_time_to_answer" do
    @pm.max_wait_time_to_answer.should == 60.seconds
  end

  describe "merge_calls_for_pool" do
    it "does nothing with zero new participants" do
      participant_list(0)
      @pm.merge_calls_for_pool(@pool, @pool_runs_at, {}).should == @data.merge({
        :next_room   => 1,
        :on_hold     => {},
        :placed      => {},
        :apologized  => {},
      })
    end

    it "initializes the hash even when passed :total" do
      participant_list(0)
      @pm.merge_calls_for_pool(@pool, @pool_runs_at, {:total => 3}).should == @data.merge({
        :next_room   => 1,
        :total => 3,
        :on_hold     => {},
        :placed      => {},
        :apologized  => {},
      })
    end
    
    describe "zero participants" do
      it "should clear out the on_hold status of anyone who's not currently there" do
        participant_list(0)
        data = @pm.initialize_data({}).merge({
          :on_hold => { "session_id_1" => 1 },
          :waiting_for_events => [77, 33],
        })
        @pm.merge_calls_for_pool(@pool, @pool_runs_at, data).should == @data.merge({
          :waiting_for_events => [77, 33],
          :on_hold     => {},
        })
      end

      it "should clear out the waiting_for_events info of someone who missed the call" do
        participant_list(0)
        call1 = Call.create!( # completed => remove me
          :event_id       => 77,
          :status         => 'outgoing-greeting-nokeypress-callback',
        )
        call2 = Call.create!( # onhold => remove me
          :event_id       => 76,
          :status         => 'outgoing-greeting-onhold',
        )
        call3 = Call.create!( # call is still waiting for answer/hangup
          :event_id       => 66,
          :status         => 'outgoing-greeting',
        )
        call4 = Call.create!( # event from a long time ago
          :event_id       => 44,
          :status         => 'outgoing-greeting-nokeypress-callback',
        )
        call5 = Call.create!( # nokeypress => remove me
          :event_id       => 88,
          :status         => 'outgoing-greeting-nokeypress',
        )
        ActiveRecord::Base.record_timestamps = false
        call4.created_at = Time.now - (@pool.timelimit + 1).minutes
        call4.updated_at = Time.now - (@pool.timelimit + 1).minutes
        call4.save
        ActiveRecord::Base.record_timestamps = true
  
        data = @pm.initialize_data({}).merge({
          :waiting_for_events => [77, 76, 33, 44, 66, 88],
        })
        @pm.merge_calls_for_pool(@pool, @pool_runs_at, data).should == @data.merge({
          :waiting_for_events => [33, 44, 66],
        })
      end
    end
    
    describe "single participant" do      
      it "should carry over if we haven't seen them before" do
        participant_list(1)
        @pm.merge_calls_for_pool(@pool, @pool_runs_at, {
          :total => 1,
          :waiting_for_events => [1],
        }).should == {
          :total       => 1,
          :waiting_for_events => [],
          :next_room   => 1,
          :on_hold     => {
            "session_id_1" => 1,
          },
          :placed      => {},
          :apologized  => {},
        }
      end

      it "should carry over if there is no existing conference room even if he's old" do
        participant_list(1)
        data = @pm.initialize_data({})
        data[:on_hold] = {
          "session_id_1" => 1,          
        }
        @pm.merge_calls_for_pool(@pool, @pool_runs_at, data).should == @data.merge({
          :next_room   => 1,
          :on_hold     => {
            "session_id_1" => 2,
          },
          :placed      => {},
          :apologized  => {},
        })
      end

      it "should tell him sorry and end call if he's been waiting a long time" do
        user = Factory(:user)
        phone = Factory(:phone, :user_id => user.id, :primary => true)
        event = Factory(:event, :user_id => user.id, :pool_id => @pool.id, :send_sms_reminder => true)
        participant = participant_list(1).first
        participant.event_id = event.id
        participant.user_id = user.id
        participant.save
        @tc.should_receive(:apologize_no_other_participants).with(participant.session_id, 2)
        twilio = mock('TwilioCaller')
        TwilioCaller.stub(:new).and_return(twilio)
        data = @pm.initialize_data({})
        data[:on_hold] = {
          "session_id_1" => 1,
        }
        data[:total] = 2
        data = @pm.merge_calls_for_pool(@pool, @pool_runs_at, data)
        data.should == @data.merge({
          :total       => 2,
          :next_room   => 1,
          :on_hold     => {
            "session_id_1" => 2,
          },
          :placed      => {},
          :apologized  => {},
        })
        data = @pm.merge_calls_for_pool(@pool, @pool_runs_at, data)
        data.should == @data.merge({
          :total       => 2,
          :next_room   => 1,
          :on_hold     => {
            "session_id_1" => 3,
          },
          :apologized  => {
            "session_id_1" => 1,
          },
          :placed      => {},
        })
        data = @pm.merge_calls_for_pool(@pool, @pool_runs_at, data)
        data.should == @data.merge({
          :total       => 2,
          :next_room   => 1,
          :on_hold     => {
            "session_id_1" => 4,
          },
          :apologized  => {
            "session_id_1" => 1,
          },
          :placed      => {},
        })
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
        participant = participant_list(1).first
        participant.event_id = event.id
        participant.user_id = user.id
        participant.save
        @tc.should_receive(:apologize_no_other_participants).with(participant.session_id, 2)
        data = @pm.initialize_data({})
        data[:on_hold] = {
          "session_id_1" => 1,
        }
        data[:total] = 2
        data = @pm.merge_calls_for_pool(@pool, @pool_runs_at, data)
        data.should == @data.merge({
          :total       => 2,
          :next_room   => 1,
          :on_hold     => {
            "session_id_1" => 2,
          },
          :placed      => {},
          :apologized  => {},
        })
        data = @pm.merge_calls_for_pool(@pool, @pool_runs_at, data)
        data.should == @data.merge({
          :total       => 2,
          :next_room   => 1,
          :on_hold     => {
            "session_id_1" => 3,
          },
          :placed      => {},
          :apologized  => {
            "session_id_1" => 1,
          },
        })
        conference = Conference.where(
          :pool_id    => event.pool_id,
          :started_at => @pool_runs_at,
          :status     => 'only_one_answered'
        )[0]
        conference.ended_at.should > @pool_runs_at
        conference.ended_at.should < Time.now
        conference.users.should == [user]
      end

      it "should put him in the smallest conference room if he's old" do
        user = Factory(:user)
        phone = Factory(:phone, :user_id => user.id, :primary => true)
        event = Factory(:event, :user_id => user.id, :pool_id => @pool.id)
        participant = participant_list_for_events([event]).first
        conference = Conference.create(
          :room_name  => "15mcPool#{@pool.id}Room3",
          :pool_id    => @pool.id,
          :started_at => @pool_runs_at,
          :status     => 'in_progress'
        )
        conference.users = [Factory(:user), Factory(:user)]
        @tc.should_receive(:place_participant_in_conference).twice.with(
          "session_id_1",
          "15mcPool#{@pool.id}Room3",
          be_within(3).of(@timelimit_insec),
          event.id,
          [32, 33],
        )
        data = @data.merge({
          :on_hold => {"session_id_1" => 1},
          :next_room => 5,
          :apologized  => {},
          :placed      => {
            "session_id_11" => {
              :room_name => "15mcPool#{@pool.id}Room1",
              :event_id => 11,
            },
            "session_id_12" => {
              :room_name => "15mcPool#{@pool.id}Room1",
              :event_id => 12,
            },
            "session_id_13" => {
              :room_name => "15mcPool#{@pool.id}Room1",
              :event_id => 13,
            },
            "session_id_21" => {
              :room_name => "15mcPool#{@pool.id}Room2",
              :event_id => 21,
            },
            "session_id_22" => {
              :room_name => "15mcPool#{@pool.id}Room2",
              :event_id => 22,
            },
            "session_id_23" => {
              :room_name => "15mcPool#{@pool.id}Room2",
              :event_id => 23,
            },
            "session_id_32" => {
              :room_name => "15mcPool#{@pool.id}Room3",
              :event_id => 32,
            },
            "session_id_33" => {
              :room_name => "15mcPool#{@pool.id}Room3",
              :event_id => 33,
            },
            "session_id_41" => {
              :room_name => "15mcPool#{@pool.id}Room4",
              :event_id => 41,
            },
            "session_id_42" => {
              :room_name => "15mcPool#{@pool.id}Room4",
              :event_id => 42,
            },
            "session_id_43" => {
              :room_name => "15mcPool#{@pool.id}Room4",
              :event_id => 43,
            },
          },
        })
        data2 = Marshal.load(Marshal.dump(data))
        expected = Marshal.load(Marshal.dump(data))
        got = @pm.merge_calls_for_pool(@pool, @pool_runs_at, data)
        expected[:placed]["session_id_1"] = {
          :room_name => "15mcPool#{@pool.id}Room3",
          :event_id => event.id,          
        }
        expected[:on_hold] = {}
        expected[:placed].each_value{ |v| v.delete(:time)}
        got[:placed].each_value{ |v| v.delete(:time)}
        got.should == expected
        conference.reload
        conference.users.should include(user)
        conference.users.count.should == 3
        user.reload
        user.placed_count.should == 1

        # Don't add them to the conference object twice
        participant.reload
        participant.call_state.should == 'placed'
        participant.call_state = 'onhold'
        participant.save
        @pm.merge_calls_for_pool(@pool, @pool_runs_at, data2)
        conference.reload
        conference.users.should include(user)
        conference.users.count.should == 3
        user.reload
        user.placed_count.should == 2
      end

      it "should form a group of three and a group of two if the smallest conference is four" do
        events = create_events(5)
        new_participants = participant_list(5, events)

        # Three come in and get merged together
        new_participants[2].call_state = 'foo'
        new_participants[4].call_state = 'foo'
        new_participants.each { |p| p.save }
        data = @pm.initialize_data({})
        @tc.should_receive(:place_participant_in_conference).with(
          "session_id_1", "15mcPool#{@pool.id}Room1", 
          be_within(3).of(@timelimit_insec), 
          events[0].id, [events[0].id, events[1].id, events[3].id]
        )
        @tc.should_receive(:place_participant_in_conference).with(
          "session_id_2", "15mcPool#{@pool.id}Room1", 
          be_within(3).of(@timelimit_insec), 
          events[1].id, [events[0].id, events[1].id, events[3].id]
        )
        @tc.should_receive(:place_participant_in_conference).with(
          "session_id_4", "15mcPool#{@pool.id}Room1", 
          be_within(3).of(@timelimit_insec), 
          events[3].id, [events[0].id, events[1].id, events[3].id]
        )
        data = @pm.merge_calls_for_pool(@pool, @pool_runs_at, data)

        # Fourth comes in and gets merged into a group of four
        new_participants[2].call_state = 'onhold'
        new_participants[2].save
        @tc.should_receive(:place_participant_in_conference).with(
          "session_id_3", "15mcPool#{@pool.id}Room1", 
          be_within(3).of(@timelimit_insec), 
          events[2].id, [events[0].id, events[1].id, events[3].id]
        )        
        data = @pm.merge_calls_for_pool(@pool, @pool_runs_at, data)
        data = @pm.merge_calls_for_pool(@pool, @pool_runs_at, data)

        # Fifth comes in and plucks one out to form two groups: one of 2 and one of 3
        new_participants[4].call_state = 'onhold'
        new_participants[4].save
        @tc.should_receive(:place_participant_in_conference).with(
          "session_id_3", "15mcPool#{@pool.id}Room2", 
          be_within(3).of(@timelimit_insec), 
          events[2].id, [events[2].id, events[4].id]
        )
        @tc.should_receive(:place_participant_in_conference).with(
          "session_id_5", "15mcPool#{@pool.id}Room2", 
          be_within(3).of(@timelimit_insec), 
          events[4].id, [events[2].id, events[4].id]
        )
        data = @pm.merge_calls_for_pool(@pool, @pool_runs_at, data)
        data = @pm.merge_calls_for_pool(@pool, @pool_runs_at, data)
  
        # Placed data for final grouping
        data[:placed].each_value{ |v| v.delete(:time)}
        data[:placed].should == {
          "session_id_1" => {
            :room_name => "15mcPool#{@pool.id}Room1", 
            :event_id  => events[0].id,
          }, 
          "session_id_2" => {
            :room_name => "15mcPool#{@pool.id}Room1", 
            :event_id  => events[1].id,
          }, 
          "session_id_3" => {
            :room_name => "15mcPool#{@pool.id}Room2", 
            :event_id  => events[2].id,
          }, 
          "session_id_4" => {
            :room_name => "15mcPool#{@pool.id}Room1", 
            :event_id  => events[3].id,
          }, 
          "session_id_5" => {
            :room_name => "15mcPool#{@pool.id}Room2", 
            :event_id  => events[4].id,
          }
        }
      end


      it "should keep everyone in the same group if merge_type == 3" do
        @pool.merge_type = 3
        @pool.save
        events = create_events(5)
        new_participants = participant_list(5, events)

        # Three come in and get merged together
        new_participants[2].call_state = 'foo'
        new_participants[4].call_state = 'foo'
        new_participants.each { |p| p.save }
        data = @pm.initialize_data({})
        @tc.should_receive(:place_participant_in_conference).with(
          "session_id_1", "15mcPool#{@pool.id}Room1", 
          be_within(3).of(@timelimit_insec), 
          events[0].id, [events[0].id, events[1].id, events[3].id]
        )
        @tc.should_receive(:place_participant_in_conference).with(
          "session_id_2", "15mcPool#{@pool.id}Room1", 
          be_within(3).of(@timelimit_insec), 
          events[1].id, [events[0].id, events[1].id, events[3].id]
        )
        @tc.should_receive(:place_participant_in_conference).with(
          "session_id_4", "15mcPool#{@pool.id}Room1", 
          be_within(3).of(@timelimit_insec), 
          events[3].id, [events[0].id, events[1].id, events[3].id]
        )
        data = @pm.merge_calls_for_pool(@pool, @pool_runs_at, data)

        # Fourth comes in and gets merged into a group of four
        new_participants[2].call_state = 'onhold'
        new_participants[2].save
        @tc.should_receive(:place_participant_in_conference).with(
          "session_id_3", "15mcPool#{@pool.id}Room1", 
          be_within(3).of(@timelimit_insec), 
          events[2].id, [events[0].id, events[1].id, events[3].id]
        )        
        data = @pm.merge_calls_for_pool(@pool, @pool_runs_at, data)
        data = @pm.merge_calls_for_pool(@pool, @pool_runs_at, data)

        # Fifth comes in and gets merged into a group of five
        new_participants[4].call_state = 'onhold'
        new_participants[4].save
        @tc.should_receive(:place_participant_in_conference).with(
          "session_id_5", "15mcPool#{@pool.id}Room1", 
          be_within(3).of(@timelimit_insec), 
          events[4].id, [events[0].id, events[1].id, events[3].id, events[2].id]
        )
        data = @pm.merge_calls_for_pool(@pool, @pool_runs_at, data)
        data = @pm.merge_calls_for_pool(@pool, @pool_runs_at, data)
  
        # Placed data for final grouping
        data[:placed].each_value{ |v| v.delete(:time)}
        data[:placed].should == {
          "session_id_1" => {
            :room_name => "15mcPool#{@pool.id}Room1", 
            :event_id  => events[0].id,
          }, 
          "session_id_2" => {
            :room_name => "15mcPool#{@pool.id}Room1", 
            :event_id  => events[1].id,
          }, 
          "session_id_3" => {
            :room_name => "15mcPool#{@pool.id}Room1", 
            :event_id  => events[2].id,
          }, 
          "session_id_4" => {
            :room_name => "15mcPool#{@pool.id}Room1", 
            :event_id  => events[3].id,
          }, 
          "session_id_5" => {
            :room_name => "15mcPool#{@pool.id}Room1", 
            :event_id  => events[4].id,
          }
        }
      end
    end
    
    describe "two participants" do

      it "should carry over if we are still waiting on another participant" do
        participant_list(2)
        pool_runs_at = Time.now
        data = @pm.initialize_data({}).merge({
          :waiting_for_events => [333],
        })
        data = @pm.merge_calls_for_pool(@pool, pool_runs_at, data)
        data.should == @data.merge({
          :on_hold     => {
            "session_id_1" => 1,
            "session_id_2" => 1,
          },
          :waiting_for_events => [333],
        })
        @pm.merge_calls_for_pool(@pool, pool_runs_at, data).should == @data.merge({
          :on_hold     => {
            "session_id_1" => 2,
            "session_id_2" => 2,
          },
          :waiting_for_events => [333],
        })
      end

      it "should merge them after a long time even if we are still waiting on another participant" do
        participant_list(2)
        pool_runs_at = Time.now
        data = @pm.initialize_data({}).merge({
          :on_hold     => {
            "session_id_1" => 1,
            "session_id_2" => 1,
          },
          :waiting_for_events => [333],
        })
        offset = 60.seconds
        timelimit_insec = (((@pool.timelimit + 1) * 60) - offset) - 1
        @tc.should_receive(:place_participant_in_conference).with("session_id_1", "15mcPool#{@pool.id}Room1",
         be_within(3).of(timelimit_insec),
         1, [1, 2])
        @tc.should_receive(:place_participant_in_conference).with("session_id_2", "15mcPool#{@pool.id}Room1",
         be_within(3).of(timelimit_insec), 
         2, [1, 2])
        got = @pm.merge_calls_for_pool(@pool, pool_runs_at - offset, data)
        got[:placed].each_value{ |v| v.delete(:time)}
        got.should == @data.merge({
          :on_hold     => {},
          :next_room   => 2,
          :placed      => {
            "session_id_1" => {
              :room_name => "15mcPool#{@pool.id}Room1",
              :event_id => 1,
            },
            "session_id_2" => {
              :room_name => "15mcPool#{@pool.id}Room1",
              :event_id => 2,
            }
          },
          :waiting_for_events => [333],
        })
      end

      it "should join them together if we've seen one of them before" do
        user1  = Factory(:user)
        event1 = Factory(:event, :user_id => user1.id, :pool_id => @pool.id)
        user2  = Factory(:user)
        event2 = Factory(:event, :user_id => user2.id, :pool_id => @pool.id)
        participant_list(2, [event1, event2])
        data = @pm.initialize_data({})
        data[:on_hold] = {
          "session_id_1" => 1,          
        }
        @tc.should_receive(:place_participant_in_conference).with("session_id_1", "15mcPool#{@pool.id}Room1", @timelimit_insec, 
          event1.id, [event1.id, event2.id])
        @tc.should_receive(:place_participant_in_conference).with("session_id_2", "15mcPool#{@pool.id}Room1", @timelimit_insec, 
          event2.id, [event1.id, event2.id])
        got = @pm.merge_calls_for_pool(@pool, @pool_runs_at, data)
        got[:placed].each_value{ |v| v.delete(:time)}
        got.should == @data.merge({
          :next_room   => 2,
          :on_hold     => {},
          :apologized  => {},
          :placed      => {
            "session_id_1" => {
              :room_name => "15mcPool#{@pool.id}Room1",
              :event_id => event1.id,
            },
            "session_id_2" => {
              :room_name => "15mcPool#{@pool.id}Room1",
              :event_id => event2.id,
            }
          },
        })
        conference = Conference.where(
          :room_name  => "15mcPool#{@pool.id}Room1",
          :pool_id    => @pool.id,
          :started_at => @pool_runs_at,
          :status     => 'in_progress'
        )[0]
        conference.users.should include(user1, user2)
      end

      it "should join them together if waiting_for_events is empty even if neither is on hold" do
        user1  = Factory(:user)
        event1 = Factory(:event, :user_id => user1.id, :pool_id => @pool.id)
        user2  = Factory(:user)
        event2 = Factory(:event, :user_id => user2.id, :pool_id => @pool.id)
        participant_list(2, [event1, event2])
        data = @pm.initialize_data({})
        @tc.should_receive(:place_participant_in_conference).with("session_id_1", "15mcPool#{@pool.id}Room1", @timelimit_insec, 
          event1.id, [event1.id, event2.id])
        @tc.should_receive(:place_participant_in_conference).with("session_id_2", "15mcPool#{@pool.id}Room1", @timelimit_insec, 
          event2.id, [event1.id, event2.id])
        got = @pm.merge_calls_for_pool(@pool, @pool_runs_at, data)
        got[:placed].each_value{ |v| v.delete(:time)}
        got.should == @data.merge({
          :next_room   => 2,
          :on_hold     => {},
          :apologized  => {},
          :placed      => {
            "session_id_1" => {
              :room_name => "15mcPool#{@pool.id}Room1",
              :event_id => event1.id,
            },
            "session_id_2" => {
              :room_name => "15mcPool#{@pool.id}Room1",
              :event_id => event2.id,
            }
          },
        })
        conference = Conference.where(
          :room_name  => "15mcPool#{@pool.id}Room1",
          :pool_id    => @pool.id,
          :started_at => @pool_runs_at,
          :status     => 'in_progress'
        )[0]
        conference.users.should include(user1, user2)
      end
      
      it "should join them together if we've seen both of them before" do
        participant_list(2)
        data = @pm.initialize_data({})
        data[:on_hold] = {
          "session_id_1" => 1,          
          "session_id_2" => 1,          
        }
        @tc.should_receive(:place_participant_in_conference).with("session_id_1", "15mcPool#{@pool.id}Room1",
          be_within(3).of(@timelimit_insec),
          1, [1, 2])
        @tc.should_receive(:place_participant_in_conference).with("session_id_2", "15mcPool#{@pool.id}Room1",
          be_within(3).of(@timelimit_insec),
          2, [1, 2])
        got = @pm.merge_calls_for_pool(@pool, @pool_runs_at, data)
        got[:placed].each_value{ |v| v.delete(:time)}
        got.should == @data.merge({
          :next_room   => 2,
          :on_hold     => {},
          :apologized  => {},
          :placed      => {
            "session_id_1" => {
              :room_name => "15mcPool#{@pool.id}Room1",
              :event_id => 1,
            },
            "session_id_2" => {
              :room_name => "15mcPool#{@pool.id}Room1",
              :event_id => 2,
            },
          },
        })
      end
    end

    describe "three participants" do
      it "should form a new conference" do
        events = create_events(3)
        participant_list_for_events(events)
        event_ids = events.map(&:id)
        @tc.should_receive(:place_participant_in_conference).with("session_id_1", "15mcPool#{@pool.id}Room1",
          be_within(3).of(@timelimit_insec),
          events[0].id, event_ids)
        @tc.should_receive(:place_participant_in_conference).with("session_id_2", "15mcPool#{@pool.id}Room1",
          be_within(3).of(@timelimit_insec),
          events[1].id, event_ids)
        @tc.should_receive(:place_participant_in_conference).with("session_id_3", "15mcPool#{@pool.id}Room1",
          be_within(3).of(@timelimit_insec),
          events[2].id, event_ids)
        got = @pm.merge_calls_for_pool(@pool, @pool_runs_at, {})
        got[:placed].each_value{ |v| v.delete(:time)}
        got.should == @data.merge({
          :next_room   => 2,
          :on_hold     => {},
          :apologized  => {},
          :placed      => {
            "session_id_1" => {
              :room_name => "15mcPool#{@pool.id}Room1",
              :event_id => events[0].id,
            },
            "session_id_2" => {
              :room_name => "15mcPool#{@pool.id}Room1",
              :event_id => events[1].id,
            },            
            "session_id_3" => {
              :room_name => "15mcPool#{@pool.id}Room1",
              :event_id => events[2].id,
            },
          },
        })
      end

      it "with six we should get two new conferences ordered by user_id" do
        events = create_events(6)
        participant_list_for_events(events)
        @tc.should_receive(:place_participant_in_conference).with("session_id_1", "15mcPool#{@pool.id}Room1", 
          be_within(3).of(@timelimit_insec),
          events[0].id, [events[0].id, events[1].id, events[2].id])
        @tc.should_receive(:place_participant_in_conference).with("session_id_2", "15mcPool#{@pool.id}Room1",
          be_within(3).of(@timelimit_insec),
          events[1].id, [events[0].id, events[1].id, events[2].id])
        @tc.should_receive(:place_participant_in_conference).with("session_id_3", "15mcPool#{@pool.id}Room1",
          be_within(3).of(@timelimit_insec),
          events[2].id, [events[0].id, events[1].id, events[2].id])
        @tc.should_receive(:place_participant_in_conference).with("session_id_4", "15mcPool#{@pool.id}Room2",
          be_within(3).of(@timelimit_insec),
          events[3].id, [events[3].id, events[4].id, events[5].id])
        @tc.should_receive(:place_participant_in_conference).with("session_id_5", "15mcPool#{@pool.id}Room2",
          be_within(3).of(@timelimit_insec),
          events[4].id, [events[3].id, events[4].id, events[5].id])
        @tc.should_receive(:place_participant_in_conference).with("session_id_6", "15mcPool#{@pool.id}Room2",
          be_within(3).of(@timelimit_insec),
          events[5].id, [events[3].id, events[4].id, events[5].id])
        got = @pm.merge_calls_for_pool(@pool, @pool_runs_at, {})
        got[:placed].each_value{ |v| v.delete(:time)}
        got.should == @data.merge({
          :next_room   => 3,
          :on_hold     => {},
          :apologized  => {},
          :placed      => {
            "session_id_1" => {
              :room_name => "15mcPool#{@pool.id}Room1",
              :event_id => events[0].id,
            },
            "session_id_2" => {
              :room_name => "15mcPool#{@pool.id}Room1",
              :event_id => events[1].id,
            },            
            "session_id_3" => {
              :room_name => "15mcPool#{@pool.id}Room1",
              :event_id => events[2].id,
            },
            "session_id_4" => {
              :room_name => "15mcPool#{@pool.id}Room2",
              :event_id => events[3].id,
            },
            "session_id_5" => {
              :room_name => "15mcPool#{@pool.id}Room2",
              :event_id => events[4].id,
            },            
            "session_id_6" => {
              :room_name => "15mcPool#{@pool.id}Room2",
              :event_id => events[5].id,
            },
          },
        })
      end
      
      it "should skip participants that have already been placed" do
        new_participants = participant_list(3)
        data = @pm.initialize_data({})
        data[:on_hold] = {
          "session_id_1" => 1,          
        }
        data[:placed] = {
          "session_id_3" => {
            :room_name => "15mcPool34Event123",          
            :event_id => 3,
          },
        }
        @tc.should_receive(:place_participant_in_conference).with("session_id_1", "15mcPool#{@pool.id}Room1", @timelimit_insec,
          1, [1, 2])
        @tc.should_receive(:place_participant_in_conference).with("session_id_2", "15mcPool#{@pool.id}Room1", @timelimit_insec,
          2, [1, 2])
        got = @pm.merge_calls_for_pool(@pool, @pool_runs_at, data)
        got[:placed].each_value{ |v| v.delete(:time)}
        got.should == @data.merge({
          :next_room   => 2,
          :on_hold     => {
            "session_id_3" => 1,
          },
          :apologized  => {},
          :placed      => {
            "session_id_3" => {
              :room_name => "15mcPool34Event123",
              :event_id => 3,
            },
            "session_id_1" => {
              :room_name => "15mcPool#{@pool.id}Room1",
              :event_id => 1,
            },
            "session_id_2" => {
              :room_name => "15mcPool#{@pool.id}Room1",
              :event_id => 2,
            },
          },
        })
      end

      it "should skip participants that have already been placed and are Incoming when they're on hold for 1" do
        new_participants = participant_list(3)
        data = @pm.initialize_data({})
        data[:on_hold] = {
          "session_id_1" => 1,          
          "session_id_3" => 1,
        }
        data[:placed] = {
          "CA9fa67e8696b60ee1ca1e75ec81ef85e7OOO3" => {
            :room_name => "15mcPool34Room1",          
            :event_id => 3,
          },
        }
        @tc.should_receive(:place_participant_in_conference).with("session_id_1", "15mcPool#{@pool.id}Room1", 
          be_within(3).of(@timelimit_insec), 
          1, [1, 2])
        @tc.should_receive(:place_participant_in_conference).with("session_id_2", "15mcPool#{@pool.id}Room1", 
          be_within(3).of(@timelimit_insec), 
          2, [1, 2])
        got = @pm.merge_calls_for_pool(@pool, @pool_runs_at, data)
        got[:placed].each_value{ |v| v.delete(:time)}
        got.should == @data.merge({
          :next_room   => 2,
          :on_hold     => {
            "session_id_3" => 2,
          },
          :apologized  => {},
          :placed      => {
            "CA9fa67e8696b60ee1ca1e75ec81ef85e7OOO3" => {
              :room_name => "15mcPool34Room1",
              :event_id => 3,
            },
            "session_id_1" => {
              :room_name => "15mcPool#{@pool.id}Room1",
              :event_id => 1,
            },
            "session_id_2" => {
              :room_name => "15mcPool#{@pool.id}Room1",
              :event_id => 2,
            },
          },
        })
      end

      it "should place participants that have already been placed and are Incoming when they're on hold for 2" do
        participant_list(3)
        data = @pm.initialize_data({})
        data[:next_room] = 2
        data[:on_hold] = {
          "session_id_1" => 1,          
          "session_id_3" => 2,
        }
        data[:placed] = {
          "CA9fa67e8696b60ee1ca1e75ec81ef85e7OOO3" => {
            :room_name => "15mcPool#{@pool.id}Room1",
            :event_id => 3,
          },
          "CA9fa67e8696b60ee1ca1e75ec81ef85e7OOO4" => {
            :room_name => "15mcPool#{@pool.id}Room1",
            :event_id => 4,
          },
          "CAThisGuyCalledBackFromADifferentPhoneOOO4" => {
            :room_name => "15mcPool#{@pool.id}Room1",
            :event_id => 4,
          },
          "CA9fa67e8696b60ee1ca1e75ec81ef85e7OOO5" => {
            :room_name => "15mcPool#{@pool.id}Room1",
            :event_id => 5,
          },
        }
        @tc.should_receive(:place_participant_in_conference).with("session_id_1", "15mcPool#{@pool.id}Room2", @timelimit_insec,
          1, [1, 2])
        @tc.should_receive(:place_participant_in_conference).with("session_id_2", "15mcPool#{@pool.id}Room2", @timelimit_insec,
          2, [1, 2])
        @tc.should_receive(:place_participant_in_conference).with("session_id_3", "15mcPool#{@pool.id}Room1", @timelimit_insec,
          3, [3, 4, 5])
        got = @pm.merge_calls_for_pool(@pool, @pool_runs_at, data)
        got[:placed].each_value{ |v| v.delete(:time)}
        got.should == @data.merge({
          :next_room   => 3,
          :on_hold     => {},
          :apologized  => {},
          :placed      => {
            "session_id_1" => {
              :room_name => "15mcPool#{@pool.id}Room2",
              :event_id => 1,
            },
            "session_id_2" => {
              :room_name => "15mcPool#{@pool.id}Room2",
              :event_id => 2,
            },
            "session_id_3" => {
              :room_name => "15mcPool#{@pool.id}Room1",
              :event_id => 3,
            },
            "CA9fa67e8696b60ee1ca1e75ec81ef85e7OOO3" => {
              :room_name => "15mcPool#{@pool.id}Room1",
              :event_id => 3,
            },
            "CA9fa67e8696b60ee1ca1e75ec81ef85e7OOO4" => {
              :room_name => "15mcPool#{@pool.id}Room1",
              :event_id => 4,
            },
            "CAThisGuyCalledBackFromADifferentPhoneOOO4" => {
              :room_name => "15mcPool#{@pool.id}Room1",
              :event_id => 4,
            },
            "CA9fa67e8696b60ee1ca1e75ec81ef85e7OOO5" => {
              :room_name => "15mcPool#{@pool.id}Room1",
              :event_id => 5,
            },
          },
        })
      end

      it "should not duplicate the event_ids when merging in a callback" do
        participant_list(1)
        @tc.should_receive(:place_participant_in_conference).with("session_id_1", "15mcPool#{@pool.id}Room1", @timelimit_insec,
          1, [1, 2, 3])
        data = @pm.initialize_data({})
        data[:on_hold] = {
          "session_id_1" => 2,
        }
        data[:placed] = {
          "session_id_1" => {
            :room_name => "15mcPool#{@pool.id}Room1",
            :event_id => 1,
          },
          "session_id_2" => {
            :room_name => "15mcPool#{@pool.id}Room1",
            :event_id => 2,
          },
          "session_id_3" => {
            :room_name => "15mcPool#{@pool.id}Room1",
            :event_id => 3,
          },
        }
        @pm.merge_calls_for_pool(@pool, @pool_runs_at, data)
      end

      it "should merge callbacks into the same room they were in before" do
        participant_list(1)
        @tc.should_receive(:place_participant_in_conference).with("session_id_1", "15mcPool#{@pool.id}Room1", @pool.timelimit * 60, 
          1, [1, 2, 3])
        data = @pm.initialize_data({})
        data[:on_hold] = {
          "session_id_1" => 2,
        }
        data[:placed] = {
          "session_id_1" => {
            :room_name => "15mcPool#{@pool.id}Room1",
            :event_id => 1,
          },
          "session_id_2" => {
            :room_name => "15mcPool#{@pool.id}Room1",
            :event_id => 2,
          },
          "session_id_3" => {
            :room_name => "15mcPool#{@pool.id}Room1",
            :event_id => 3,
          },
          "session_id_4" => {
            :room_name => "15mcPool#{@pool.id}Room2",
            :event_id => 4,
          },
          "session_id_5" => {
            :room_name => "15mcPool#{@pool.id}Room2",
            :event_id => 5,
          },
        }
        Call.create(
          :Sid => 'session_id_1',
          :event_id => 1,
          :Duration => 66,
        )
        Call.create(
          :Sid => 'session_id_2',
          :event_id => 2,
          :Duration => nil,
        )
        Call.create(
          :Sid => 'session_id_3',
          :event_id => 3,
          :Duration => nil,
        )
        @pm.merge_calls_for_pool(@pool, @pool_runs_at - 3.hours, data)
      end

      it "should merge callbacks into a new room if it's old room is empty" do
        participant_list(1)
        @tc.should_receive(:place_participant_in_conference).with("session_id_1", "15mcPool#{@pool.id}Room2", @pool.timelimit * 60, 
          1, [4, 5])
        data = @pm.initialize_data({})
        data[:on_hold] = {
          "session_id_1" => 2,
        }
        data[:placed] = {
          "session_id_1" => {
            :room_name => "15mcPool#{@pool.id}Room1",
            :event_id => 1,
          },
          "session_id_2" => {
            :room_name => "15mcPool#{@pool.id}Room1",
            :event_id => 2,
          },
          "session_id_3" => {
            :room_name => "15mcPool#{@pool.id}Room1",
            :event_id => 3,
          },
          "session_id_4" => {
            :room_name => "15mcPool#{@pool.id}Room2",
            :event_id => 4,
          },
          "session_id_5" => {
            :room_name => "15mcPool#{@pool.id}Room2",
            :event_id => 5,
          },
        }
        Call.create(
          :Sid => 'session_id_1',
          :event_id => 1,
          :Duration => nil,
        )
        Call.create(
          :Sid => 'session_id_2',
          :event_id => 2,
          :Duration => 66,
        )
        Call.create(
          :Sid => 'session_id_3',
          :event_id => 3,
          :Duration => 66,
        )
        got = @pm.merge_calls_for_pool(@pool, @pool_runs_at - 3.hours, data)
        got[:placed].each_value{ |v| v.delete(:time)}
        got[:on_hold].should == {}
        got[:placed].should == {
          "session_id_1" => {
            :room_name => "15mcPool#{@pool.id}Room2",
            :event_id => 1,
          },
          "session_id_2" => {
            :room_name => "15mcPool#{@pool.id}Room1",
            :event_id => 2,
          },
          "session_id_3" => {
            :room_name => "15mcPool#{@pool.id}Room1",
            :event_id => 3,
          },
          "session_id_4" => {
            :room_name => "15mcPool#{@pool.id}Room2",
            :event_id => 4,
          },
          "session_id_5" => {
            :room_name => "15mcPool#{@pool.id}Room2",
            :event_id => 5,
          },          
        }
      end
    end

    describe "four participants" do
      it "should form two new conference of two participants each sorted by placed_id if there are no prefs" do
        events = create_events(4)
        events[2].user.placed_count = 11
        events[3].user.placed_count = 12
        events[1].user.placed_count = 13
        events[0].user.placed_count = 14
        events.each { |e| e.save; e.user.save }
        participant_list(4, events)
        @tc.should_receive(:place_participant_in_conference).with("session_id_1", "15mcPool#{@pool.id}Room1", 
          be_within(3).of(@timelimit_insec), 
          events[0].id, [events[2].id, events[0].id])
        @tc.should_receive(:place_participant_in_conference).with("session_id_3", "15mcPool#{@pool.id}Room1",
           be_within(3).of(@timelimit_insec), 
           events[2].id, [events[2].id, events[0].id])
        @tc.should_receive(:place_participant_in_conference).with("session_id_2", "15mcPool#{@pool.id}Room2",
          be_within(3).of(@timelimit_insec),
          events[1].id, [events[3].id, events[1].id])
        @tc.should_receive(:place_participant_in_conference).with("session_id_4", "15mcPool#{@pool.id}Room2",
          be_within(3).of(@timelimit_insec), 
          events[3].id, [events[3].id, events[1].id])
        got = @pm.merge_calls_for_pool(@pool, @pool_runs_at, {})
        got[:placed].each_value{ |v| v.delete(:time)}
        got.should == @data.merge({
          :next_room   => 3,
          :on_hold     => {},
          :apologized  => {},
          :placed      => {
            "session_id_1" => {
              :room_name => "15mcPool#{@pool.id}Room1",
              :event_id => events[0].id,
            },
            "session_id_3" => {
              :room_name => "15mcPool#{@pool.id}Room1",
              :event_id => events[2].id,
            },            
            "session_id_2" => {
              :room_name => "15mcPool#{@pool.id}Room2",
              :event_id => events[1].id,
            },
            "session_id_4" => {
              :room_name => "15mcPool#{@pool.id}Room2",
              :event_id => events[3].id,
            },
          },
        })
      end

      it "another way to write the above test..... Needs plumbing test to go along with it" do
        events = create_events(4)
        events[2].user.placed_count = 11
        events[3].user.placed_count = 12
        events[1].user.placed_count = 13
        events[0].user.placed_count = 14
        events.each { |e| e.save; e.user.save }
        new_participants = participant_list(4, events)
        pool = Pool.default_pool
        pool_runs_at = Time.now
        @pm.should_receive(:create_new_group).with([new_participants[2], new_participants[0]], pool, pool_runs_at, {})
        @pm.should_receive(:create_new_group).with([new_participants[3], new_participants[1]], pool, pool_runs_at, {})
        @pm.handle_four_new_participants(new_participants, pool, pool_runs_at, {})
        new_participants.should be_empty
      end

      it "groups all four together if there is a newbie even if their are prefs" do
        events = create_events_with_placed(4)
        newbie = events[0].user
        newbie.placed_count = 0
        newbie.save
        events[2].user.prefer!(events[3].user)
        events[3].user.prefer!(events[2].user)
        new_participants = participant_list(4, events)
        pool = Pool.default_pool
        pool_runs_at = Time.now
        @pm.should_receive(:create_new_group).with([new_participants[0], new_participants[1], new_participants[2], new_participants[3]], 
          pool, pool_runs_at, {})
        @pm.handle_four_new_participants(new_participants, pool, pool_runs_at, {})
        new_participants.should be_empty
      end
      
      it "makes two groups of two and respects a single persons pref for another" do
        events = create_events_with_placed(4)
        events[0].user.prefer!(events[1].user)
        new_participants = participant_list(4, events)
        pool = Pool.default_pool
        pool_runs_at = Time.now
        @pm.should_receive(:create_new_group).with([new_participants[0], new_participants[1]], pool, pool_runs_at, {})
        @pm.should_receive(:create_new_group).with([new_participants[2], new_participants[3]], pool, pool_runs_at, {})
        @pm.handle_four_new_participants(new_participants, pool, pool_runs_at, {})
        new_participants.should be_empty
      end
      
      it "makes two groups of two and respects a single persons avoids for two others" do
        events = create_events_with_placed(4)
        events[0].user.avoid!(events[1].user)
        events[0].user.avoid!(events[3].user)
        new_participants = participant_list(4, events)
        pool = Pool.default_pool
        pool_runs_at = Time.now
        @pm.should_receive(:create_new_group).with([new_participants[0], new_participants[2]], pool, pool_runs_at, {})
        @pm.should_receive(:create_new_group).with([new_participants[1], new_participants[3]], pool, pool_runs_at, {})
        @pm.handle_four_new_participants(new_participants, pool, pool_runs_at, {})
        new_participants.should be_empty
      end
      
      it "groups all four together if there is a four way pref loop" do
        events = create_events_with_placed(4)
        events[0].user.prefer!(events[1].user)
        events[1].user.prefer!(events[2].user)
        events[2].user.prefer!(events[3].user)
        events[3].user.prefer!(events[0].user)
        new_participants = participant_list(4, events)
        pool = Pool.default_pool
        pool_runs_at = Time.now
        @pm.should_receive(:create_new_group).with([new_participants[0], new_participants[1], new_participants[2], new_participants[3]], 
          pool, pool_runs_at, {})
        @pm.handle_four_new_participants(new_participants, pool, pool_runs_at, {})
        new_participants.should be_empty
      end

      it "groups all four together if one member prefers the other three" do
        events = create_events_with_placed(4)
        events[0].user.prefer!(events[1].user)
        events[0].user.prefer!(events[2].user)
        events[0].user.prefer!(events[3].user)
        new_participants = participant_list(4, events)
        pool = Pool.default_pool
        pool_runs_at = Time.now
        @pm.should_receive(:create_new_group).with([new_participants[0], new_participants[1], new_participants[2], new_participants[3]], 
          pool, pool_runs_at, {})
        @pm.handle_four_new_participants(new_participants, pool, pool_runs_at, {})
        new_participants.should be_empty
      end      

      it "splits into two if one member prefers the other three and one avoids the other" do
        events = create_events_with_placed(4)
        events[0].user.prefer!(events[1].user)
        events[0].user.prefer!(events[2].user)
        events[0].user.prefer!(events[3].user)
        events[1].user.avoid!(events[2].user)
        new_participants = participant_list(4, events)
        pool = Pool.default_pool
        pool_runs_at = Time.now
        @pm.should_receive(:create_new_group).with([new_participants[0], new_participants[1]], pool, pool_runs_at, {})
        @pm.should_receive(:create_new_group).with([new_participants[2], new_participants[3]], pool, pool_runs_at, {})
        @pm.handle_four_new_participants(new_participants, pool, pool_runs_at, {})
        new_participants.should be_empty
      end
      
      it "splits into two if one member prefers the other three and one avoids the one prefering" do
        events = create_events_with_placed(4)
        events[0].user.prefer!(events[1].user)
        events[0].user.prefer!(events[2].user)
        events[0].user.prefer!(events[3].user)
        events[1].user.avoid!(events[0].user)
        new_participants = participant_list(4, events)
        pool = Pool.default_pool
        pool_runs_at = Time.now
        @pm.should_receive(:create_new_group).with([new_participants[0], new_participants[3]], pool, pool_runs_at, {})
        @pm.should_receive(:create_new_group).with([new_participants[1], new_participants[2]], pool, pool_runs_at, {})
        @pm.handle_four_new_participants(new_participants, pool, pool_runs_at, {})
        new_participants.should be_empty
      end

      it "same case ordered differently, splits into two if one member prefers the other three and one avoids the one prefering" do
        events = create_events_with_placed(4)
        events[1].user.prefer!(events[0].user)
        events[1].user.prefer!(events[2].user)
        events[1].user.prefer!(events[3].user)
        events[0].user.avoid!(events[1].user)
        new_participants = participant_list_for_events(events)
        pool = Pool.default_pool
        pool_runs_at = Time.now
        @pm.should_receive(:create_new_group).with([new_participants[0], new_participants[3]], pool, pool_runs_at, {})
        @pm.should_receive(:create_new_group).with([new_participants[1], new_participants[2]], pool, pool_runs_at, {})
        @pm.handle_four_new_participants(new_participants, pool, pool_runs_at, {})
        new_participants.should be_empty
      end
    end
    
    describe "five particpants" do
      it "should ignore on_hold count and create two groups based on user_ids when there are no user prefs" do
        events = create_events(5)
        new_participants = participant_list_for_events(events)
        pool = Pool.default_pool
        pool_runs_at = Time.now
        data = @pm.initialize_data({})
        data[:on_hold] = {
          "session_id_4" => 2,
          "session_id_1" => 1,
        }
        @pm.should_receive(:create_new_group).with(
          [new_participants[0], new_participants[1], new_participants[2]], pool, pool_runs_at, data)
        @pm.should_receive(:create_new_group).with(
          [new_participants[3], new_participants[4]], pool, pool_runs_at, data)
        @pm.handle_new_participants(new_participants, pool, pool_runs_at, data)
        new_participants.should be_empty
      end

      it "should put them all into a single group with merge_type == 3" do
        events = create_events(5)
        pool = Factory(:pool, :merge_type => 3)
        new_participants = participant_list_for_events(events, pool)
        pool_runs_at = Time.now
        data = @pm.initialize_data({})
        @pm.should_receive(:create_new_group).with([
          new_participants[0], new_participants[1], new_participants[2], new_participants[3], new_participants[4]
        ], pool, pool_runs_at, data)
        @pm.handle_new_participants(new_participants, pool, pool_runs_at, data)
        new_participants.should be_empty
      end
    end
  end
  
  describe "pick_three_participants" do
    before(:each) do
      @pool = Factory(:pool, :merge_type => 1)
    end

    it "grabs the first three from the list" do
      events = create_events(3)
      participants = participant_list_for_events(events)

      three = @pm.pick_three_participants(participants, @pool)

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

      three = @pm.pick_three_participants(participants, @pool)

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

      three = @pm.pick_three_participants(participants, @pool)

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

      three = @pm.pick_three_participants(participants, @pool)

      extract_event_names(three).should == [events[2], events[3], events[4]].map(&:name)
      extract_event_names(participants).should == [events[0], events[1], events[5]].map(&:name)
    end

    it "it finds a group of three that all prefer each other" do
      events = create_events_with_placed(6)
      events[0].user.prefer!(events[2].user)
      events[0].user.prefer!(events[4].user)
      events[2].user.prefer!(events[0].user)
      events[2].user.prefer!(events[4].user)
      events[4].user.prefer!(events[0].user)
      events[4].user.prefer!(events[2].user)
      participants = participant_list_for_events(events)

      three = @pm.pick_three_participants(participants, @pool)

      extract_event_names(three).should == [events[0], events[2], events[4]].map(&:name)
      extract_event_names(participants).should == [events[1], events[3], events[5]].map(&:name)
    end

    it "it picks three people that don't have prefs for each other if they all avoid the others" do
      events = create_events_with_placed(5)
      events[0].user.avoid!(events[1].user)
      events[0].user.avoid!(events[4].user)
      events[3].user.avoid!(events[1].user)
      events[3].user.avoid!(events[4].user)
      events[2].user.avoid!(events[1].user)
      events[2].user.avoid!(events[4].user)
      participants = participant_list_for_events(events)

      three = @pm.pick_three_participants(participants, @pool)

      extract_event_names(three).should == [events[0], events[2], events[3]].map(&:name)
      extract_event_names(participants).should == [events[1], events[4]].map(&:name)
    end
    
    it "prefers users who's ids are close if there is no other information to go by" do
      events = create_events_with_placed(6)
      participants = participant_list_for_events(events).shuffle

      three = @pm.pick_three_participants(participants, @pool)

      extract_event_names(three).sort.should == [events[0], events[1], events[2]].map(&:name)
      extract_event_names(participants).sort.should == [events[3], events[4], events[5]].map(&:name)      
    end

    it "if merge_type is set to random it picks random users with not other information to go by" do
      @pool.merge_type = 2
      @pool.save

      events = create_events_with_placed(10)
      participants = participant_list_for_events(events).shuffle
      three = @pm.pick_three_participants(participants, @pool)
      picks1 = extract_event_names(three).sort
      participants.count.should == 7

      events = create_events_with_placed(10)
      participants = participant_list_for_events(events).shuffle
      three = @pm.pick_three_participants(participants, @pool)
      picks2 = extract_event_names(three).sort
      participants.count.should == 7

      picks1.should_not == picks2
    end

    it "finds a good match in the front of the list" do
      events = create_events_with_placed(14)
      matched_events = [events[0], events[1], events[2]]
      matched_events[0].user.prefer!(matched_events[1].user)
      matched_events[1].user.prefer!(matched_events[2].user)
      matched_events[2].user.prefer!(matched_events[0].user)
      participants = participant_list_for_events(events)
      three = @pm.pick_three_participants(participants, @pool)
      extract_event_names(three).should == matched_events.map(&:name)
    end

    it "finds a good match in the middle of the list" do
      events = create_events_with_placed(14)
      matched_events = [events[4], events[6], events[10]]
      matched_events[0].user.prefer!(matched_events[1].user)
      matched_events[1].user.prefer!(matched_events[2].user)
      matched_events[2].user.prefer!(matched_events[0].user)
      participants = participant_list_for_events(events)
      three = @pm.pick_three_participants(participants, @pool)
      extract_event_names(three).should == matched_events.map(&:name)
    end

    it "will miss a good match if the users are spread out past 12" do
      events = create_events_with_placed(14)
      matched_events = [events[0], events[12], events[13]]
      matched_events[0].user.prefer!(matched_events[1].user)
      matched_events[1].user.prefer!(matched_events[2].user)
      matched_events[2].user.prefer!(matched_events[0].user)
      participants = participant_list_for_events(events)
      three = @pm.pick_three_participants(participants, @pool)
      extract_event_names(three).should == [events[0], events[1], events[2]].map(&:name)
    end

    describe "rolling windows" do
      it "Takes c(6,3)=20 compute_pref_score computations to find the best match in 12" do
        events = create_events_with_placed(6)
        participants = participant_list_for_events(events)
        @pm.should_receive(:compute_pref_score).exactly(21).times.and_return([1, 2, 3, 4])
        three = @pm.pick_three_participants(participants, @pool)
      end

      it "Takes c(12,3)=220 compute_pref_score computations to find the best match in 12" do
        events = create_events_with_placed(12)
        participants = participant_list_for_events(events)
        @pm.should_receive(:compute_pref_score).exactly(221).times.and_return([1, 2, 3, 4])
        three = @pm.pick_three_participants(participants, @pool)
      end

      it "Takes c(12,3)=220 compute_pref_score computations to find the best match in 15" do
        events = create_events_with_placed(15)
        participants = participant_list_for_events(events)
        @pm.should_receive(:compute_pref_score).exactly(221).times.and_return([1, 2, 3, 4])
        three = @pm.pick_three_participants(participants, @pool)
      end
      # Therfore the numbers look like this
      # Totals: 3 => 1, 6 => 21, 9 => 105, 12 => 325, 15 => 325+220 = 545, 18 => 765, 21 => 985
      # Compared to a rolling window of 9
      # Totals: 3 => 1, 6 => 21, 9 => 105, 12 = 105+84 = 189,   15 => 273, 18 => 357, 21 => 441
    end
  end
 
  describe "compute_pref_score" do
    it "should compute a score based on preference among users" do
      user1 = Factory(:user)
      user2 = Factory(:user)
      user3 = Factory(:user)
      @pm.compute_pref_score([user1, user2, user3]).should == [0, 4, 3, user1.id]
      @pm.compute_pref_score([user1, user3]).should        == [0, 2, 2, user1.id]
      @pm.compute_pref_score([user1, user2]).should        == [0, 1, 2, user1.id]
      user1.prefer!(user2)
      @pm.compute_pref_score([user1, user2, user3]).should == [1, 4, 3, user1.id]
      user1.prefer!(user3)
      @pm.compute_pref_score([user1, user2, user3]).should == [2, 4, 3, user1.id]
      user2.prefer!(user1)
      user2.prefer!(user3)
      user3.prefer!(user1)
      user3.prefer!(user2)
      @pm.compute_pref_score([user1, user2, user3]).should == [6, 4, 3, user1.id]
      user1.avoid!(user2)
      @pm.compute_pref_score([user1, user2, user3]).should == [3, 4, 3, user1.id]
      user2.avoid!(user1)
      @pm.compute_pref_score([user1, user2, user3]).should == [0, 4, 3, user1.id]
      user3.avoid!(user1)
      @pm.compute_pref_score([user1, user2, user3]).should == [-3, 4, 3, user1.id]      
    end

    it "should shortcut to 0 if no one has any prefs" do
      user1 = mock('User')
      user2 = mock('User')
      user1.should_receive(:preferences).and_return([])
      user2.should_receive(:preferences).and_return([])
      user1.should_receive(:id).at_least(1).times.and_return(1)
      user2.should_receive(:id).at_least(1).times.and_return(2)
      user1.should_not_receive(:prefers?)
      user1.should_not_receive(:avoids?)
      user2.should_not_receive(:prefers?)
      user2.should_not_receive(:avoids?)
      @pm.compute_pref_score([user1, user2]).should == [0, 1, 2, user1.id]
    end
  end
  
  describe "initialize_data" do
    it "should initialize the empty hash" do
      @pm.initialize_data({}).should == {
        :next_room          => 1,
        :on_hold            => {},
        :placed             => {},
        :apologized         => {},
        :total              => 0,
        :waiting_for_events => [],
      }
    end

    it "should leave existing values alone" do
      data = {:next_room => 1, :placed => {1 => 2}, :on_hold => {2 => 3}}
      @pm.initialize_data(data).should == data
    end
  end
end

def participant_list(participant_count, events = [], pool = @pool)
  CallSession.where(:pool_id => @pool.id).each { |cs| cs.destroy }
  n = 0
  participant_count.times do
    n += 1
    call_session = CallSession.create!(
      :pool_id => pool.id,
      :session_id => 'session_id_' + n.to_s,
      :call_state => 'onhold',
      :event_id => n,
    )
    if events[n-1]
      call_session.event_id = events[n-1].id
      call_session.user_id = events[n-1].user_id
      call_session.pool_id = events[n-1].pool_id
      call_session.save
    end
  end
  CallSession.where(:pool_id => @pool.id).sort_by(&:id)
end

def create_events(count, placed = false)
  list = []
  i = 0
  count.times do
    user = Factory(:user)
    event = Factory(:event, :name => "Event #{i}", :user_id => user.id, :pool_id => @pool.id)
    if placed
      user.placed_count = i+1
      user.save
    end
    list << event
    i += 1
  end
  list
end

def create_events_with_placed(count)
  create_events(count, true)
end

def participant_list_for_events(events = [], pool = @pool)
  participant_list(events.count, events, pool)
end

def extract_events(participants)
  participants.map{ |p| Event.find(p.event_id) }
end

def extract_event_names(participants)
  extract_events(participants).map(&:name)
end