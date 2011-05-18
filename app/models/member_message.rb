# == Schema Information
# Schema version: 20110518002551
#
# Table name: member_messages
#
#  id         :integer         not null, primary key
#  sender_id  :integer
#  to_id      :integer
#  body       :text
#  created_at :datetime
#  updated_at :datetime
#

class MemberMessage < ActiveRecord::Base
end
