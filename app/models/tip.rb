# == Schema Information
# Schema version: 20110509053936
#
# Table name: tips
#
#  id         :integer         not null, primary key
#  body       :text
#  created_at :datetime
#  updated_at :datetime
#

class Tip < ActiveRecord::Base
  validates_presence_of :body
end
