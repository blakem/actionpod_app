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
    if current_user.admin?
      @conferences = Conference.order("id DESC").paginate(:page => params[:page], :per_page => 5)
    else
      @conferences = current_user.conferences.paginate(:page => params[:page], :per_page => 5)
    end
    @timeslots = build_timeslots
    set_profile_values
  end
  
  def profile
    @user = User.find_by_handle(params[:handle])
    if (@user)
      set_profile_values(@user)
      @conferences = @user.conferences.select{ |c| c.started_at.min == 0 }.paginate(:page => params[:page], :per_page => 5)
      @users = [@user]
      @your = @user.first_name + "'s"
      @youhave = @user.first_name + " has"
      if (@user != current_user)
        @my = @your
        if current_user.prefers?(@user)
          @slider_value = 3
        elsif current_user.avoids?(@user)
          @slider_value = 1
        else
          @slider_value = 2
        end
      end
      @view_options = {
        :hide_view_profile => @user == current_user,
        :show_users_preferences => @user != current_user,
      }
    else
      redirect_to(root_path, :alert => "There is no handle by that name")
    end
  end
  
  def prefer
    other_user = User.find_by_id(params[:other_user_id])
    prefer = params[:prefer]
    if (other_user)
      if prefer == '1'
        current_user.avoid!(other_user)    
        notice = "We will try to place you on fewer calls with #{other_user.first_name}."
      end
      if prefer == '2'
        current_user.unprefer!(other_user) 
        notice = "You will be placed with #{other_user.first_name} according to the standard algorithm."
      end
      if prefer == '3'
        current_user.prefer!(other_user)   
        notice = "We will try to place you on more calls with #{other_user.first_name}."
      end
      notice ||= "We couldn't understand that preference setting"
      if params[:conference]
        flash[:notice] = notice
        redirect_to(:controller => :pages, :action => :conference, :id => params[:conference])
      else
        redirect_to('/u/' + other_user.handle, :notice => notice)
      end
    else
      redirect_to(root_path)
    end
  end
  
  def conference
    @conference = Conference.find_by_id(params[:id])
    if @conference
      @users = @conference.users.select { |u| u.id == current_user.id } +
               @conference.users.select { |u| u.id != current_user.id }
      set_profile_values
      @view_options = {
        :hide_view_current_conference => @conference == current_user.conferences.first,
        :show_users_preferences => @conference.users.count > 1 || @conference.users.first != current_user,
      }
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
      redirect_no_access
    end
  end
  
  def call_groups
    set_profile_values
    @view_options = {:hide_call_groups => true}    
    @call_groups = build_call_groups(current_user, current_user)
    @my = current_user.admin? ? 'All' : 'My'
    @groups = @call_groups.length > 1 ? 'Groups' : 'Group'
    @groups = 'Groups' if current_user.admin?
  end

  def time_slot
    set_profile_values
    @call_group = build_call_groups(current_user).select{ |cg| cg[:time] == params[:time] }[0]
    redirect_to(root_path, :alert => "There is no call at that time.") unless @call_group
  end
  
  def place_test_call
    @user = current_user
    if params[:user_id] && current_user.admin?
      @user = User.find_by_id(params[:user_id])
    end
    unless @user
      redirect_to(root_path, :alert => "Couldn't find user.")
    else
      tc = TwilioCaller.new
      tc.start_call_for_user(@user, {
        'Url' => tc.base_url + '/place_test_call.xml',
      })
      redirect_to('/u/' + @user.handle, :notice => "Placing test call to: #{@user.primary_phone.number_pretty}")
    end
  end
  
  def conference_email
    if admin_signed_in?
      set_profile_values
      conference = current_user.conferences.select { |c| c.users.count == 3 }.first
      render :inline => message = UserMailer.conference_email(current_user, conference.users).body.raw_source.html_safe, :layout => true
    else
      redirect_no_access
    end
  end

  def confirmation_email
    if admin_signed_in?
      set_profile_values
      render :inline => Devise::Mailer.confirmation_instructions(current_user).body.raw_source.html_safe, :layout => true
    else
      redirect_no_access
    end
  end

  private
      def redirect_no_access
        redirect_to(root_path, :alert => "You don't have access to that page")      
      end
end
