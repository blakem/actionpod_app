class TropoCaller
  # def account_sid
  #   'AC2e57bf710b77d765d280786bc07dbacc'
  # end
  
  # if request.post?
  #      @my_tropo_token = "PLACE YOUR TOKEN HERE"
  #      @API_URL='http://api.tropo.com/1.0/sessions?action=create&' 
  #      Net::HTTP.get_print URI.parse(URI.encode(@API_URL+'&token='+@my_tropo_token+'&number_to_dial='+params[:call][:number]+"&message="+params[:call][:message]+'&from_number='+params[:call][:from])) 
  #      redirect_to root_path
  # end
  
  def account_token
    '04387300635ebe4cbc820020e5354055a8c4e24f72e407d1159abc03aa6a2a88896146fb9131e1804bae5736'
  end

  def api_version
    '1.0'
  end

  def api_url
    'http://api.tropo.com/' + api_version + '/sessions'
  end
  
  def make_call
    res = Net::HTTP.post_form(URI.parse(api_url), {
      :action => 'create',
      :token => account_token,
      :number_to_dial => '+14153141222',
      :message => 'Hello from Tropo',
    })
    puts res.inspect
    puts res.body
  end
  
#   def account_phone
#     '+14157669865'
#   end
# 
#   def base_url
#      'http://www.15minutecalls.com/twilio'
#   end
# 
#   def caller_id
#     '+14157669865'
#   end
#   
#   def twilio_base_url
#     "/#{api_version}/Accounts/#{account_sid}"
#   end
#   
#   def start_call_uri
#     twilio_base_url + '/Calls.json'
#   end
# 
#   def conferences_in_progress_uri
#     twilio_base_url + '/Conferences.json?Status=in-progress'
#   end
# 
#   def caller_uri(call_sid)
#     twilio_base_url + "/Calls/#{call_sid}.json"
#   end
# 
#   def sms_uri
#     twilio_base_url + '/SMS/Messages.json'
#   end
# 
#   def twilio_account
#     @twilio_account ||= Twilio::RestAccount.new(account_sid, account_token)
#   end
#   
#   def twilio_request(*args)
#     resp = twilio_account.request(*args)
#     unless (resp.kind_of?(Net::HTTPOK) or resp.kind_of?(Net::HTTPSuccess))
#       resp = twilio_account.request(*args)
#       send_error_to_blake("Retrying twilio_request: ResponseCode:#{resp.class}") unless args[0] == sms_uri
#       unless resp.respond_to?('body')
#         send_error_to_blake("Fatal twilio_request not retrying: ResponseCode:#{resp.class}") unless args[0] == sms_uri
#         return {}
#       end
#     end
#     hash = ActiveSupport::JSON.decode(resp.body).with_indifferent_access
#     if (hash[:num_pages] and hash[:num_pages].to_i > 1)
#       send_error_to_blake("WARNING: GOT A RESPONSE THAT NEED TO BE PAGED: #{hash[:num_pages]}")
#     end
#     hash
#   end
#   
#   def send_error_to_blake(error)
#     send_sms('+14153141222', error)
#   end
# 
#   def start_call_for_event(event)
#     post_args = {
#       'Url' => base_url + '/greeting.xml',
#       'FallbackUrl' => base_url + '/greeting_fallback.xml',
#     }
#     if event.user.use_ifmachine
#       post_args['Url'] = base_url + '/go_directly_to_conference.xml'
#       post_args['IfMachine'] = 'Hangup'
#     end
#     call_hash = start_call_for_user(event.user, post_args)
#     TwilioCaller.create_call_from_call_hash(call_hash.merge(:status => 'outgoing'), event.id)
#   end
# 
#   def start_call_for_user(user, post_args = {})
#     twilio_request(start_call_uri, 'POST', post_args.merge({
#       'From' => caller_id,
#       'To' => user.primary_phone.number,
#       'StatusCallback' => base_url + '/callback.xml',      
#     }))
#   end
#   
#   def place_participant_in_conference(call_sid, conference, timelimit, event_id, event_ids)
#     update_call_status(call_sid, "placing:#{conference}")
#     events = event_ids.join(',')
#     resp_hash = twilio_request(caller_uri(call_sid), 'POST', {
#      'Url' => base_url + "/place_in_conference.xml?conference=#{conference}&timelimit=#{timelimit}&events=#{events}&event=#{event_id}",
#     })
#   end
# 
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
#   def participants_on_hold_for_pool(pool)
#     participants = []
#     conferences_on_hold_for_pool(pool).each do |conference|
#       participant_uri = conference[:subresource_uris][:participants]
#       response_hash = twilio_request(participant_uri , 'GET')
#       participant_list = response_hash[:participants]
#       participant_list.each do |participant|
#         participant[:conference_friendly_name] = conference[:friendly_name]
#       end
#       participants += participant_list
#     end
#     participants
#   end
#     
#   def conferences_on_hold_for_pool(pool)
#     conferences_in_progress.select { |conference| conference[:friendly_name] =~ /^15mcHold.*Pool#{pool.id}($|\D)/ }
#   end
#   
#   def conferences_in_progress
#     response_hash = twilio_request(conferences_in_progress_uri, 'GET')
#     response_hash[:conferences]
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
    Tropo::Generator.new(:voice => 'dave')
  end
end