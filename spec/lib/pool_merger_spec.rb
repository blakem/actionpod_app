require 'spec_helper'

describe PoolMerger do
  before(:each) do
    @pm = PoolMerger.new
  end

  describe "merge_calls_for_pool" do
    it "sends each participant into a room" do
      tc = mock('TwilioCaller')
      TwilioCaller.should_receive(:new).and_return(tc)
      pool = Factory(:pool, :timelimit => 22)
      tc.should_receive(:participants_on_hold_for_pool).with(pool).and_return(participant_hash)
      tc.should_receive(:place_participant_in_conference).with("CA9fa67e8696b60ee1ca1e75ec81ef85e7", "Pool#{pool.id}Room1", 22)
      @pm.merge_calls_for_pool(pool, {})
    end
  end

end

def participant_response
  '{"page":0,"num_pages":1,"page_size":50,"total":1,"start":0,"end":0,"uri":"\/2010-04-01\/Accounts\/AC2e57bf710b77d765d280786bc07dbacc\/Conferences\/' +
  'CF0cb07a25bdaf64828850b784ea2d1aa7\/Participants.json","first_page_uri":"\/2010-04-01\/Accounts\/AC2e57bf710b77d765d280786bc07dbacc\/Conferences\/' +
  'CF0cb07a25bdaf64828850b784ea2d1aa7\/Participants.json?Page=0&PageSize=50","previous_page_uri":null,"next_page_uri":null,"last_page_uri":"\/2010-04-01\/' +
  'Accounts\/AC2e57bf710b77d765d280786bc07dbacc\/Conferences\/CF0cb07a25bdaf64828850b784ea2d1aa7\/Participants.json?Page=0&PageSize=50",' +
  '"participants":[{"conference_sid":"CF0cb07a25bdaf64828850b784ea2d1aa7","account_sid":"AC2e57bf710b77d765d280786bc07dbacc",' +
  '"call_sid":"CA9fa67e8696b60ee1ca1e75ec81ef85e7","muted":false,"end_conference_on_exit":false,"start_conference_on_enter":true,' +
  '"date_created":"Wed, 06 Apr 2011 19:10:13 +0000","date_updated":"Wed, 06 Apr 2011 19:10:13 +0000","uri":"\/2010-04-01\/Accounts\/' +
  'AC2e57bf710b77d765d280786bc07dbacc\/Conferences\/CF0cb07a25bdaf64828850b784ea2d1aa7\/Participants\/CA9fa67e8696b60ee1ca1e75ec81ef85e7.json"}]}'
end

def participant_hash
  ActiveSupport::JSON.decode(participant_response).with_indifferent_access[:participants]
end
