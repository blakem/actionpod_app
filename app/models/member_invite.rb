# == Schema Information
# Schema version: 20110609210122
#
# Table name: member_invites
#
#  id          :integer         not null, primary key
#  sender_id   :integer
#  to_id       :integer
#  pool_id     :integer
#  invite_code :string(255)
#  body        :text
#  created_at  :datetime
#  updated_at  :datetime
#

class MemberInvite < ActiveRecord::Base
end
