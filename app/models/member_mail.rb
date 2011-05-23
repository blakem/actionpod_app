# == Schema Information
# Schema version: 20110523212532
#
# Table name: member_mails
#
#  id         :integer         not null, primary key
#  user_id    :integer
#  sent_at    :datetime
#  email_type :string(255)
#  created_at :datetime
#  updated_at :datetime
#

class MemberMail < ActiveRecord::Base
end
