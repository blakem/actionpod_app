# == Schema Information
# Schema version: 20110329225808
#
# Table name: events
#
#  id            :integer         not null, primary key
#  name          :string(255)
#  schedule_yaml :text
#  user_id       :integer         not null
#  created_at    :datetime
#  updated_at    :datetime
#

class Event < ActiveRecord::Base
  belongs_to :user
end
