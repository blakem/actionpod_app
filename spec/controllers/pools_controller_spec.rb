require 'spec_helper'

describe PoolsController do

  describe "when not logged in" do
    it "should redirect to the home page" do
  	  controller.user_signed_in?.should be_false
      get :index
      response.should redirect_to('/members/sign_in')
    end
  end

  describe "when logged in" do
    before(:each) do
      login_user
      @other_user = Factory(:user)
      @attr = {
        :admin_id => @other_user.id,
        :name => 'Some Random Testing Pool',
        :public_group => false,
      }
      @pool1 = Pool.create! @attr.merge({:admin_id => @current_user.id})
      @pool2 = Pool.create! @attr
      @pool_other = Pool.create! @attr
      @current_user.pools = [@pool1, @pool2]
    end
    
    describe "GET index" do
      it "assigns all users pools as @pools" do
        get :index
        assigns(:pools).should     include(@pool1, @pool2)
        assigns(:pools).should_not include(@pool_other)
      end
    end

    describe "GET show" do
      it "assigns the requested pool as @pool" do
        get :show, :id => @pool1.id.to_s
        assigns(:pool).should eq(@pool1)
      end
      
      it "redirects if you try to show a pool you don't belong to" do
        get :show, :id => @pool_other.id
        response.should redirect_to(root_path)
      end

      it "redirects if you try to send an arbitrary id" do
        get :show, :id => 77345
        response.should redirect_to(root_path)
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
        get :edit, :id => @pool1.id.to_s
        assigns(:pool).should eq(@pool1)
      end
      
      it "redirects if you try to show a pool you aren't admin of" do
        get :edit, :id => @pool2.id
        response.should redirect_to(root_path)
      end

      it "redirects if you try to show a pool you don't belong to" do
        get :edit, :id => @pool_other.id
        response.should redirect_to(root_path)
      end

      it "redirects if you try to send an arbitrary id" do
        get :edit, :id => 77345
        response.should redirect_to(root_path)
      end
    end

    describe "GET invite" do
      it "assigns the requested pool as @pool" do
        get :invite, :id => @pool1.id.to_s
        assigns(:pool).should eq(@pool1)
      end

      it "assigns the requested pool as @pool if pool is public" do
        @pool1.public_group = true
        @pool1.save
        get :invite, :id => @pool1.id.to_s
        assigns(:pool).should eq(@pool1)
      end
      
      it "redirects if you try to show a pool you aren't admin of" do
        get :invite, :id => @pool2.id
        response.should redirect_to(root_path)
      end

      it "redirects if you try to show a pool you don't belong to" do
        get :invite, :id => @pool_other.id
        response.should redirect_to(root_path)
      end

      it "redirects if you try to send an arbitrary id" do
        get :invite, :id => 77345
        response.should redirect_to(root_path)
      end
    end

    describe "POST create" do
      describe "with valid params" do
        it "creates a new Pool" do
          expect {
            post :create, :pool => @attr
          }.to change(Pool, :count).by(1)
        end

        it "assigns a newly created pool as @pool" do
          pools = @current_user.pools
          pools.should_not be_empty
          post :create, :pool => @attr
          pool = assigns(:pool)
          pool.should be_a(Pool)
          pool.should be_persisted
          pool.admin_id.should == @current_user.id
          @current_user.reload
          @current_user.pools.should include(pool)
          pools.each do |p|
            @current_user.pools.should include(p)
          end
        end

        it "redirects to the created pool" do
          post :create, :pool => @attr
          response.should redirect_to(invite_pool_path(Pool.last))
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
          Pool.any_instance.should_receive(:update_attributes).with({'these' => 'params'})
          put :update, :id => @pool1.id, :pool => {'these' => 'params'}
        end

        it "assigns the requested pool as @pool" do
          put :update, :id => @pool1.id, :pool => @attr
          assigns(:pool).should eq(@pool1)
        end

        it "redirects to the pool" do
          put :update, :id => @pool1.id, :pool => @attr
          response.should redirect_to(@pool1)
        end
        
        it "redirects if you aren't the admin" do
          get :update, :id => @pool2.id
          response.should redirect_to(root_path)
        end

        it "redirects if you try to show someone else's event" do
          get :update, :id => @pool_other.id
          response.should redirect_to(root_path)
        end

        it "redirects if you try to send an arbitrary id" do
          get :update, :id => 77345
          response.should redirect_to(root_path)
        end
      end

      describe "with invalid params" do
        it "assigns the pool as @pool" do
          Pool.any_instance.stub(:save).and_return(false)
          put :update, :id => @pool1.id.to_s, :pool => {}
          assigns(:pool).should eq(@pool1)
        end

        it "re-renders the 'edit' template" do
          Pool.any_instance.stub(:save).and_return(false)
          put :update, :id => @pool1.id.to_s, :pool => {}
          response.should render_template("edit")
        end
      end
    end

    describe "DELETE destroy" do
      it "Doesn't allow you to delete a pool that has members" do
        second_user = Factory(:user)
        second_user.pools = [@pool1]
        pool_id = @pool1.id
        delete :destroy, :id => pool_id
        Pool.find_by_id(pool_id).should_not be_nil
        response.should redirect_to(:controller => :pages, :action => :manage_groups)
      end

      it "destroys the requested pool if it only has one member (you) and you're the admin" do
        @pool_empty = Pool.create! @attr.merge({:admin_id => @current_user.id})
        @pool_empty.users = []
        expect {
          delete :destroy, :id => @pool_empty.id
        }.to change(Pool, :count).by(-1)
        response.should redirect_to(:controller => :pages, :action => :manage_groups)
      end

      it "destroys the requested pool if it has no members" do
        @pool1.users = []
        expect {
          delete :destroy, :id => @pool1.id.to_s
        }.to change(Pool, :count).by(-1)
        response.should redirect_to(:controller => :pages, :action => :manage_groups)
      end

      it "Doesn't allow you to delete someone elses pools" do
        @pool_other.users = []
        other_pool_id = @pool_other.id
        delete :destroy, :id => other_pool_id
        Pool.find_by_id(other_pool_id).should_not be_nil
        response.should redirect_to(root_path)
      end
      
      it "Doesn't allow you to delete a pool that you aren't admin of" do
        @pool2.users = []
        other_pool_id = @pool2.id
        delete :destroy, :id => other_pool_id
        Pool.find_by_id(other_pool_id).should_not be_nil
        response.should redirect_to(root_path)
      end
    end
  end
end
