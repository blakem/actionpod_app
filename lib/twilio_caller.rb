class TwilioCaller
  def account_sid
    'AC2e57bf710b77d765d280786bc07dbacc'
  end
  
  def account_token
    'fc9bd67bb8deee6befd3ab0da3973718'
  end

  def api_version
    '2010-04-01'
  end
  
  def account_phone
    '+14157669865'
  end

  def base_url
     'http://www.15minutecalls.com/twilio'
  end

  def caller_id
    '+14157669865'
  end
  
  def twilio_base_url
    "/#{api_version}/Accounts/#{account_sid}"
  end
  
  def start_call_uri
    twilio_base_url + '/Calls.json'
  end

  def conferences_in_progress_uri
    twilio_base_url + '/Conferences.json?Status=in-progress'
  end

  def caller_uri(call_sid)
    twilio_base_url + "/Calls/#{call_sid}.json"
  end

  def sms_uri
    twilio_base_url + '/SMS/Messages.json'
  end

  def twilio_account
    @twilio_account ||= Twilio::RestAccount.new(account_sid, account_token)
  end
  
  def twilio_request(*args)
    resp = twilio_account.request(*args) # XXX need to handle failure condition
    unless resp.success?
      resp = twilio_account.request(*args) # XXX need to handle failure condition
      send_error_to_blake("Retrying twilio_request: ResponseCode:#{resp.code}")
    end      
    hash = ActiveSupport::JSON.decode(resp.body).with_indifferent_access
    if (hash[:num_pages] and hash[:num_pages].to_i > 1)
      send_error_to_blake("WARNING: GOT A RESPONSE THAT NEED TO BE PAGED: #{hash[:num_pages]}")
    end
    hash
  end
  
  def send_error_to_blake(error)
  end

  def start_call_for_event(event)
    post_args = {
      'From' => caller_id,
      'To' => event.user.primary_phone,
      'Url' => base_url + '/greeting.xml',
      'FallbackUrl' => base_url + '/greeting_fallback.xml',
      'StatusCallback' => base_url + '/callback.xml',
    }
    if event.user.use_ifmachine
      post_args['Url'] = base_url + '/go_directly_to_conference.xml'
      post_args['IfMachine'] = 'Hangup'
    end
    call_hash = twilio_request(start_call_uri, 'POST', post_args)
    TwilioCaller.create_call_from_call_hash(call_hash, event.id)
  end
  
  def place_participant_in_conference(call_sid, conference, timelimit, event_ids)
    events = event_ids.join(',')
    resp_hash = twilio_request(caller_uri(call_sid), 'POST', {
     'Url' => base_url + "/place_in_conference.xml?conference=#{conference}&timeout=#{timelimit}&events=#{events}",
    })
  end

  def apologize_no_other_participants(call_sid, participant_count)
    resp_hash = twilio_request(caller_uri(call_sid), 'POST', {
     'Url' => base_url + "/apologize_no_other_participants.xml?participant_count=#{participant_count}",
    })
  end
  
  def participants_on_hold_for_pool(pool)
    participants = []
    conferences_on_hold_for_pool(pool).each do |conference|
      participant_uri = conference[:subresource_uris][:participants]
      response_hash = twilio_request(participant_uri , 'GET')
      participant_list = response_hash[:participants]
      participant_list.each do |participant|
        participant[:conference_friendly_name] = conference[:friendly_name]
      end
      participants += participant_list
    end
    participants
  end
    
  def conferences_on_hold_for_pool(pool)
    conferences_in_progress.select { |conference| conference[:friendly_name] =~ /Pool#{pool.id}$/ }
  end
  
  def conferences_in_progress
    response_hash = twilio_request(conferences_in_progress_uri, 'GET')
    response_hash[:conferences]
  end
  
  def send_sms(phone_number, text)
    resp_hash = twilio_request(sms_uri, 'POST', {
      :From => account_phone,
      :To => phone_number,
      :Body => text,
    })
  end
  
  def self.create_call_from_call_hash(call_hash, event_id)
    Call.create(
      :event_id       => event_id,
      :Sid            => call_hash[:Sid]             || call_hash[:sid],
      :DateCreated    => call_hash[:DateCreated]     || call_hash[:date_created],
      :DateUpdated    => call_hash[:DateUpdated]     || call_hash[:date_updated],    
      :To             => call_hash[:To]              || call_hash[:to],
      :From           => call_hash[:From]            || call_hash[:from],
      :PhoneNumberSid => call_hash[:PhoneNumberSid]  || call_hash[:phone_number_sid],
      :Uri            => call_hash[:Uri]             || call_hash[:uri],
      :Direction      => call_hash[:Direction]       || call_hash[:direction]
    )
  end
end