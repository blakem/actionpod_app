class EventsController < ApplicationController
  before_filter :authenticate_user!
  
  # GET /events
  def index
    @events = Event.where(:user_id => current_user.id)
  end

  # GET /events/1
  def show
    @event = Event.where(:id => params[:id], :user_id => current_user.id )[0]
    redirect_to(root_path, :alert => "You don't have permissions to view that event.") unless @event
  end

  # GET /events/new
  def new
    @event = Event.new
  end

  # GET /events/1/edit
  def edit
    @event = Event.where(:id => params[:id], :user_id => current_user.id)[0]
    redirect_to(root_path, :alert => "You don't have permissions to view that event.") unless @event
  end

  # POST /events
  def create
    pool = Pool.find_by_name('Default Pool')
    event_params = params[:event].merge(:user_id => current_user.id, :pool_id => pool.id)
    @event = Event.new(event_params.merge(days_from_params(params)))
    @event.alter_schedule(:start_date => Time.now.in_time_zone(current_user.time_zone).beginning_of_day)

    if @event.save
      redirect_to(root_path, :notice => 'Event was successfully created.')
    else
      render :action => "new"
    end
  end

  # PUT /events/1
  def update
    @event = Event.where(:id => params[:id], :user_id => current_user.id)[0]
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
    @event = Event.where(:id => params[:id], :user_id => current_user.id)[0]
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
      
end
