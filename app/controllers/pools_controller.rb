class PoolsController < ApplicationController
  before_filter :authenticate_user!
  
  # GET /pools
  def index
    @pools = current_user.pools
  end

  # GET /pools/1
  def show
    @pool = pool_from_params
    redirect_to(root_path, :alert => "You don't have permissions to view that group.") unless @pool
  end

  # GET /pools/new
  def new
    @pool = Pool.new
  end

  # GET /pools/1/edit
  def edit
    @pool = admin_pool_from_params
    redirect_to(root_path, :alert => "You don't have permissions to view that group.") unless @pool
  end

  # POST /pools
  def create
    @pool = Pool.new(params[:pool].merge({:admin_id => current_user.id}))
    if @pool.save
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
      @pool.destroy
      redirect_to(pools_url)
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
end