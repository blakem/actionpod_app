class PagesController < ApplicationController
  before_filter :authenticate_user!, :except => [:home, :help, :homepage]
  
  def home
    @title = 'Accountability Calls Made Easy'
    if user_signed_in?
      self.my_profile
      render :my_profile
    end
  end
  
  def homepage
    @title = 'Accountability Calls Made Easy'
    render :home
  end
  
  def my_profile
    @events = current_user.events.sort { |a,b| a.minute_of_day <=> b.minute_of_day }
    if current_user.admin?
      @conferences = Conference.order("id DESC").paginate(:page => params[:page], :per_page => 5)
    else
      user_ids = current_user.preferred_members.map(&:id) + [current_user.id]
      @conferences = Conference.order("id DESC").select{ |c| 
        c.users.select{ |u| user_ids.include?(u.id) }.any?
      }.paginate(:page => params[:page], :per_page => 5)
    end
    @timeslots = build_timeslots
    set_profile_values
    @view_options[:link_user_name] = true
    breadcrumbs.add current_user.name
  end
  
  def profile
    breadcrumbs.add 'Member Profile'
    @user = User.find_by_handle(params[:handle])
    if (@user)
      set_profile_values(@user)
      breadcrumbs.add @user.name
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
        :show_users_preferences => @user != current_user,
        :show_member_message => @user != current_user,
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
        redirect_to(other_user.profile_path, :notice => notice)
      end
    else
      redirect_to(root_path)
    end
  end
  
  def conference
    breadcrumbs.add 'View Conference'
    @conference = Conference.find_by_id(params[:id])
    if @conference
      @users = @conference.users.select { |u| u.id == current_user.id } +
               @conference.users.select { |u| u.id != current_user.id }
      set_profile_values
      @end_time = @conference.started_at + 16.minutes + 10.seconds
      @end_time = Time.now + 10.seconds if false
      @view_options.merge!({
        :show_conference_timer => @end_time > Time.now,
        :hide_tip_hr => @end_time > Time.now,
        :hide_view_current_conference => @conference == current_user.conferences.first,
        :show_users_preferences => @conference.users.count > 1 || @conference.users.first != current_user,
        :show_member_message => true,
      })
    else
      redirect_to(root_path, :alert => "There is no conference with that id")
    end
  end

  def plan    
    breadcrumbs.add 'Update Your Daily Goals'
    @plan = Plan.new(:body => Plan.default_body)
    current_plan = current_user.current_plan    
    @plan.body = current_plan.body if current_plan
    set_profile_values
    @view_options = {:hide_create_plan => true}
  end

  def plan_create
    @plan = Plan.new(params[:plan].merge(:user_id => current_user.id))
    if @plan.save
      redirect_to(current_user.profile_path, :notice => 'Your goals were successfully updated.')
    else
      set_profile_values
      @view_options = {:hide_create_plan => true}
      render :action => :plan
    end
  end
  
  def intro
    breadcrumbs.add 'Update Your Introduction'
    set_profile_values
    @view_options = {:hide_update_intro => true}    
  end

  def intro_update
    if current_user.update_attributes(params[:user])
      redirect_to(current_user.profile_path, :notice => 'Your introduction was successfully updated.')
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
  
  def call_groups
    set_profile_values
    @view_options = {:hide_call_groups => true}    
    @call_groups = build_call_groups(current_user, current_user)
    @my = current_user.admin? ? 'All' : 'My'
    @groups = @call_groups.length > 1 ? 'Groups' : 'Group'
    @groups = 'Groups' if current_user.admin?
    breadcrumbs.add "Who's in My Call " + @groups
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
      redirect_to(@user.profile_path, :notice => "Placing test call to: #{@user.primary_phone.number_pretty}")
    end
  end

  def send_member_message
    user = User.find_by_id(params[:member_id])
    body = params[:body]
    return_path = root_path
    if user && params[:conference_id] && Conference.find_by_id(params[:conference_id])
      return_path = {:controller => :pages, :action => :conference, :id => params[:conference_id]}
    elsif user
      return_path = user.profile_path
    end
    
    if user && !body.blank?
      UserMailer.deliver_member_message(user, current_user, body)
      MemberMessage.create(:sender_id => current_user.id, :to_id => user.id, :body => body)
      redirect_to(return_path, :notice => "Thank you.  Your message has been sent to #{user.name}.")
    elsif !user
      redirect_to(return_path, :alert => "Sorry, we couldn't find that member.")
    else
      redirect_to(return_path, :alert => "Please enter a message to send.")
    end
  end

  def calls
    return unless check_for_admin_user
    if params[:all] == "1"
      if params[:member_id]
        @calls = Call.order("id DESC").select{ |c| 
          event = Event.find_by_id(c.event_id)
          (event && (event.user_id == params[:member_id].to_i))
        }
      else
        @calls = Call.order("id DESC")
      end
    elsif params[:member_id]
      @calls = Call.order("id DESC").select{ |c| 
        event = Event.find_by_id(c.event_id)
        (event && (event.user_id == params[:member_id].to_i))
      }.paginate(:page => params[:page], :per_page => 20)
    else
      @calls = Call.order("id DESC").paginate(:page => params[:page], :per_page => 20)
    end
  end

  def emails
    return unless check_for_admin_user
    @emails = MemberMessage.order("id DESC").paginate(:page => params[:page], :per_page => 20)
  end

  def callcal
    return unless check_for_admin_user
    @scheduled_events = build_scheduled_events
    set_profile_values
    breadcrumbs.add 'Call Times'
  end

  def stranded_users
    return unless check_for_admin_user
    @users = User.all.sort_by(&:id).select { |u| u.events.empty? }
    set_profile_values
    @view_options = {:hide_stranded_users => true}    
    breadcrumbs.add 'Stranded Members'
  end
    
  def conference_email
    return unless check_for_admin_user
    set_profile_values
    conference = current_user.conferences.select { |c| c.users.count == 3 }.first
    render :inline => message = UserMailer.conference_email(current_user, conference.users).body.raw_source.html_safe, :layout => true
  end

  def next_steps_email
    return unless check_for_admin_user
    set_profile_values
    render :inline => message = UserMailer.member_next_steps(current_user).body.raw_source.html_safe, :layout => true
  end

  def confirmation_email
    return unless check_for_admin_user
    set_profile_values
    render :inline => Devise::Mailer.confirmation_instructions(current_user).body.raw_source.html_safe, :layout => true
  end
  
  def manage_groups
    breadcrumbs.add 'Manage Groups'
    @pools = current_user.pools
    set_profile_values
  end
  
  def remove_from_group
    user = User.find_by_id(params[:member_id])
    pool = Pool.find_by_id(params[:group_id])
    if user && pool && (current_user.id == user.id or current_user.id == pool.admin_id)
      if user.id == pool.admin_id
        redirect_to(invite_pool_path(pool), :alert => "You cannot remove yourself from this group.")
      else
        pool.users.delete(user)
        Event.where(:user_id => user.id, :pool_id => pool.id).map{ |e| e.destroy }
        if current_user.id == user.id
          redirect_to(:controller => :pages, :action => :manage_groups, :notice => "You have been removed from the group.")
        else
          redirect_to(invite_pool_path(pool), :notice => "#{user.name} was removed from the group.")
        end
      end
    else
      redirect_to(root_path, :alert => "You don't have access to that page")
    end
  end
  
  def invite_members
    pool = Pool.find_by_id(params[:group_id])
    if pool and pool.admin_id == current_user.id
      handle_invites(current_user, pool, params[:emails], params[:message])
      redirect_to(invite_pool_path(pool), :notice => "Invites have been sent.")
    else
      redirect_to(root_path, :alert => "You don't have access to that page")
    end
  end

  private
      def check_for_admin_user
        if admin_signed_in?
          return true
        else
          redirect_to(root_path, :alert => "You don't have access to that page")
          return false
        end
      end
      
      def handle_invites(sender, pool, emails, message)
        emails.split(/,\s*/).each do |email|
          user = User.find(:first, :conditions=>['LOWER(email) = ?', email.downcase])
          if user
            unless user.pools.include?(pool)
              user.pools << pool
              token = MemberInvite.generate_token
              mail = UserMailer.member_invite(user, current_user, message, pool, token)
              body = mail.body.raw_source
              mail.deliver
            else
              body = ''
            end
            MemberInvite.create(
              :sender_id => sender.id,
              :to_id => user.id,
              :pool_id => pool.id,
              :body => body,
              :invite_code => token,
            )
          end
        end
      end
      
      def create_invite_code
        'abc'
      end
end
