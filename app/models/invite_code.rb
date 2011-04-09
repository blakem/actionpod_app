# == Schema Information
# Schema version: 20110409010517
#
# Table name: invite_codes
#
#  id         :integer         not null, primary key
#  name       :string(255)
#  created_at :datetime
#  updated_at :datetime
#

class InviteCode < ActiveRecord::Base
end
