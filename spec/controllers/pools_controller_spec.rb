require 'spec_helper'

describe PoolsController do

  def valid_attributes
    @user = Factory(:user)
    {:admin_id => @user.id}
  end

  describe "when not logged in" do
    it "should redirect to the home page" do
  	  controller.user_signed_in?.should be_false
      get :index
      response.should redirect_to('/members/sign_in')
    end
  end

  describe "when logged in" do
    before(:each) do
      User.all.each { |u| u.destroy }
      login_user
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
end
