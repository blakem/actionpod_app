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

  def base_url
     'http://actionpods.heroku.com/twilio'
  end

  def caller_id
    '+14157669865'
  end
  
  def start_call_uri
    "/#{api_version}/Accounts/#{account_sid}/Calls"
  end

  def conferences_in_progress_uri
    "/#{api_version}/Accounts/#{account_sid}/Conferences.json?Status=in-progress"
  end

  def twilio_account
    @twilio_account ||= Twilio::RestAccount.new(account_sid, account_token)
  end
  
  def twilio_request_xml(*args)
    resp = twilio_account.request(*args) # XXX need to handle failure condition
    (Hash.from_xml resp.body).with_indifferent_access
  end

  def twilio_request(*args)
    resp = twilio_account.request(*args) # XXX need to handle failure condition
    ActiveSupport::JSON.decode(resp.body).with_indifferent_access
  end

  def start_call_for_event(event)
    post_args = {
        'From' => caller_id,
        'To' => event.user.primary_phone,
        'Url' => base_url + '/greeting.xml',
    }  
    response_hash = twilio_request_xml(start_call_uri, 'POST', post_args)
    call_hash = response_hash[:TwilioResponse][:Call]
    TwilioCaller.create_call_from_call_hash(call_hash, event.id)
  end
  
  # def merge_calls_for_pool(pool)
  # end


  def participants_on_hold_for_pool(pool)
    participants = []
    conferences_on_hold_for_pool(pool).each do |conference|
      participant_uri = conference[:subresource_uris][:participants]
      response_hash = twilio_request(participant_uri , 'GET')
      participant_list = response_hash[:participants]
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

  
  def self.create_call_from_call_hash(call_hash, event_id)
    Call.create(
      :event_id       => event_id,
      :Sid            => call_hash[:Sid],
      :DateCreated    => call_hash[:DateCreated],
      :DateUpdated    => call_hash[:DateUpdated],
      :To             => call_hash[:To],
      :From           => call_hash[:From],
      :PhoneNumberSid => call_hash[:PhoneNumberSid],
      :Uri            => call_hash[:Uri],
      :Direction      => call_hash[:Direction]
    )
  end
end