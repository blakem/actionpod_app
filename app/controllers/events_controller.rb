class EventsController < ApplicationController
  before_filter :authenticate_user!
  
  # GET /events
  def index
    @events = Event.where(:user_id => current_user.id)
  end

  # GET /events/1
  def show
    @event = Event.where(:id => params[:id], :user_id => current_user.id )[0]
    redirect_to(root_path, :notice => "You don't have permissions to view that event.") unless @event
  end

  # GET /events/new
  def new
    @event = Event.new
  end

  # GET /events/1/edit
  def edit
    @event = Event.where(:id => params[:id], :user_id => current_user.id)[0]
    redirect_to(root_path, :notice => "You don't have permissions to view that event.") unless @event
  end

  # POST /events
  def create
    @event = Event.new(params[:event].merge(:user_id => current_user.id))

    if @event.save
      redirect_to(@event, :notice => 'Event was successfully created.')
    else
      render :action => "new"
    end
  end

  # PUT /events/1
  def update
    @event = Event.where(:id => params[:id], :user_id => current_user.id)[0]
    if @event
      if @event.update_attributes(params[:event])
        redirect_to(@event, :notice => 'Event was successfully updated.')
      else
        render :action => "edit"
      end
    else
      redirect_to(root_path, :notice => "You don't have permissions to view that event.")
    end
  end

  # DELETE /events/1
  def destroy
    @event = Event.where(:id => params[:id], :user_id => current_user.id)[0]
    if @event
      @event.destroy
      redirect_to(events_url)
    else
      redirect_to(root_path, :notice => "You don't have permissions to view that event.")
    end
  end
end
