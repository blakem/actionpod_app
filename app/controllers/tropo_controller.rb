class TropoController < ApplicationController

  respond_to :json

  def greeting
    puts params.inspect
    event = find_event_from_params(params)
    t = Tropo::Generator.new
    unless event
      #   update_call_status_from_params(params, 'greeting:nomatch')
      t.say "I'm sorry I can't match this number up with a scheduled event. Goodbye."
    else
      #   update_call_status_from_params(params, 'greeting:match')
      #   @postto = base_url + '/put_on_hold.xml'
      t.say "Welcome to your #{event.name_in_second_person}. Press 1 to join the conference.", :voice => 'dave'
      log_message("GREETING for #{event.user.name}")
    end
    render :inline => t.response
  end
  
  def greeting_fallback
    TwilioCaller.new.send_error_to_blake('Fallback: ' + params[:CallSid])
    event = find_event_from_params(params)
    unless event
      update_call_status_from_params(params, 'fallback:nomatch')
      self.say_sorry
      render :action => :say_sorry
    else
      update_call_status_from_params(params, 'fallback:match')
      self.put_on_hold
      render :action => :put_on_hold
    end
  end
  
  def callback
    call = Call.find_by_Sid(params[:CallSid])
    call.Duration = params[:CallDuration]
    call.AnsweredBy = params[:AnsweredBy] if params[:AnsweredBy]
    call.save
    bailed_before_greeting = call.status == 'outgoing'
    event = find_event_from_params(params)
    unless event
      update_call_object_status(call, 'callback:nomatch')
    else
      update_call_object_status(call, 'callback:match')
      if call.status =~ /^outgoing/ && (call.status !~ /-onhold/ && call.status !~ /-direct:match-/)
        update_missed_count(event.user) unless bailed_before_greeting
      end
      log_message("CALLBACK for #{event.user.name}")
    end
    update_call_object_status(call, 'completed')
    TwilioCaller.new.send_error_to_blake('OutgoingBug: ' + params[:CallSid]) if bailed_before_greeting
  end

  def say_sorry
  end
  
  def place_test_call
    @postto = base_url + '/place_test_call_thanks.xml'
  end
  def place_test_call_thanks
  end

  def apologize_no_other_participants
    update_call_status_from_params(params, 'apologized')
    @other_participants = params[:participant_count].to_i - 1
    @people = @other_participants == 1 ? 'person' : 'people'
    @event = Event.find_by_id(params[:event])
    @next_call_time = @event ? @event.user.next_call_time_string : ''
    @user = @event.user
    @pool = @event.pool
    @timelimit = @pool.timelimit * 60
  end

  def go_directly_to_conference
    event = find_event_from_params(params)
    unless event
      update_call_status_from_params(params, 'direct:nomatch', 'AnsweredBy' => params[:AnsweredBy])
      self.say_sorry
      render :action => :say_sorry
    else
      update_call_status_from_params(params, 'direct:match', 'AnsweredBy' => params[:AnsweredBy])
      update_answered_count(event.user)
      @event_name = event.name_in_second_person
      @timelimit = event.pool.timelimit
      @pool = event.pool
      @user = event.user
      @event = event
      @timelimit *= 60
      log_message("DIRECT for #{event.user.name}")
    end
  end

  def put_on_hold
    event = find_event_from_params(params)
    unless event
      update_call_status_from_params(params, 'onhold:nomatch')
      self.say_sorry
      render :action => :say_sorry
    else
      update_call_status_from_params(params, 'onhold:match')
      update_answered_count(event.user)
      @timelimit = event.pool.timelimit
      @pool = event.pool 
      @event = event
      @user = event.user
      @timelimit *= 60
      log_message("ONHOLD for #{event.user.name}")
    end
  end

  def incoming
    event = find_event_from_params(params)
    event_id = event ? event.id : nil
    call = TwilioCaller.create_call_from_call_hash(params.merge(:Sid => params[:CallSid], :status => 'incoming'), event_id)
    unless event
      update_call_object_status(call, 'nomatch')
      self.say_sorry
      render :action => :say_sorry
    else
      update_call_object_status(call, 'onhold')
      update_incoming_count(event.user)
      @event_name = event.name_in_second_person
      @timelimit = event.pool.timelimit
      @pool = event.pool
      @user = event.user
      @event = event
      @timelimit *= 60
      log_message("INCOMING for #{event.user.name}")
    end
  end

  def place_in_conference
    @names = build_intro_string(params[:events])
    @timelimit = params[:timelimit] ? params[:timelimit].to_i : 15 * 60
    @conference = params[:conference] || 'DefaultConference'
    update_call_status_from_params(params, "placed:#{@conference}")
    event = Event.find_by_id(params[:event])
    if event
      @next_call_time = event.user.next_call_time_string
      log_message("CONFERENCE for #{event.user.name} - #{@conference}")
    else
      @next_call_time = ''
    end
  end
  
  def sms
  end

  private
    def base_url 
      "http://www.15minutecalls.com/twilio"
    end
    
    def update_answered_count(user)
      user.answered_count += 1
      user.made_in_a_row += 1
      user.missed_in_a_row = 0
      user.save
    end

    def update_missed_count(user)
      user.missed_in_a_row += 1
      user.made_in_a_row = 0
      user.save
    end

    def update_incoming_count(user)
      user.incoming_count += 1
      user.save
    end

    def update_call_object_status(call, status, args = {})
      return unless call
      call.status = call.status.nil? ? status : call.status + "-#{status}"
      call.update_attributes(args) unless args.empty?      
      call.save
    end

    def update_call_status_from_params(params, status, args = {})
      call = Call.find_by_Sid(params[:CallSid])
      update_call_object_status(call, status, args)
    end

    def find_event_from_params(params)
