# == Schema Information
# Schema version: 20110419233934
#
# Table name: plans
#
#  id         :integer         not null, primary key
#  body       :text
#  user_id    :integer         not null
#  created_at :datetime
#  updated_at :datetime
#

class Plan < ActiveRecord::Base
  belongs_to :user
  validates_presence_of :body

end
