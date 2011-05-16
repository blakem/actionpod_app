# == Schema Information
# Schema version: 20110509184915
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
#  Direction      :string(255)
#  Duration       :integer
#  status         :string(255)
#  AnsweredBy     :string(255)
#

class Call < ActiveRecord::Base

  def status_category
    if status == 'outgoing'
      'Out InProgress'
    elsif status == 'outgoing-greeting:match-callback:match-completed'
      'NoAnswer'
    else
      '???'
    end
  end
end
