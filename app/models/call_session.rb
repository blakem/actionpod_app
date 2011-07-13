# == Schema Information
# Schema version: 20110713010146
#
# Table name: call_sessions
#
#  id                :integer         not null, primary key
#  session_id        :string(255)
#  call_id           :string(255)
#  pool_id           :integer
#  user_id           :integer
#  event_id          :integer
#  direction         :string(255)
#  call_state        :string(255)
#  created_at        :datetime
#  updated_at        :datetime
#  conference_name   :string(255)
#  timelimit         :integer
#  event_ids         :string(255)
#  participant_count :integer
#

class CallSession < ActiveRecord::Base
end
