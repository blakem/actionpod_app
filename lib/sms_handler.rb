class SmsHandler

  def process_sms(text, number)
    text = text.strip.upcase
    response = ''
    if text == 'BUSY'
      response = handle_busy(number)
    elsif text == 'NEXT'
      response = handle_next(number)
    end
    
    return response.blank? ? welcome_message : response
  end

  def handle_busy(number)
    phone = Phone.find_by_number(number)
    return nil unless phone
    user = phone.user
    event = user.event_with_next_call_time
    return nil unless event
    skip_dates = event.skip_dates
    skip_dates = skip_dates + ',' unless skip_dates.blank?
    next_occurrence = event.next_occurrence
    event.skip_dates = skip_dates + next_occurrence.strftime("%m/%d/%Y")
    event.save
    "Ok, call cancelled. Your next call is at: #{user.next_call_time_string}."
  end
  
  def handle_next(number)
    phone = Phone.find_by_number(number)
    return nil unless phone
    "Your next call is at: #{phone.user.next_call_time_string}."
  end
  
  def welcome_message
    "Welcome to 15 Minute Calls.  See 15minutecalls.com for more information."
  end
end

