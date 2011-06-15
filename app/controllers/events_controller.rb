class EventsController < ApplicationController
  before_filter :authenticate_user!
  
  # GET /events
  def index
    @events = Event.where(:user_id => current_user.id)
  end

  # GET /events/1
  def show
    @event = event_from_params
    redirect_to(root_path, :alert => "You don't have permissions to view that event.") unless @event
  end

  # GET /events/new
  def new
    @group = group_from_params
    if @group
      @event = Event.new(:pool_id => @group.id)
    else
      redirect_to(root_path, :alert => "You don't have permissions to create that event.")
    end
  end

  # GET /events/1/edit
  def edit
    @event = event_from_params
    redirect_to(root_path, :alert => "You don't have permissions to view that event.") unless @event
  end

  # POST /events
  def create
    pool = group_from_params(params[:event][:pool_id])
    if pool
      event_params = params[:event].merge(:user_id => current_user.id)
      @event = Event.new(event_params.merge(days_from_params(params)))
      @event.alter_schedule(:start_date => Time.now.in_time_zone(current_user.time_zone).beginning_of_day)
      if @event.save
        redirect_to(root_path, :notice => 'Event was successfully created.')
      else
        render :action => "new"
      end
    else
      redirect_to(root_path, :alert => "You don't have permissions to create that event.")
    end
  end

  # PUT /events/1
  def update
    @event = event_from_params
    if @event
      event_params = params[:event] || {}
      if event_params[:time] != @event.time and event_params[:name] == @event.name
        event_params[:name].sub!(/\d+(:\d{2})?(am|pm)/i, event_params[:time])
      end
      if @event.update_attributes(event_params.merge(days_from_params(params)))
        redirect_to(root_path, :notice => 'Event was successfully updated.')
      else
        render :action => "edit"
      end
    else
      redirect_to(root_path, :alert => "You don't have permissions to view that event.")
    end
  end

  # DELETE /events/1
  def destroy
    @event = event_from_params
    if @event
      @event.destroy
      redirect_to(root_path, :notice => 'Event was successfully deleted.')
    else
      redirect_to(root_path, :alert => "You don't have permissions to view that event.")
    end
  end
  
  private
    def days_from_params(params)
      day_list = params.map { |k,v| k =~ /^on_(sun|mon|tue|wed|thr|fri|sat)$/ ? v.to_i : nil }.select { |v| v }
      return {:days => day_list}
    end
    
    def group_from_params(group_id = params[:group_id])
      group = Pool.find_by_id(group_id)
      if group && current_user.pools.include?(group)
        group
      else
        nil
      end                
    end
    
    def event_from_params
      Event.where(:id => params[:id], :user_id => current_user.id).first
    end
end
