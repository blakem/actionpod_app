# == Schema Information
# Schema version: 20110330183523
#
# Table name: pools
#
#  id         :integer         not null, primary key
#  name       :string(255)
#  user_id    :integer         not null
#  created_at :datetime
#  updated_at :datetime
#

class Pool < ActiveRecord::Base
  belongs_to :user
end
