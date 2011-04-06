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

  def start_call_for_event(event)
    post_args = {
        'From' => caller_id,
        'To' => event.user.primary_phone,
        'Url' => base_url + '/greeting.xml',
    }  
    account = Twilio::RestAccount.new(account_sid, account_token)
    resp = account.request(start_call_uri, 'POST', post_args) # XXX need to handle failure condition
    response_hash = (Hash.from_xml resp.body).with_indifferent_access
    call_hash = response_hash[:TwilioResponse][:Call]
    TwilioCaller.create_call_from_call_hash(call_hash, event.id)
  end
  
  def conferences_in_progress
    account = Twilio::RestAccount.new(account_sid, account_token)
    resp = account.request(conferences_in_progress_uri, 'GET') # XXX need to handle failure condition
    response_hash = (Hash.from_xml resp.body).with_indifferent_access
    conference_hash = response_hash[:TwilioResponse][:Conferences]
    total = conference_hash[:total].to_i
    conferences = []
    if total == 1
      conferences = [conference_hash[:Conference]]
    elsif total > 1
      conferences = conference_hash[:Conference]
    end
    conferences
  end

  def conferences_in_progress_uri
    "/#{api_version}/Accounts/#{account_sid}/Conferences?Status=in-progress"
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