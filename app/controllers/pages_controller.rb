class PagesController < ApplicationController
  before_filter :authenticate_user!, :except => [:home, :help]
  
  def home
    @title = 'Accountability Calls You Can Count On'
    self.my_profile if user_signed_in?
  end
  
  def my_profile
    @events = current_user.events.sort { |a,b| a.minute_of_day <=> b.minute_of_day }
    @conferences = current_user.conferences
    @timeslots = build_timeslots
    set_profile_values
    render :my_profile, :layout => "sidebar"
  end
  
  def profile
    @user = User.find_by_handle(params[:handle])
    if (@user)
      @conferences = @user.conferences.select{ |c| c.started_at.strftime("%M") == "00"}
      @title = @user.name
      @nextcalls = build_nextcalls(@user)
      @your = @user.first_name + "'s"
      @youhave = @user.first_name + " has"
      @view_options = {:hide_view_profile => @user == current_user}
      render :layout => "sidebar"
    else
      redirect_to(root_path, :alert => "There is no handle by that name")
    end
  end

  def plan
    @plan = Plan.new
    current_plan = current_user.current_plan    
    @plan.body = current_plan.body if current_plan
    set_profile_values
    @view_options = {:hide_create_plan => true}
    render :layout => "sidebar"
  end

  def plan_create
    @plan = Plan.new(params[:plan].merge(:user_id => current_user.id))
    if @plan.save
      redirect_to('/u/' + current_user.handle, :notice => 'Your plan was successfully updated.')
    else
      set_profile_values
      @view_options = {:hide_create_plan => true}
      render :action => :plan
    end
  end
  
  def intro
    set_profile_values
    @view_options = {:hide_update_intro => true}    
    render :layout => "sidebar"
  end

  def intro_update
    if current_user.update_attributes(params[:user])
      redirect_to('/u/' + current_user.handle, :notice => 'Your introduction was successfully updated.')
    else
      render :action => :intro
    end
  end

  def set_profile_values
    @user = current_user
    @title = @user.name
    @nextcalls = build_nextcalls(@user)
    @your = 'Your'
    @youhave = 'You have'
    @view_options = {}
  end

  def join
    event = Event.create(:user_id => current_user.id, :pool_id => Pool.default_pool.id, :time => params[:time])
    run_at_date = event.schedule.next_occurrence.strftime("%A at %l:%M%p").sub(/AM/,'am').sub(/PM/,'pm')
    redirect_to('/pages/call_groups', :notice => "Great! We'll call you on #{run_at_date}, " + 
                                                 "along with these other people. ;-)")
  end

  def help
    @title = 'Guide'
    render :action => :help_logged_in if user_signed_in?
  end
  
  def callcal
    @scheduled_events = build_scheduled_events
    set_profile_values
    @view_options = {:hide_callcal => true}    
    render :layout => "sidebar"
  end
  
  def call_groups
    set_profile_values
    @view_options = {:hide_call_groups => true}    
    @call_groups = build_call_groups(current_user)
    render :layout => "sidebar"
  end
  
  private
    def build_nextcalls(user)
      calls = []
      start_time = Time.now
      end_time = start_time + 7.days
      user.events.each do |event|
        event.schedule.occurrences_between(start_time, end_time).each do |occurrence|
          calls.push(occurrence.in_time_zone(current_user.time_zone))
        end
      end
      calls = calls.sort{ |a,b| a <=> b }.map { |c| c.strftime("%l:%M%p on %A").sub(/AM/,'am').sub(/PM/,'pm') }
      calls[0..4]
    end

    def build_timeslots
      slots = []
      build_scheduled_events.each do |occurrence|
        slot = occurrence[0].strftime('%l:%M%p').downcase.strip
        slots.push(slot) unless slots.include?(slot)
      end
      current_user.events.each do |event|
        slots.delete(event.time.downcase.strip)
      end
      slots.map{ |s| {:time => s, :string => "#{s} on Weekdays"} }
    end
    
    def build_scheduled_events
      hash = {}
      start_time = Time.now.beginning_of_week + 6.days
      end_time = start_time + 7.days
      Event.all.each do |event|
        next unless (event.minute_of_hour == 0 or current_user.admin?)
        event.schedule.occurrences_between(start_time, end_time).each do |occurrence|
          occurrence = occurrence.in_time_zone(current_user.time_zone)
          hash[occurrence] ||= 0
          hash[occurrence] += 1
        end
      end
      hash.each.sort
    end
    
    def build_call_groups(user)
      call_groups = {}
      my_calls = {}
      Event.all.each do |event|
        occurrence = event.schedule.next_occurrence
        next unless occurrence
        occurrence = occurrence.in_time_zone(user.time_zone)
        time = occurrence.strftime('%l:%M%p').downcase.strip
        call_groups[time] ||= {
          :time => time,
          :events => []
        }
        call_groups[time][:events].push [event.id, event.user_id]
        my_calls[time] = true if event.user_id == user.id
      end
      call_groups.select{ |k,v| my_calls[k]}.sort{ |a,b| a[0] <=> b[0] }.map{ |cg| {
        :time => cg[0], 
        :events => cg[1][:events].sort { |a,b| a[1] <=> b[1] } 
      }}
    end
end
