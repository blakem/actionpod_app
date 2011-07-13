class TropoController < ApplicationController

  respond_to :json

  def tropo
    tg = TropoCaller.tropo_generator
    if user_id = find_parameters_key(:user_id) # place_test_call
      call_session = CallSession.create(
        :user_id => user_id,
        :session_id => params[:session][:id],
      )
      user = User.find_by_id(user_id)
      tg.on :event => 'continue', :next => "/tropo/test_call.json"
      tg.on :event => 'incomplete', :next => '/tropo/test_call_nokeypress.json'
      tg.call(
        :to => user.primary_phone.number,
        :from => TropoCaller.new.phone_number,
      )
      log_message("TESTCALL for #{user.name}")
    elsif event = find_event
      call_session = CallSession.create(
        :event_id => event.id,
        :user_id => event.user_id,
        :pool_id => event.pool_id,
        :session_id => params[:session][:id],
      )
      call = Call.create(
        :event_id => event.id,
        :user_id => event.user.id,
        :session_id => params[:session][:id]
      )
      if call_id = find_call_id # incoming
        tg.say :value => "Welcome to your #{event.name_in_second_person}."
        tg.on :event => 'continue', :next => "/tropo/put_on_hold.json"
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
        call.status = 'inbound'
        update_incoming_count(event.user)
        log_message("INCOMING for #{event.user.name}")
      else # outgoing
        tg.on :event => 'continue', :next => URI.encode("/tropo/greeting.json")
        number_to = event.user.primary_phone.number
        number_from = TropoCaller.new.phone_number 
        tg.call(
          :to => number_to,
          :from => number_from,
        )
        call_session.direction = 'outbound'
        call_session.call_state = 'calling'
        call.Direction = 'outbound'
        call.status = 'outgoing'
        call.To = number_to
        call.From = number_from
        call.DateCreated = Time.now
        call.DateUpdated = Time.now
      end
      call_session.save
      call.save
    end
    render :json => tg
  end

  def sms

  end

  def greeting
    event, call_session, call = process_request('greeting', 'waiting_for_input')
    call.Sid = find_call_id
    call.save
    tg = TropoCaller.tropo_generator
    tg.on :event => 'continue', :next => "/tropo/put_on_hold.json"
    tg.on :event => 'incomplete', :next => '/tropo/no_keypress.json'
    tg.ask({ :name    => 'signin', 
             :bargein => true, 
             :timeout => 8,
             :required => 'true' }) do
               say     :value => "Welcome to your #{event.name_in_second_person}. Press 1 to join the conference."
               choices :value => '[1 DIGIT]', :mode => 'dtmf'
             end
    log_message("GREETING for #{event.user.name}")
    render :json => tg
  end
  
  def test_call
    tg = TropoCaller.tropo_generator
    tg.on :event => 'continue', :next => "/tropo/test_call_thanks.json"
    tg.on :event => 'incomplete', :next => '/tropo/test_call_nokeypress.json'
    tg.ask({ :name    => 'signin', 
             :bargein => true, 
             :timeout => 8,
             :required => 'true' }) do
               say     :value => "Welcome. Please press 1 on your handset."
               choices :value => '[1 DIGIT]', :mode => 'dtmf'
             end
  end

  def no_keypress
    process_request('nokeypress')
    tg = TropoCaller.tropo_generator
    tg.say :value => "Sorry, We didn't receive any input. Call this number back to join the conference."
    render :json => tg
  end
  
  def put_on_hold
    event, call_session = process_request('onhold')
    update_answered_count(event.user)
    tg = TropoCaller.tropo_generator
    tg.on :event => 'continue', :next => "/tropo/put_on_hold.json"
    tg.on :event => 'placed', :next => "/tropo/place_in_conference.json"
    tg.on :event => 'apologize', :next => "/tropo/apologize_no_other_participants.json"
    tg.say :value => 'Waiting for the other participants.'
    tg.say :value => 'http://hosting.tropo.com/69721/www/audio/jazz_planet.mp3'
    render :json => tg
  end
  
  def place_in_conference
    event, call_session = process_request
    update_call_session('placed')
    update_call_status("placed:#{call_session.conference_name}")
    tg = TropoCaller.tropo_generator
    tg.say :value => 'Welcome.  On the call today we have ' + build_intro_string(call_session.event_ids)
    tg.conference(conference_params(call_session))
    tg.on :event => 'onemin', :next => "/tropo/one_minute_warning.json"
    render :json => tg
  end

  def one_minute_warning
    event, call_session = process_request('lastminute')
    tg = TropoCaller.tropo_generator
    tg.say :value => 'One minute remaining.'
    tg.conference(conference_params(call_session))
    tg.on :event => 'awesome', :next => "/tropo/awesome_day.json"
    render :json => tg
  end

  def awesome_day
    event, call_session, call = process_request('awesome', 'complete')
    next_call_time = event.user.next_call_time_string
    next_call_time = "Your next call is #{next_call_time}. " unless next_call_time.blank?
    tg = TropoCaller.tropo_generator
    tg.say :value => "Time is up. #{next_call_time}Have an Awesome day!"
    render :json => tg
  end

  def callback
    event, call_session, call = process_request('callback')
    call_session.destroy if call_session
    if call && call.Direction == 'outbound'
      update_missed_count(event.user) unless call.status =~ /-onhold/
    end
    render :inline => ''
  end
  
  def apologize_no_other_participants
    event, call_session = process_request('apologized', 'onhold')
    tg = TropoCaller.tropo_generator
    tg.on :event => 'continue', :next => "/tropo/put_on_hold.json"
    count = call_session.participant_count - 1
    people = count == 1 ? 'person' : 'people'
    next_call_time = event ? event.user.next_call_time_string : ''
    tg.say :value => "I'm sorry. I called #{count} other #{people} but they didn't answer."
    tg.say :value => "You may stay on the line, for one of them to call in. Or wait for your next call, #{next_call_time}."
    render :json => tg
  end  

  private
    def process_request(call_status = nil, call_session_status = nil)
      call_session_status ||= call_status

      event = find_event
      call_session = find_call_session
      call = find_call
      
      if call_session
        update_call_session(call_session_status) if call_session_status
      end
      if call
        update_call_status(call_status) if call_status
        call.Duration = find_duration
        call.save
      end

      [event, call_session, call]
    end

    def conference_params(call_session)
      {
        :id => call_session.conference_name, 
        :playTones => true, 
        :terminator => '#',
        :name => call_session.conference_name + '_name',
      }
    end
  
    def update_call_session(new_state, call_session = nil)
      call_session ||= find_call_session
      call_session.call_state = new_state
      call_session.save
      call_session
    end  

    def say_sorry(tg)
      tg.say "I'm sorry I can't match this number up with a scheduled event. Goodbye."
    end
    
    def find_call_session
      session_id = find_session_id
      session_id ? CallSession.find_by_session_id(session_id) : nil
    end

    def find_call
      Call.find_by_session_id(find_session_id)
    end

    def find_session_id
      find_result_key(:sessionId) ||
        find_session_key(:id)
    end
    
    def find_call_id
      find_result_key(:callId) ||
        find_session_key(:callId)
    end
      
    def find_duration
      find_result_key(:sessionDuration)
    end

    def find_result_key(key)
      params[:result] ? params[:result][key] : nil
    end

    def find_session_key(key)
      params[:session] ? params[:session][key] : nil
    end

    def find_parameters_key(key)
      parameters = find_session_key(:parameters)
      parameters ? parameters[key] : nil
    end

    def find_event
      if event_id = find_parameters_key(:event_id)
        event = Event.find_by_id(event_id)
        return event if event
      end

      if session = find_call_session
        event = Event.find_by_id(session.event_id)
        return event if event
      end

      pick_users_closest_event
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
    
    def update_call_status(status, args = {})
      call = find_call
      update_call_object_status(call, status, args)
    end
    
    def pick_users_closest_event
      from = find_session_key(:from)
      if from && !from[:name].blank?
        phone = Phone.find_by_number(from[:name])
      end
      return nil unless phone

      user = phone.user
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
