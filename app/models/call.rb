# == Schema Information
# Schema version: 20110711220438
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
#  user_id        :integer
#  session_id     :string(255)
#

class Call < ActiveRecord::Base

  def status_category
    if status == 'outgoing'
      'Out InProgress'
    elsif status == 'outgoing-greeting-callback'
      'NoAnswer'
    elsif status == 'outgoing-greeting-nokeypress-callback'
      'NoAnswer'
    elsif status =~ /^outgoing-greeting-onhold-apologizing/
      'Apology'
    elsif status =~ /^outgoing-greeting-onhold-placed/
      'Placed'
    elsif status == 'inbound-onhold-callback'
      'Inbound Notplaced'
    elsif status == 'outgoing-greeting-onhold-callback'
      'Hangup'
    else
      '???'
    end
  end
  
  def cost
    cost = 0.00
    duration = (self.Duration || 0) / 60
    cost += self.Direction == 'outbound-api' ? duration * 0.02 : duration * 0.01
    
    event = Event.find_by_id(self.event_id)
    if event
      cost += 0.05 * event.pool.timelimit / 60.0
      if event.send_sms_reminder
        cost += 0.02
      end
    end
    
    sprintf("%.2f", cost).to_f
  end
end
