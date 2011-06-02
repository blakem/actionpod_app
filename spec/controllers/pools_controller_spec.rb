require 'spec_helper'

# This spec was generated by rspec-rails when you ran the scaffold generator.
# It demonstrates how one might use RSpec to specify the controller code that
# was generated by Rails when you ran the scaffold generator.
#
# It assumes that the implementation code is generated by the rails scaffold
# generator.  If you are using any extension libraries to generate different
# controller code, this generated spec may or may not pass.
#
# It only uses APIs available in rails and/or rspec-rails.  There are a number
# of tools you can use to make these specs even more expressive, but we're
# sticking to rails and rspec-rails APIs to keep things simple and stable.
#
# Compared to earlier versions of this generator, there is very limited use of
# stubs and message expectations in this spec.  Stubs are only used when there
# is no simpler way to get a handle on the object needed for the example.
# Message expectations are only used when there is no simpler way to specify
# that an instance is receiving a specific message.

describe PoolsController do

  # This should return the minimal set of attributes required to create a valid
  # Pool. As you add validations to Pool, be sure to
  # update the return value of this method accordingly.
  def valid_attributes
    @user = Factory(:user)
    {:admin_id => @user.id}
  end

  describe "GET index" do
    it "assigns all pools as @pools" do
      pool = Pool.create! valid_attributes
      get :index
      assigns(:pools).should eq(Pool.all)
    end
  end

  describe "GET show" do
    it "assigns the requested pool as @pool" do
      pool = Pool.create! valid_attributes
      get :show, :id => pool.id.to_s
      assigns(:pool).should eq(pool)
    end
  end

  describe "GET new" do
    it "assigns a new pool as @pool" do
      get :new
      assigns(:pool).should be_a_new(Pool)
    end
  end

  describe "GET edit" do
    it "assigns the requested pool as @pool" do
      pool = Pool.create! valid_attributes
      get :edit, :id => pool.id.to_s
      assigns(:pool).should eq(pool)
    end
  end

  describe "POST create" do
    describe "with valid params" do
      it "creates a new Pool" do
        expect {
          post :create, :pool => valid_attributes
        }.to change(Pool, :count).by(1)
      end

      it "assigns a newly created pool as @pool" do
        post :create, :pool => valid_attributes
        assigns(:pool).should be_a(Pool)
        assigns(:pool).should be_persisted
      end

      it "redirects to the created pool" do
        post :create, :pool => valid_attributes
        response.should redirect_to(Pool.last)
      end
    end

    describe "with invalid params" do
      it "assigns a newly created but unsaved pool as @pool" do
        # Trigger the behavior that occurs when invalid params are submitted
        Pool.any_instance.stub(:save).and_return(false)
        post :create, :pool => {}
        assigns(:pool).should be_a_new(Pool)
      end

      it "re-renders the 'new' template" do
        # Trigger the behavior that occurs when invalid params are submitted
        Pool.any_instance.stub(:save).and_return(false)
        post :create, :pool => {}
        response.should render_template("new")
      end
    end
  end

  describe "PUT update" do
    describe "with valid params" do
      it "updates the requested pool" do
        pool = Pool.create! valid_attributes
        # Assuming there are no other pools in the database, this
        # specifies that the Pool created on the previous line
        # receives the :update_attributes message with whatever params are
        # submitted in the request.
        Pool.any_instance.should_receive(:update_attributes).with({'these' => 'params'})
        put :update, :id => pool.id, :pool => {'these' => 'params'}
      end

      it "assigns the requested pool as @pool" do
        pool = Pool.create! valid_attributes
        put :update, :id => pool.id, :pool => valid_attributes
        assigns(:pool).should eq(pool)
      end

      it "redirects to the pool" do
        pool = Pool.create! valid_attributes
        put :update, :id => pool.id, :pool => valid_attributes
        response.should redirect_to(pool)
      end
    end

    describe "with invalid params" do
      it "assigns the pool as @pool" do
        pool = Pool.create! valid_attributes
        # Trigger the behavior that occurs when invalid params are submitted
        Pool.any_instance.stub(:save).and_return(false)
        put :update, :id => pool.id.to_s, :pool => {}
        assigns(:pool).should eq(pool)
      end

      it "re-renders the 'edit' template" do
        pool = Pool.create! valid_attributes
        # Trigger the behavior that occurs when invalid params are submitted
        Pool.any_instance.stub(:save).and_return(false)
        put :update, :id => pool.id.to_s, :pool => {}
        response.should render_template("edit")
      end
    end
  end

  describe "DELETE destroy" do
    it "destroys the requested pool" do
      pool = Pool.create! valid_attributes
      expect {
        delete :destroy, :id => pool.id.to_s
      }.to change(Pool, :count).by(-1)
    end

    it "redirects to the pools list" do
      pool = Pool.create! valid_attributes
      delete :destroy, :id => pool.id.to_s
      response.should redirect_to(pools_url)
    end
  end

end
