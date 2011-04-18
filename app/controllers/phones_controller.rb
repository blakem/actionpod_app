class PhonesController < ApplicationController
  before_filter :authenticate_user!
  
  # GET /phones
  def index
    @phones = Phone.where(:user_id => current_user.id)
  end

  # GET /phones/1
  def show
    @phone = Phone.where(:id => params[:id], :user_id => current_user.id )[0]
    redirect_to(root_path, :notice => "You don't have permissions to view that phone.") unless @phone
  end

  # GET /phones/new
  def new
    @phone = Phone.new
  end

  # GET /phones/1/edit
  def edit
    @phone = Phone.where(:id => params[:id], :user_id => current_user.id)[0]
    redirect_to(root_path, :notice => "You don't have permissions to view that phone.") unless @phone
  end

  # POST /phones
  def create
    @phone = Phone.new(params[:phone].merge(:user_id => current_user.id))
    if @phone.save
      redirect_to(@phone, :notice => 'Phone was successfully created.')
    else
      render :action => "new"
    end
  end

  # PUT /phones/1
  def update
    @phone = Phone.where(:id => params[:id], :user_id => current_user.id)[0]

    if @phone
      if @phone.update_attributes(params[:phone])
        redirect_to(root_path, :notice => 'Phone was successfully updated.')
      else
        render :action => "edit"
      end
    else
      redirect_to(root_path, :notice => "You don't have permissions to view that phone.")
    end
  end

  # DELETE /phones/1
  def destroy
    @phone = Phone.where(:id => params[:id], :user_id => current_user.id)[0]
    if @phone
      @phone.destroy
      redirect_to(phones_path, :notice => 'Phone was successfully deleted.')
    else
      redirect_to(root_path, :notice => "You don't have permissions to view that phone.")
    end
  end
end
