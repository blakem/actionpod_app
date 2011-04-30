class RegistrationsController < Devise::RegistrationsController

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

  def create
    build_resource

    if resource.save
      TwilioCaller.new.send_error_to_blake("New User: #{resource.id}:#{resource.name} - #{resource.invite_code}") if Rails.env.production?
      set_flash_message :notice, :signed_up
      sign_in_and_redirect(resource_name, resource)
    else
      clean_up_passwords(resource)
      render_with_scope :new
    end
  end

end