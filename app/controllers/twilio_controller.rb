class TwilioController < ApplicationController

  respond_to :html, :xml
  def greeting
    event = find_event_from_params(params)
    unless event
      self.say_sorry
      render :action => :say_sorry
    else
      @event_name = event.name
      @postto = base_url + '/put_on_hold.xml'
    end
  end
  
  def greeting_fallback
    event = find_event_from_params(params)
    unless event
      self.say_sorry
      render :action => :say_sorry
    else
      self.put_on_hold
      render :action => :put_on_hold
    end
  end
  
  def callback
    call = Call.find_by_Sid(params[:CallSid])
    call.Duration = params[:CallDuration]
    call.save
  end

  def say_sorry
  end

  def apologize_no_other_participants
    @other_participants = params[:participant_count] - 1
    @people = @other_participants == 1 ? 'person' : 'people' 
  end

  def go_directly_to_conference
    event = find_event_from_params(params)
    unless event
      self.say_sorry
      render :action => :say_sorry
    else
      @event_name = event.name
      @timelimit = event.pool.timelimit
      @pool = event.pool 
      @event = event
      @timelimit *= 60
    end
  end

  def put_on_hold
    event = find_event_from_params(params)
    unless event
      self.say_sorry
      render :action => :say_sorry
    else
      @timelimit = event.pool.timelimit
      @pool = event.pool 
      @event = event
      @timelimit *= 60
    end
  end

  def incoming
    event = find_event_from_params(params)
    unless event
      self.say_sorry
      render :action => :say_sorry
    else
      TwilioCaller.create_call_from_call_hash(params.merge(:Sid => params[:CallSid]), event.id)
      @event_name = event.name
      @postto = base_url + '/put_on_hold.xml'
    end
  end
  
  def place_in_conference
    @names = build_intro_string(params[:events])
    @timelimit = (params[:timelimit] || 15) * 60
    @conference = params[:conference] || 'DefaultConference'
  end
  
  def sms
  end

  def build_intro_string(event_string)
    return '' if event_string.blank?
    event_ids = event_string.split(/,/).map { |s| s.to_i }
    users = event_ids.map { |id| Event.find(id).user }.map { |u| intro_string_for_user(u) }
    last_user = users.pop    
    @names = users.join(', ') + ", and " + last_user
  end

  def intro_string_for_user(user)
    return '' unless user
    string = user.name
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
      User.find_by_primary_phone(params[key])
    end
    
    def pick_users_closest_event(user)
      user_time = Time.now.in_time_zone(user.time_zone)
      beg_of_day = user_time.beginning_of_day
      events = user.events.sort { |a,b| a.schedule.next_occurrence(beg_of_day) <=> b.schedule.next_occurrence(beg_of_day) }
      closest_event = events[0]
      events.each do |event|
        closest_event = event if event.schedule.next_occurrence(beg_of_day) < user_time + 10.minutes
      end
      closest_event
    end
end
