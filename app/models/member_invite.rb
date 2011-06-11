# == Schema Information
# Schema version: 20110611004315
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
#  email       :string(255)
#

class MemberInvite < ActiveRecord::Base

  def self.generate_token
    loop do
      token = Devise.friendly_token
      unless MemberInvite.find_by_invite_code(token) or InviteCode.find_by_name(token) or token == User.secret_invite_code
        break token
      end
    end
  end
end
