class PhonesController < ApplicationController
  before_filter :authenticate_user!
  before_filter :set_breadcrumb

  # GET /phones
  def index
    @phones = Phone.where(:user_id => current_user.id)
  end

  # GET /phones/1
  def show
    @phone = Phone.where(:id => params[:id], :user_id => current_user.id )[0]
    redirect_to(root_path, :alert => "You don't have permissions to view that phone.") unless @phone
  end

  # GET /phones/new
  def new
    @phone = Phone.new
  end

  # GET /phones/1/edit
  def edit
    @phone = Phone.where(:id => params[:id], :user_id => current_user.id)[0]
    redirect_to(root_path, :alert => "You don't have permissions to view that phone.") unless @phone
  end

  # POST /phones
  def create
    @phone = Phone.new(params[:phone].merge(:user_id => current_user.id))
    if @phone.save
      if @phone.primary
        other_phones = @phone.user.phones.select { |p| p.id != @phone.id }
        other_phones.each do |other_phone|
          other_phone.primary = false
          other_phone.save
        end
      end
      redirect_to(phones_path, :notice => 'Phone was successfully created.')
    else
      render :action => "new"
    end
  end

  # PUT /phones/1
  def update
    @phone = Phone.where(:id => params[:id], :user_id => current_user.id)[0]

    if @phone
      params[:phone]['primary'] = '1' if params[:phone] && @phone.primary
      if @phone.update_attributes(params[:phone])
        if @phone.primary
          other_phones = @phone.user.phones.select { |p| p.id != @phone.id }
          other_phones.each do |other_phone|
            other_phone.primary = false
            other_phone.save
          end
        end
        redirect_to(phones_path, :notice => 'Phone was successfully updated.')
      else
        render :action => "edit"
      end
    else
      redirect_to(root_path, :alert => "You don't have permissions to view that phone.")
    end
  end

  # DELETE /phones/1
  def destroy
    @phone = Phone.where(:id => params[:id], :user_id => current_user.id)[0]
    if @phone
      if @phone.primary
        redirect_to(phones_path, :alert => "You can't delete your primary phone")
      else
        @phone.destroy
        redirect_to(phones_path, :notice => 'Phone was successfully deleted.')
      end
    else
      redirect_to(root_path, :alert => "You don't have permissions to view that phone.")
    end
  end
  
  private
    def set_breadcrumb
      set_profile_values
      breadcrumbs.add 'Manage Phones'
    end

end
