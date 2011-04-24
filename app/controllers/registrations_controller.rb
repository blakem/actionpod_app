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
  
  private
  
  def set_profile_values # XXX Dupe of the one in PagesController
    @user = current_user
    @title = @user.name
    @nextcalls = build_nextcalls(@user)
    @your = 'Your'
    @youhave = 'You have'
    @view_options = {}
  end
  
  def build_nextcalls(user) # XXX dupe of the one in PagesController
    calls = []
    start_time = Time.now
    end_time = start_time + 7.days
    user.events.each do |event|
      event.schedule.occurrences_between(start_time, end_time).each do |occurrence|
        calls.push(occurrence.in_time_zone(current_user.time_zone))
      end
    end
    calls = calls.sort{ |a,b| a <=> b }.map { |c| c.strftime("%l:%M%p on %A").sub(/AM/,'am').sub(/PM/,'pm') }
    calls[0..4]
  end
end