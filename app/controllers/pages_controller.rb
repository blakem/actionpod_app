class PagesController < ApplicationController
  before_filter :authenticate_user!, :except => [:home, :help, :homepage]
  
  def home
    @title = 'Accountability Calls You Can Count On'
    if user_signed_in?
      self.my_profile
      render :my_profile
    end
  end
  
  def homepage
    @title = 'Accountability Calls You Can Count On'
    render :home
  end
  
  def my_profile
    @events = current_user.events.sort { |a,b| a.minute_of_day <=> b.minute_of_day }
    @conferences = current_user.conferences.paginate(:page => params[:page], :per_page => 5)
    @timeslots = build_timeslots
    set_profile_values
  end
  
  def profile
    @user = User.find_by_handle(params[:handle])
    if (@user)
      set_profile_values(@user)
      @conferences = @user.conferences.select{ |c| c.started_at.min == 0 }.paginate(:page => params[:page], :per_page => 5)
      @your = @user.first_name + "'s"
      @youhave = @user.first_name + " has"
      if (@user != current_user)
        @my = @your
      end
      @view_options = {
        :hide_view_profile => @user == current_user,
        :show_user_preferences => @user != current_user,
      }
    else
      redirect_to(root_path, :alert => "There is no handle by that name")
    end
  end
  
  def conference
    @conference = Conference.find_by_id(params[:id])
    if @conference
      @users = @conference.users.select { |u| u.id == current_user.id } +
               @conference.users.select { |u| u.id != current_user.id }
      set_profile_values
      @view_options = {:hide_view_current_conference => @conference == current_user.conferences.first}
    else
      redirect_to(root_path, :alert => "There is no conference with that id")
    end
  end

  def plan    
    @plan = Plan.new(:body => Plan.default_body)
    current_plan = current_user.current_plan    
    @plan.body = current_plan.body if current_plan
    set_profile_values
    @view_options = {:hide_create_plan => true}
  end

  def plan_create
    @plan = Plan.new(params[:plan].merge(:user_id => current_user.id))
    if @plan.save
      redirect_to('/u/' + current_user.handle, :notice => 'Your goals were successfully updated.')
    else
      set_profile_values
      @view_options = {:hide_create_plan => true}
      render :action => :plan
    end
  end
  
  def intro
    set_profile_values
    @view_options = {:hide_update_intro => true}    
  end

  def intro_update
    if current_user.update_attributes(params[:user])
      redirect_to('/u/' + current_user.handle, :notice => 'Your introduction was successfully updated.')
    else
      render :action => :intro
    end
  end

  def join
    event = Event.create(:user_id => current_user.id, :pool_id => Pool.default_pool.id, :time => params[:time])
    run_at_date = event.next_occurrence.strftime("%A at %l:%M%p").sub(/AM/,'am').sub(/PM/,'pm')
    redirect_to('/pages/call_groups', :notice => "Great! We'll call you on #{run_at_date}, " + 
                                                 "along with these other people. ;-)")
  end

  def help
    @title = 'Guide'
    render :action => :help_logged_in if user_signed_in?
  end
  
  def callcal
    if admin_signed_in?
      @scheduled_events = build_scheduled_events
      set_profile_values
      @view_options = {:hide_callcal => true}    
    else
      redirect_to(root_path, :alert => "You don't have access to that page")
    end
  end

  def stranded_users
    if admin_signed_in?
      @users = User.all.sort_by(&:id).select { |u| u.events.empty? }
      set_profile_values
      @view_options = {:hide_stranded_users => true}    
    else
      redirect_to(root_path, :alert => "You don't have access to that page")
    end
  end
  
  def call_groups
    set_profile_values
    @view_options = {:hide_call_groups => true}    
    @call_groups = build_call_groups(current_user, current_user)
  end

  def time_slot
    set_profile_values
    @call_group = build_call_groups(current_user).select{ |cg| cg[:time] == params[:time] }[0]
    redirect_to(root_path, :alert => "There is no call at that time.") unless @call_group
  end
end