#      call = match_call_from_params(params)
#      return Event.find_by_id(call.event_id) if call
      user = match_user_from_params(params)
      return nil unless user
      return pick_users_closest_event(user)
    end
    
    def match_call_from_params(params)
      unless params[:CallSid].blank?
        call = Call.find_by_Sid(params[:CallSid])
        return call if call
      end
      unless params[:PhoneNumberSid].blank?
        call = Call.where(:PhoneNumberSid => params[:PhoneNumberSid]).sort { |a,b| a.id <=> b.id }.last
        return call if call
      end
      return nil
    end
    # 
    # {
    #   "session"=>{
    #     "id"=>"cde357ff7d80d615ba65c421b4df6323", 
    #     "accountId"=>"69721", 
    #     "timestamp"=>2011-06-23 23:41:29 UTC, 
    #     "userType"=>"HUMAN", 
    #     "initialText"=>nil, 
    #     "callId"=>"fad6a6decb25ebee3bf508fb1c05813d", 
    #     "to"=>{
    #       "id"=>"4157660881", 
    #       "name"=>"+14157660881", 
    #       "channel"=>"VOICE", 
    #       "network"=>"SIP"}, 
    #     "from"=>{
    #       "id"=>"4153141222", 
    #       "name"=>"+14153141222", 
    #       "channel"=>"VOICE", 
    #       "network"=>"SIP"}, 
    #     "headers"=>{
    #       "x-sbc-from"=>
    #       "<sip:+14153141222@192.168.47.68;isup-oli=62>;tag=gK0d7bc0f5", 
    #       "x-voxeo-sbc-name"=>"10.6.63.201", 
    #       "x-sbc-contact"=>"<sip:+14153141222@192.168.47.68:5060>", 
    #       "Content-Length"=>"247", 
    #       "x-accountid"=>"2", 
    #       "To"=>"<sip:4157660881@10.6.61.201:5060>", 
    #       "x-voxeo-sbc"=>"true", 
    #       "Contact"=>"<sip:4153141222@10.6.63.201:5060>", 
    #       "x-sbc-remote-party-id"=>"<sip:+14153141222@192.168.47.68:5060>;privacy=off", 
    #       "x-voxeo-to"=>"<sip:+14157660881@67.231.4.93>", 
    #       "x-appid"=>"24601", 
    #       "x-sbc-request-uri"=>"sip:+14157660881@sip.tropo.com", 
    #       "x-sbc-call-id"=>"1426951374_36863491@192.168.47.68", 
    #       "x-sid"=>"07a0cb9e1609b68353684b1bfa2cff6a", 
    #       "x-sbc-cseq"=>"29996 INVITE", 
    #       "x-sbc-max-forwards"=>"53", 
    #       "x-voxeo-sbc-session-id"=>"07a0cb9e1609b68353684b1bfa2cff6a", 
    #       "CSeq"=>"2 INVITE", 
    #       "Via"=>"SIP/2.0/UDP 66.193.54.6:5060;received=10.6.63.201", 
    #       "x-sbc-record-route"=>"<sip:216.82.224.202;lr;ftag=gK0d7bc0f5>", 
    #       "Call-ID"=>"0-13c4-4e03cf28-1d5dd57d-7b1c-1d762270", 
    #       "Content-Type"=>"application/sdp", 
    #       "x-sbc-to"=>"<sip:+14157660881@67.231.4.93>", 
    #       "From"=>"<sip:4153141222@10.6.63.201:5060>;tag=0-13c4-4e03cf28-1d5dd57d-72d9"}
    #     }, 
    #     "controller"=>"tropo", 
    #     "action"=>"greeting", 
    #     "format"=>"json"}
    def match_user_from_params(params)
      # key = params[:Direction] == 'inbound' ? :From : :To
      key = 'from'
      return nil if !params['session'] or ! params['session'][key] or params['session'][key]['name'].blank?
      phone = Phone.find_by_number(params['session'][key]['name'])
      phone ? phone.user : nil
    end
    
    def pick_users_closest_event(user)
      user_time = Time.now.in_time_zone(user.time_zone)
      beg_of_day = user_time.beginning_of_day
      events = user.events.select { |e| e.next_occurrence(beg_of_day) }
      events = events.sort { |a,b| a.next_occurrence(beg_of_day) <=> b.next_occurrence(beg_of_day) }
      closest_event = events[0]
      events.each do |event|
        closest_event = event if event.next_occurrence(beg_of_day) < user_time + 10.minutes
      end
      closest_event
    end

    def build_intro_string(event_string)
      return '' if event_string.blank?
      users = event_string.split(/,/).map { |s| Event.find_by_id(s.to_i) }.select{ |e| e }.map { |e| intro_string_for_user(e.user) }
      last_user = users.pop
      users.empty? ? last_user : users.join(', ') + ", and " + last_user
    end

    def intro_string_for_user(user)
      return '' unless user
      string = user.phonetic_name
      string = string + " a " + user.title unless user.title.blank?
      string = string + " from " + user.location unless user.location.blank?
      string
    end
    
    def log_message(message)
      puts message if Rails.env.production?
    end

end
