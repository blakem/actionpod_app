require 'spec_helper'

describe PoolMerger do
  before(:each) do
    @pm = PoolMerger.new
    @pool = Factory(:pool)
    @tc = mock('TwilioCaller')
    TwilioCaller.stub(:new).and_return(@tc)
    @pool_runs_at = Time.now - 5.minutes
  end

  describe "merge_calls_for_pool" do
    it "does nothing with zero new participants" do
      @tc.should_receive(:participants_on_hold_for_pool).with(@pool).and_return(participant_list(0))
      @pm.merge_calls_for_pool(@pool, @pool_runs_at, {}).should == {
        :next_room   => 1,
        :on_hold     => {},
        :placed      => {},
      }
    end

    it "initializes the hash even when passed :total" do
      @tc.should_receive(:participants_on_hold_for_pool).with(@pool).and_return(participant_list(0))
      @pm.merge_calls_for_pool(@pool, @pool_runs_at, {:total => 3}).should == {
        :next_room   => 1,
        :total => 3,
        :on_hold     => {},
        :placed      => {},
      }
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
        }
      end

      it "should tell him sorry and end call if he's been waiting a long time" do
        user = Factory(:user, :primary_phone => '+12223334444')
        event = Factory(:event, :user_id => user.id, :pool_id => @pool.id)
        new_participants = participant_list(1)
        new_participants[0][:conference_friendly_name] = "HoldEvent#{event.id}Pool555"
        @tc.should_receive(:participants_on_hold_for_pool).twice.with(@pool).and_return(new_participants)
        @tc.should_receive(:apologize_no_other_participants).with('CA9fa67e8696b60ee1ca1e75ec81ef85e7XXX1', 2)
        @tc.should_receive(:send_sms).with(user.primary_phone,
          "Sorry about that... I couldn't find anyone else for the call.  That shouldn't happen once we reach critical mass. ;-)"
        )
        data = @pm.initialize_data({})
        data[:on_hold] = {
          "CA9fa67e8696b60ee1ca1e75ec81ef85e7XXX1" => 3,
        }
        data[:total] = 2
        data = @pm.merge_calls_for_pool(@pool, @pool_runs_at, data)
        data.should == {
          :total       => 2,
          :next_room   => 1,
          :on_hold     => {
            "CA9fa67e8696b60ee1ca1e75ec81ef85e7XXX1" => 4,
          },
          :placed      => {},
        }
        data = @pm.merge_calls_for_pool(@pool, @pool_runs_at, data)
        data.should == {
          :total       => 2,
          :next_room   => 1,
          :on_hold     => {},
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
      end

      it "should put him in the smallest conference room if he's old" do
        new_participants = participant_list(1)
        @tc.should_receive(:participants_on_hold_for_pool).with(@pool).and_return(new_participants)
        @tc.should_receive(:place_participant_in_conference).with("CA9fa67e8696b60ee1ca1e75ec81ef85e7XXX1", "Pool#{@pool.id}Room3", @pool.timelimit, [1, 32, 33])
        data = {
          :on_hold => {"CA9fa67e8696b60ee1ca1e75ec81ef85e7XXX1" => 1},
          :next_room => 5,
          :placed      => {
            "CA9fa67e8696b60ee1ca1e75ec81ef85e7XXX11" => {
              :room_name => "Pool#{@pool.id}Room1",
              :event_id => 11,
            },
            "CA9fa67e8696b60ee1ca1e75ec81ef85e7XXX12" => {
              :room_name => "Pool#{@pool.id}Room1",
              :event_id => 12,
            },
            "CA9fa67e8696b60ee1ca1e75ec81ef85e7XXX13" => {
              :room_name => "Pool#{@pool.id}Room1",
              :event_id => 13,
            },
            "CA9fa67e8696b60ee1ca1e75ec81ef85e7XXX21" => {
              :room_name => "Pool#{@pool.id}Room2",
              :event_id => 21,
            },
            "CA9fa67e8696b60ee1ca1e75ec81ef85e7XXX22" => {
              :room_name => "Pool#{@pool.id}Room2",
              :event_id => 22,
            },
            "CA9fa67e8696b60ee1ca1e75ec81ef85e7XXX23" => {
              :room_name => "Pool#{@pool.id}Room2",
              :event_id => 23,
            },
            "CA9fa67e8696b60ee1ca1e75ec81ef85e7XXX32" => {
              :room_name => "Pool#{@pool.id}Room3",
              :event_id => 32,
            },
            "CA9fa67e8696b60ee1ca1e75ec81ef85e7XXX33" => {
              :room_name => "Pool#{@pool.id}Room3",
              :event_id => 33,
            },
            "CA9fa67e8696b60ee1ca1e75ec81ef85e7XXX41" => {
              :room_name => "Pool#{@pool.id}Room4",
              :event_id => 41,
            },
            "CA9fa67e8696b60ee1ca1e75ec81ef85e7XXX42" => {
              :room_name => "Pool#{@pool.id}Room4",
              :event_id => 42,
            },
            "CA9fa67e8696b60ee1ca1e75ec81ef85e7XXX43" => {
              :room_name => "Pool#{@pool.id}Room4",
              :event_id => 43,
            },
          },
        }
        got = @pm.merge_calls_for_pool(@pool, @pool_runs_at, data)
        expected = data
        expected[:placed]["CA9fa67e8696b60ee1ca1e75ec81ef85e7XXX1"] = {
          :room_name => "Pool#{@pool.id}Room3",
          :event_id => 1,          
        }
        expected[:on_hold] = {}
        got.should == expected
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
        }
      end

      it "should join them together if we've seen one of them before" do
        new_participants = participant_list(2)
        @tc.should_receive(:participants_on_hold_for_pool).with(@pool).and_return(new_participants)
        data = @pm.initialize_data({})
        data[:on_hold] = {
          "CA9fa67e8696b60ee1ca1e75ec81ef85e7XXX1" => 1,          
        }
        @tc.should_receive(:place_participant_in_conference).with("CA9fa67e8696b60ee1ca1e75ec81ef85e7XXX1", "Pool#{@pool.id}Room1", @pool.timelimit, [1, 2])
        @tc.should_receive(:place_participant_in_conference).with("CA9fa67e8696b60ee1ca1e75ec81ef85e7XXX2", "Pool#{@pool.id}Room1", @pool.timelimit, [1, 2])
        @pm.merge_calls_for_pool(@pool, @pool_runs_at, data).should == {
          :next_room   => 2,
          :on_hold     => {},
          :placed      => {
            "CA9fa67e8696b60ee1ca1e75ec81ef85e7XXX1" => {
              :room_name => "Pool#{@pool.id}Room1",
              :event_id => 1,
            },
            "CA9fa67e8696b60ee1ca1e75ec81ef85e7XXX2" => {
              :room_name => "Pool#{@pool.id}Room1",
              :event_id => 2,
            }
          },
        }
      end

      it "should join them together if we've seen both of them before" do
        new_participants = participant_list(2)
        @tc.should_receive(:participants_on_hold_for_pool).with(@pool).and_return(new_participants)
        data = @pm.initialize_data({})
        data[:on_hold] = {
          "CA9fa67e8696b60ee1ca1e75ec81ef85e7XXX1" => 1,          
          "CA9fa67e8696b60ee1ca1e75ec81ef85e7XXX2" => 1,          
        }
        @tc.should_receive(:place_participant_in_conference).with("CA9fa67e8696b60ee1ca1e75ec81ef85e7XXX1", "Pool#{@pool.id}Room1", @pool.timelimit, [1, 2])
        @tc.should_receive(:place_participant_in_conference).with("CA9fa67e8696b60ee1ca1e75ec81ef85e7XXX2", "Pool#{@pool.id}Room1", @pool.timelimit, [1, 2])
        @pm.merge_calls_for_pool(@pool, @pool_runs_at, data).should == {
          :next_room   => 2,
          :on_hold     => {},
          :placed      => {
            "CA9fa67e8696b60ee1ca1e75ec81ef85e7XXX1" => {
              :room_name => "Pool#{@pool.id}Room1",
              :event_id => 1,
            },
            "CA9fa67e8696b60ee1ca1e75ec81ef85e7XXX2" => {
              :room_name => "Pool#{@pool.id}Room1",
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
        @tc.should_receive(:place_participant_in_conference).with("CA9fa67e8696b60ee1ca1e75ec81ef85e7XXX1", "Pool#{@pool.id}Room1", @pool.timelimit, [1, 2, 3])
        @tc.should_receive(:place_participant_in_conference).with("CA9fa67e8696b60ee1ca1e75ec81ef85e7XXX2", "Pool#{@pool.id}Room1", @pool.timelimit, [1, 2, 3])
        @tc.should_receive(:place_participant_in_conference).with("CA9fa67e8696b60ee1ca1e75ec81ef85e7XXX3", "Pool#{@pool.id}Room1", @pool.timelimit, [1, 2, 3])
        @pm.merge_calls_for_pool(@pool, @pool_runs_at, {}).should == {
          :next_room   => 2,
          :on_hold     => {},
          :placed      => {
            "CA9fa67e8696b60ee1ca1e75ec81ef85e7XXX1" => {
              :room_name => "Pool#{@pool.id}Room1",
              :event_id => 1,
            },
            "CA9fa67e8696b60ee1ca1e75ec81ef85e7XXX2" => {
              :room_name => "Pool#{@pool.id}Room1",
              :event_id => 2,
            },            
            "CA9fa67e8696b60ee1ca1e75ec81ef85e7XXX3" => {
              :room_name => "Pool#{@pool.id}Room1",
              :event_id => 3,
            },
          },
        }
      end

      it "with six we should get two new conferences ordered by event_id" do
        new_participants = participant_list(6).reverse # reverse tests the sorting by event_id
        @tc.should_receive(:participants_on_hold_for_pool).with(@pool).and_return(new_participants)
        @tc.should_receive(:place_participant_in_conference).with("CA9fa67e8696b60ee1ca1e75ec81ef85e7XXX1", "Pool#{@pool.id}Room1", @pool.timelimit, [1, 2, 3])
        @tc.should_receive(:place_participant_in_conference).with("CA9fa67e8696b60ee1ca1e75ec81ef85e7XXX2", "Pool#{@pool.id}Room1", @pool.timelimit, [1 ,2 ,3])
        @tc.should_receive(:place_participant_in_conference).with("CA9fa67e8696b60ee1ca1e75ec81ef85e7XXX3", "Pool#{@pool.id}Room1", @pool.timelimit, [1, 2, 3])
        @tc.should_receive(:place_participant_in_conference).with("CA9fa67e8696b60ee1ca1e75ec81ef85e7XXX4", "Pool#{@pool.id}Room2", @pool.timelimit, [4, 5, 6])
        @tc.should_receive(:place_participant_in_conference).with("CA9fa67e8696b60ee1ca1e75ec81ef85e7XXX5", "Pool#{@pool.id}Room2", @pool.timelimit, [4, 5, 6])
        @tc.should_receive(:place_participant_in_conference).with("CA9fa67e8696b60ee1ca1e75ec81ef85e7XXX6", "Pool#{@pool.id}Room2", @pool.timelimit, [4, 5, 6])
        @pm.merge_calls_for_pool(@pool, @pool_runs_at, {}).should == {
          :next_room   => 3,
          :on_hold     => {},
          :placed      => {
            "CA9fa67e8696b60ee1ca1e75ec81ef85e7XXX1" => {
              :room_name => "Pool#{@pool.id}Room1",
              :event_id => 1,
            },
            "CA9fa67e8696b60ee1ca1e75ec81ef85e7XXX2" => {
              :room_name => "Pool#{@pool.id}Room1",
              :event_id => 2,
            },            
            "CA9fa67e8696b60ee1ca1e75ec81ef85e7XXX3" => {
              :room_name => "Pool#{@pool.id}Room1",
              :event_id => 3,
            },
            "CA9fa67e8696b60ee1ca1e75ec81ef85e7XXX4" => {
              :room_name => "Pool#{@pool.id}Room2",
              :event_id => 4,
            },
            "CA9fa67e8696b60ee1ca1e75ec81ef85e7XXX5" => {
              :room_name => "Pool#{@pool.id}Room2",
              :event_id => 5,
            },            
            "CA9fa67e8696b60ee1ca1e75ec81ef85e7XXX6" => {
              :room_name => "Pool#{@pool.id}Room2",
              :event_id => 6,
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
            :room_name => "Pool34Event123",          
            :event_id => 3,
          },
        }
        @tc.should_receive(:place_participant_in_conference).with("CA9fa67e8696b60ee1ca1e75ec81ef85e7XXX1", "Pool#{@pool.id}Room1", @pool.timelimit, [1, 2])
        @tc.should_receive(:place_participant_in_conference).with("CA9fa67e8696b60ee1ca1e75ec81ef85e7XXX2", "Pool#{@pool.id}Room1", @pool.timelimit, [1, 2])
        @pm.merge_calls_for_pool(@pool, @pool_runs_at, data).should == {
          :next_room   => 2,
          :on_hold     => {},
          :placed      => {
            "CA9fa67e8696b60ee1ca1e75ec81ef85e7XXX3" => {
              :room_name => "Pool34Event123",
              :event_id => 3,
            },
            "CA9fa67e8696b60ee1ca1e75ec81ef85e7XXX1" => {
              :room_name => "Pool#{@pool.id}Room1",
              :event_id => 1,
            },
            "CA9fa67e8696b60ee1ca1e75ec81ef85e7XXX2" => {
              :room_name => "Pool#{@pool.id}Room1",
              :event_id => 2,
            },
          },
        }
      end
    end
    
    describe "Handle those who are on hold first" do
      it "should put someone who's on hold at the front of the list" do
        new_participants = participant_list(4)
        @tc.should_receive(:participants_on_hold_for_pool).with(@pool).and_return(new_participants)
        @tc.should_receive(:place_participant_in_conference).with("CA9fa67e8696b60ee1ca1e75ec81ef85e7XXX4", "Pool#{@pool.id}Room1", @pool.timelimit, [4, 1, 2]).ordered
        @tc.should_receive(:place_participant_in_conference).with("CA9fa67e8696b60ee1ca1e75ec81ef85e7XXX1", "Pool#{@pool.id}Room1", @pool.timelimit, [4, 1, 2]).ordered
        @tc.should_receive(:place_participant_in_conference).with("CA9fa67e8696b60ee1ca1e75ec81ef85e7XXX2", "Pool#{@pool.id}Room1", @pool.timelimit, [4, 1, 2]).ordered
        data = @pm.initialize_data({})
        data[:on_hold] = {
          "CA9fa67e8696b60ee1ca1e75ec81ef85e7XXX4" => 2,
          "CA9fa67e8696b60ee1ca1e75ec81ef85e7XXX1" => 1,
        }
        @pm.merge_calls_for_pool(@pool, @pool_runs_at, data).should == {
          :next_room   => 2,
          :on_hold     => { "CA9fa67e8696b60ee1ca1e75ec81ef85e7XXX3" => 1 },
          :placed      => {
            "CA9fa67e8696b60ee1ca1e75ec81ef85e7XXX4" => {
              :room_name => "Pool#{@pool.id}Room1",
              :event_id => 4,
            },
            "CA9fa67e8696b60ee1ca1e75ec81ef85e7XXX1" => {
              :room_name => "Pool#{@pool.id}Room1",
              :event_id => 1,
            },
            "CA9fa67e8696b60ee1ca1e75ec81ef85e7XXX2" => {
              :room_name => "Pool#{@pool.id}Room1",
              :event_id => 2,
            },
          },
        }
      end
    end
  end

  describe "initialize_data" do
    it "should initialize the empty hash" do
      @pm.initialize_data({}).should == {
        :next_room   => 1,
        :on_hold     => {},
        :placed      => {},
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

def participant_list(participant_count)
  list = []
  stub_participant = ActiveSupport::JSON.decode(one_participant_response).with_indifferent_access[:participants][0]
  (1..participant_count).each do |i|
    participant = stub_participant.dup
    participant[:call_sid] += "XXX" + i.to_s
    participant[:conference_sid] += "XXX" + i.to_s
    participant[:conference_friendly_name] = "HoldEvent#{i}Pool555"
    list << participant
  end
  list
end
  
  
  