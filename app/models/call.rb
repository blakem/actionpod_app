# == Schema Information
# Schema version: 20110404044618
#
# Table name: calls
#
#  id             :integer         not null, primary key
#  Sid            :string(255)
#  DateCreated    :string(255)
#  DateUpdated    :string(255)
#  To             :string(255)
#  From           :string(255)
#  PhoneNumberSid :string(255)
#  Uri            :string(255)
#  event_id       :integer
#  created_at     :datetime
#  updated_at     :datetime
#

class Call < ActiveRecord::Base
end
