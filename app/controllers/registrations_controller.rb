class RegistrationsController < Devise::RegistrationsController
  layout "sidebar", :only => :edit

  def destroy
    resource.soft_delete # instead of resource.destroy
    set_flash_message :notice, :destroyed
    sign_out_and_redirect(resource)
  end

  def update
    params[resource_name]['password'] = '' if params[resource_name]['password_confirmation'].blank?
    super
  end

  def edit
    set_profile_values
    @view_options = {:hide_edit_profile => true}
    super
  end
end