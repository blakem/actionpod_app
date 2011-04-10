class RegistrationsController < Devise::RegistrationsController
  def destroy
    resource.soft_delete # instead of resource.destroy
    set_flash_message :notice, :destroyed
    sign_out_and_redirect(resource)
  end
end