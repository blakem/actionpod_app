# == Schema Information
# Schema version: 20110706203257
#
# Table name: call_sessions
#
#  id         :integer         not null, primary key
#  session_id :string(255)
#  call_id    :string(255)
#  pool_id    :integer
#  user_id    :integer
#  event_id   :integer
#  direction  :string(255)
#  call_state :string(255)
#  created_at :datetime
#  updated_at :datetime
#

class CallSession < ActiveRecord::Base
end
