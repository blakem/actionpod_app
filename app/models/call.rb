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
    elsif status == 'outgoing-greeting:match-callback:match'
      'Got CallBack'
    elsif status == 'outgoing-greeting:match'
      'Got Greeting'
    elsif status == 'outgoing-greeting:match-callback:match-completed'
      'NoAnswer'
    elsif status =~ /outgoing-greeting:match-onhold:match-placing:\w+-placed:\w+-callback:match-completed/
      'Success'
    elsif status =~ /incoming-onhold-placing:\w+-placed:\w+-callback:match-completed/
      'InSuccess'
    elsif status =~ /outgoing-direct:match-placing:\w+-placed:\w+-callback:match-completed/
      'DirSuccess'
    elsif status == 'incoming-onhold-apologizing-apologized-callback:match-completed'
      'InOnlyOne'
    elsif status == 'outgoing-direct:match-apologizing-apologized-callback:match-completed'
      'DirOnlyOne'
    else
      '???'
    end
  end
end
