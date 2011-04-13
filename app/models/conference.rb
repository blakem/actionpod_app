# == Schema Information
# Schema version: 20110413091942
#
# Table name: conferences
#
#  id         :integer         not null, primary key
#  room_name  :string(255)
#  status     :string(255)
#  pool_id    :integer
#  started_at :datetime
#  ended_at   :datetime
#  created_at :datetime
#  updated_at :datetime
#

class Conference < ActiveRecord::Base
  has_and_belongs_to_many :users
end
