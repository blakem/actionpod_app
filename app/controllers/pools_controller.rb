class PoolsController < ApplicationController
  before_filter :authenticate_user!
  
  # GET /pools
  def index
    @pools = Pool.all
  end

  # GET /pools/1
  def show
    @pool = Pool.find(params[:id])
  end

  # GET /pools/new
  def new
    @pool = Pool.new
  end

  # GET /pools/1/edit
  def edit
    @pool = Pool.find(params[:id])
  end

  # POST /pools
  def create
    @pool = Pool.new(params[:pool])
    if @pool.save
      redirect_to(@pool, :notice => 'Pool was successfully created.')
    else
      render :action => "new"
    end
  end

  # PUT /pools/1
  def update
    @pool = Pool.find(params[:id])
    if @pool.update_attributes(params[:pool])
      redirect_to(@pool, :notice => 'Pool was successfully updated.')
    else
      render :action => "edit"
    end
  end

  # DELETE /pools/1
  def destroy
    @pool = Pool.find(params[:id])
    @pool.destroy
    redirect_to(pools_url)
  end
end
