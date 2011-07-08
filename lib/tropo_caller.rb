class TropoCaller
  def account_token
    '04387300635ebe4cbc820020e5354055a8c4e24f72e407d1159abc03aa6a2a88896146fb9131e1804bae5736'
  end

  def api_version
    '1.0'
  end
  
  def phone_number
    '+14157660881'
  end

  def api_url
    'http://api.tropo.com/' + api_version + '/sessions'
  end
  
  def signal_url(session_id)
    api_url + '/' + session_id + '/signals'
  end
  
  def post_to_tropo(url, args)
    Net::HTTP.post_form(URI.parse(url), args)
  end
  
  def start_call_for_event(event)
    post_to_tropo(api_url, {
      :action => 'create',
      :token => account_token,
      :event_id => event.id,
    })
  end

  def place_participant_in_conference(session_id, conference_name, timelimit, event_id, event_ids)
    call_session = CallSession.find_by_session_id(session_id)
    call_session.conference_name = conference_name
    call_session.timelimit = timelimit
    call_session.event_ids = event_ids.join(',')
    call_session.call_state = 'placing'
    call_session.save
    send_signal_to_session('placed', session_id)
  end
  
  def send_signal_to_session(signal, session_id)
    post_to_tropo(signal_url(session_id), {:value => signal})
  end

#   def send_error_to_blake(error)
#     send_sms('+14153141222', error)
#   end

#   def apologize_no_other_participants(call_sid, event_id, participant_count)
#     update_call_status(call_sid, 'apologizing')
#     resp_hash = twilio_request(caller_uri(call_sid), 'POST', {
#      'Url' => base_url + "/apologize_no_other_participants.xml?participant_count=#{participant_count}&event=#{event_id}",
#     })
#   end
# 
#   def update_call_status(sid, status)
#     call = Call.find_by_Sid(sid)
#     if call
#       call.status = call.status.nil? ? status : call.status + "-#{status}"
#       call.save
#     end
#   end
#   
#   def send_sms(phone_number, text)
#     resp_hash = twilio_request(sms_uri, 'POST', {
#       :From => account_phone,
#       :To => phone_number,
#       :Body => text,
#     })
#   end
#   
  def self.create_call_from_call_hash(call_hash, event_id)
    user_id = nil
    event = Event.find_by_id(event_id)
    user_id = event.user_id if event
    Call.create(
      :event_id       => event_id,
      :user_id        => user_id,
      :Sid            => call_hash['session']['callId'],
      :DateCreated    => call_hash['session']['timestamp'],
      :DateUpdated    => call_hash['session']['timestamp'],
      :To             => call_hash['session']['to'] ? call_hash['session']['to']['name'] : nil,
      :From           => call_hash['session']['from'] ? call_hash['session']['from']['name'] : nil,
      :PhoneNumberSid => nil,
      :Uri            => nil,
      :Direction      => nil,
      :status         => call_hash['status'],
    )
  end
  
  def self.tropo_generator
    tg = Tropo::Generator.new(:voice => 'dave')
    tg.on :event => 'hangup', :next => '/tropo/callback.json'
    tg
  end
end