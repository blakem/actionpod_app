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
end