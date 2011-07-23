class RegistrationsController < Devise::RegistrationsController

  def new
    values = {}
    if params[:invite_code] and !params[:invite_code].blank?
      @invite = MemberInvite.find_by_invite_code(params[:invite_code])
      if @invite
        @group = Pool.find_by_id(@invite.pool_id)
        values[:email] = @invite.email
        values[:hide_optional_fields] = @group.hide_optional_fields
      end
    end
    resource = build_resource(values)
    respond_with_navigational(resource){ render_with_scope :new }
  end

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
    breadcrumbs.add 'Edit Your Member Information'
    set_profile_values
    @view_options = {:hide_edit_profile => true}
    super
  end

  def create
    build_resource

    if resource.invite_code and MemberInvite.find_by_invite_code(resource.invite_code)
      resource.confirmed_at = Time.now
      resource.confirmation_token = nil
    end

    if resource.save
      TwilioCaller.new.send_error_to_blake("New User: #{resource.id}:#{resource.name} - #{resource.invite_code}") if Rails.env.production?
      invite = MemberInvite.find_by_invite_code(resource.invite_code)
      if invite
        group = Pool.find_by_id(invite.pool_id)
        resource.pools = []
        if group
          group.add_member(resource)
          old_event = Event.where(:pool_id => group.id).sort{ |a,b| a.minute_of_day <=> b.minute_of_day }.first
          if old_event
            new_event = Event.create(
              :user_id => resource.id,
              :pool_id => group.id, 
            )
            new_time = old_event.next_occurrence.in_time_zone(resource.time_zone)
            new_event.time = old_event.ampm_format(new_time.hour, new_time.min)
            new_event.days = old_event.days
            new_event.save
          end
        end
      end
      set_flash_message :notice, :signed_up
      sign_in_and_redirect(resource_name, resource)
    else
      unless resource.invite_code.blank?
        @invite = MemberInvite.find_by_invite_code(resource.invite_code)
        if @invite
          @group = Pool.find_by_id(@invite.pool_id)
        end
      end
      clean_up_passwords(resource)
      render_with_scope :new
    end
  end

end