class TwilioController < ApplicationController

  respond_to :html, :xml
  def greeting
    event = find_event_from_params(params)
    unless event
      update_call_status_from_params(params, 'greeting:nomatch')
      self.say_sorry
      render :action => :say_sorry
    else
      update_call_status_from_params(params, 'greeting:match')
      @event_name = event.name_in_second_person
      @postto = base_url + '/put_on_hold.xml'
    end
  end
  
  def greeting_fallback
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
    call.save
    update_call_object_status(call, 'completed')
  end

  def say_sorry
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
      update_call_status_from_params(params, 'direct:nomatch')
      self.say_sorry
      render :action => :say_sorry
    else
      update_call_status_from_params(params, 'direct:match')
      @event_name = event.name_in_second_person
      @timelimit = event.pool.timelimit
      @pool = event.pool
      @user = event.user
      @event = event
      @timelimit *= 60
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
      @timelimit = event.pool.timelimit
      @pool = event.pool 
      @event = event
      @user = event.user
      @timelimit *= 60
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
      @event_name = event.name_in_second_person
      @timelimit = event.pool.timelimit
      @pool = event.pool
      @user = event.user
      @event = event
      @timelimit *= 60
    end
  end

  def update_call_object_status(call, status)
    return unless call
    call.status = call.status.nil? ? status : call.status + "-#{status}"
    call.save
  end
  
  def update_call_status_from_params(params, status)
    call = Call.find_by_Sid(params[:CallSid])
    update_call_object_status(call, status)
  end
  
  def place_in_conference
    @names = build_intro_string(params[:events])
    @timelimit = params[:timelimit] ? params[:timelimit].to_i : 15 * 60
    @conference = params[:conference] || 'DefaultConference'
    update_call_status_from_params(params, "placed:#{@conference}")
    event = Event.find_by_id(params[:event])
    @next_call_time = event ? event.user.next_call_time_string : ''
  end
  
  def sms
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

  private
    def base_url 
      "http://www.15minutecalls.com/twilio"
    end
    
    def find_event_from_params(params)
      call = match_call_from_params(params)
      return Event.find_by_id(call.event_id) if call
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
    
    def match_user_from_params(params)
      key = params[:Direction] == 'inbound' ? :From : :To
      return nil if params[key].blank?
      phone = Phone.find_by_number(params[key])
      phone ? phone.user : nil
    end
    
    def pick_users_closest_event(user)
      user_time = Time.now.in_time_zone(user.time_zone)
      beg_of_day = user_time.beginning_of_day
      events = user.events.select { |e| e.schedule.next_occurrence(beg_of_day) }
      events = events.sort { |a,b| a.schedule.next_occurrence(beg_of_day) <=> b.schedule.next_occurrence(beg_of_day) }
      closest_event = events[0]
      events.each do |event|
        closest_event = event if event.schedule.next_occurrence(beg_of_day) < user_time + 10.minutes
      end
      closest_event
    end
end
