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
    elsif status =~ /^outgoing-greeting:match-onhold:match-placing:\w+-placed:\w+-callback:match-completed$/
      'Success'
    elsif status =~ /^incoming-onhold-placing:\w+-placed:\w+-callback:match-completed$/
      'InSuccess'
    elsif status =~ /^outgoing-direct:match-placing:\w+-placed:\w+-callback:match-completed$/
      'DirSuccess'
    elsif status =~ /fallback/
      'FallbackError'
    elsif status =~ /^outgoing-greeting:match-onhold:match-(apologizing-apologized-)?callback:match-completed$/
      'OutOnlyOne'
    elsif status == 'incoming-onhold-apologizing-apologized-callback:match-completed'
      'InOnlyOne'
    elsif status == 'outgoing-direct:match-apologizing-apologized-callback:match-completed'
      'DirOnlyOne'
    elsif status == 'outgoing-callback:match-completed'
      if event_id
        event = Event.find_by_id(event_id)
        if event && event.user.use_ifmachine
          return 'DirNoAnswer'
        elsif event && !event.user.use_ifmachine
          return 'PossibleError'
        end
      end
      '????'
    else
      '???'
    end
  end
  
  def cost
    cost = 0.00
    if self.Direction == 'outbound-api'
      cost += self.Duration * 0.02
    else
      cost += self.Duration * 0.01
    end
    
    event = Event.find_by_id(self.event_id)
    if event
      cost += 0.10 * event.pool.timelimit / 60.0
      if event.send_sms_reminder
        cost += 0.02
      end
    end
    
    cost
  end
end
