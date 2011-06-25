class PoolsController < ApplicationController
  before_filter :authenticate_user!
  before_filter :set_breadcrumb
  
  # GET /pools
  def index
    @pools = current_user.pools
  end

  # GET /pools/1
  def show
    @pool = pool_from_params
    if @pool
      breadcrumbs.add @pool.name
      @users = @pool.users.paginate(:page => params[:page], :per_page => 10)
    else
      redirect_to(root_path, :alert => "You don't have permissions to view that group.")
    end
  end

  # GET /pools/new
  def new
    @pool = Pool.new
    @pool.hide_optional_fields = true
    @pool.allow_others_to_invite = true
    @pool.public_group = true
    @pool.available_time_mode = '60'
    @pool.send_conference_email = true
    @pool.merge_type = 1
    @submit_text = 'Create Group'
  end

  # GET /pools/1/edit
  def edit
    @pool = admin_pool_from_params
    if @pool
      breadcrumbs.add @pool.name
      breadcrumbs.add 'Edit'
      @submit_text = 'Update Group'
      @show_member_count = true
    else
      redirect_to(root_path, :alert => "You don't have permissions to view that group.")
    end
  end

  # GET /pools/1/invite
  def invite
    @pool = invite_pool_from_params
    if @pool
      breadcrumbs.add @pool.name
      breadcrumbs.add 'Invite Members'
      previous_invite = MemberInvite.where(:sender_id => current_user.id, :pool_id => @pool.id).sort_by(&:id).last
      if previous_invite
        @default_personal_message = previous_invite.message
      else
        @default_personal_message = ''
      end
    else
      redirect_to(root_path, :alert => "You don't have permissions to view that group.")
    end
  end

  # POST /pools
  def create
    @pool = Pool.new(params[:pool].merge({:admin_id => current_user.id}))
    if @pool.save
      current_user.pools << @pool
      redirect_to(invite_pool_path(@pool), :notice => 'Group was successfully created. Now invite some people.')
    else
      render :action => "new"
    end
  end

  # PUT /pools/1
  def update
    @pool = admin_pool_from_params
    if @pool
      if @pool.update_attributes(params[:pool])
        redirect_to(@pool, :notice => 'Group was successfully updated.')
      else
        render :action => "edit"
      end
    else
      redirect_to(root_path, :alert => "You don't have permissions to view that group.")
    end
  end

  # DELETE /pools/1
  def destroy
    @pool = admin_pool_from_params
    if @pool
      if @pool.users.count == 0 or (@pool.users.count == 1 && @pool.users.first.id == @pool.admin_id)
        @pool.destroy
        redirect_to(:controller => :pages, :action => :manage_groups)
      else
        redirect_to('/pages/manage_groups', :alert => "You can't delete a group that has members.")
      end
    else
      redirect_to(root_path, :alert => "You don't have permissions to view that group.")
    end
  end
  
  private
    def pool_from_params
      @current_user.pools.select{ |p| p.id == params[:id].to_i }.first
    end

    def admin_pool_from_params
      Pool.where(:id => params[:id], :admin_id => current_user.id)[0]
    end
    
    def invite_pool_from_params
      pool = Pool.find_by_id(params[:id])
      if pool and pool.can_invite?(current_user)
        pool
      else 
        nil
      end
    end

    def set_breadcrumb
      set_profile_values
      breadcrumbs.add 'Manage Groups'
    end
end
