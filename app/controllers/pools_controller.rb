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
      @users = @pool.users.paginate(:page => params[:page], :per_page => 10)
    else
      redirect_to(root_path, :alert => "You don't have permissions to view that group.")
    end
  end

  # GET /pools/new
  def new
    @pool = Pool.new
    @submit_text = 'Create Group'
  end

  # GET /pools/1/edit
  def edit
    @pool = admin_pool_from_params
    @submit_text = 'Update Group'
    @show_member_count = true
    redirect_to(root_path, :alert => "You don't have permissions to view that group.") unless @pool
  end

  # POST /pools
  def create
    @pool = Pool.new(params[:pool].merge({:admin_id => current_user.id}))
    if @pool.save
      current_user.pools << @pool
      redirect_to(@pool, :notice => 'Group was successfully created.')
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

    def set_breadcrumb
      set_profile_values
      breadcrumbs.add 'Manage Groups'
    end
end
