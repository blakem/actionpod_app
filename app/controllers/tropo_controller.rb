class TropoController < ApplicationController

  respond_to :json

  def tropo
    tg = TropoCaller.tropo_generator
    event = find_event_from_params(params)
    if event
      call_session = CallSession.create(
        :event_id => event.id,
        :user_id => event.user_id,
        :pool_id => event.pool_id,
        :session_id => params[:session]['id'],
      )
      call = Call.create(
        :event_id => event.id,
        :user_id => event.user.id,
      )
      call_id = params[:session]['callId'] 
      if call_id # incoming
        tg.say :value => "Welcome to your #{event.name_in_second_person}."
        tg.on :event => 'continue', :next => "/tropo/put_on_hold.json?event_id=#{event.id}"
        call_session.direction = 'inbound'
        call_session.call_state = 'inbound'
        call_session.call_id = call_id
        call.Direction = 'inbound'
        call.Sid = call_id
        call.DateCreated = params[:session][:timestamp]
        call.DateUpdated = params[:session][:timestamp]
        call.To = params[:session][:to][:name]
        call.From = params[:session][:from][:name]
        call.AnsweredBy = params[:session][:userType]
      else # outgoing
        tg.on :event => 'continue', :next => URI.encode("/tropo/greeting?event_id=#{event.id}")
        tg.call(
          :to => event.user.primary_phone.number,
          :from => TropoCaller.new.phone_number
        )
        call_session.direction = 'outbound'
        call_session.call_state = 'calling'
        call.Direction = 'outbound'
      end
      call_session.save
      call.save
    end
    render :json => tg
  end

  def sms

  end

  def greeting
    event = find_event_from_params(params)
    tg = TropoCaller.tropo_generator
    unless event
      #   update_call_status_from_params(params, 'greeting:nomatch')
      tg.say "I'm sorry I can't match this number up with a scheduled event. Goodbye."
    else
      #   update_call_status_from_params(params, 'greeting:match')
      update_call_session('waiting_for_input')
      tg.on :event => 'continue', :next => "/tropo/put_on_hold.json?event_id=#{event.id}"
      tg.on :event => 'incomplete', :next => '/tropo/no_keypress.json'
      tg.ask({ :name    => 'signin', 
               :bargein => true, 
               :timeout => 8,
               :required => 'true' }) do
                 say     :value => "Welcome to your #{event.name_in_second_person}. Press 1 to join the conference."
                 choices :value => '[1 DIGIT]', :mode => 'dtmf'
               end
      log_message("GREETING for #{event.user.name}")
    end
    render :json => tg
  end

  def no_keypress
    tg = TropoCaller.tropo_generator
    tg.say :value => "Sorry, We didn't receive any input. Call this number back to join the conference."
    render :json => tg
  end
  
  def put_on_hold
    event = find_event_from_params(params)
    update_call_session('on_hold')
    tg = TropoCaller.tropo_generator
    tg.say :value => 'Waiting for the other participants.'
    tg.say :value => 'http://hosting.tropo.com/69721/www/audio/jazz_planet.mp3'
    tg.say :value => 'http://hosting.tropo.com/69721/www/audio/jazz_planet.mp3'
    tg.say :value => 'http://hosting.tropo.com/69721/www/audio/jazz_planet.mp3'
    tg.on :event => 'placed', :next => "/tropo/place_in_conference.json"
    render :json => tg
  end
  
  def place_in_conference
    event = find_event_from_params(params)
    call_session = update_call_session('placed')
    tg = TropoCaller.tropo_generator
    tg.say :value => 'Welcome.  On the call today we have ' + build_intro_string(call_session.event_ids)
    tg.conference(conference_params(call_session))
    tg.on :event => 'onemin', :next => "/tropo/one_minute_warning.json"
    render :json => tg
  end

  def one_minute_warning
    event = find_event_from_params(params)
    call_session = update_call_session('lastminute')
    tg = TropoCaller.tropo_generator
    tg.say :value => 'One minute remaining.'
    tg.conference(conference_params(call_session))
    tg.on :event => 'awesome', :next => "/tropo/awesome_day.json"
    render :json => tg
  end

  def awesome_day
    event = find_event_from_params(params)
    update_call_session('complete')
    next_call_time = event.user.next_call_time_string
    next_call_time = "Your next call is #{next_call_time}. " unless next_call_time.blank?
    tg = TropoCaller.tropo_generator
    tg.say :value => "Time is up. #{next_call_time}Have an Awesome day!"
    render :json => tg
  end

  def callback
    call_session = find_call_session_from_params(params)
    call_session.destroy if call_session
    update_call_status_from_params(params, 'callback-completed', 
      :Duration => find_duration_from_params(params),
    )
    render :inline => ''
  end

  private

    def conference_params(call_session)
      {
        :id => call_session.conference_name, 
        :playTones => true, 
        :terminator => '#',
        :name => call_session.conference_name + '_name',
      }
    end
  
    def update_call_session(new_state)
      call_session = find_call_session_from_params(params)
      call_session.call_state = new_state
      call_session.save
      call_session
    end  

    def say_sorry(tg)
      tg.say "I'm sorry I can't match this number up with a scheduled event. Goodbye."
    end
    
    def find_call_session_from_params(params)
      session_id = find_session_id_from_params(params)
      session_id ? CallSession.find_by_session_id(session_id) : nil
    end

    def find_session_id_from_params(params)
      find_result_key_from_params(:sessionId, params)
    end

    def find_duration_from_params(params)
      find_result_key_from_params(:sessionDuration, params)
    end

    def find_result_key_from_params(key, params)
      params[:result] ? params[:result][key] : nil
    end

    def find_event_from_params(params)
      if params['event_id']
        event = Event.find_by_id(params['event_id'])
      elsif params['session'] && params['session']['parameters']
        if params['session']['parameters']['event_id']
          event = Event.find_by_id(params['session']['parameters']['event_id'])
        end
      end
      return event if event
      session = find_call_session_from_params(params)
      if session
        event = Event.find_by_id(session.event_id)
      end
      return event if event
#      call = match_call_from_params(params)
#      return Event.find_by_id(call.event_id) if call
      if event
        event
      else
        user = match_user_from_params(params)
        return nil unless user
        return pick_users_closest_event(user)
      end
    end

    # def update_answered_count(user)
    #   user.answered_count += 1
    #   user.made_in_a_row += 1
    #   user.missed_in_a_row = 0
    #   user.save
    # end
    # 
    # def update_missed_count(user)
    #   user.missed_in_a_row += 1
    #   user.made_in_a_row = 0
    #   user.save
    # end
    # 
    # def update_incoming_count(user)
    #   user.incoming_count += 1
    #   user.save
    # end
    # 

    def update_call_object_status(call, status, args = {})
      return unless call
      call.status = call.status.nil? ? status : call.status + "-#{status}"
      call.update_attributes(args) unless args.empty?      
      call.save
    end
    
    def update_call_status_from_params(params, status, args = {})
      call = Call.find_by_Sid(find_session_id_from_params(params))
      update_call_object_status(call, status, args)
      call
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
