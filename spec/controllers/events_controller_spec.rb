require 'spec_helper'

describe EventsController do
  render_views

  def mock_event(stubs={})
    @mock_event ||= mock_model(Event, stubs).as_null_object
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
      @pool ||= Factory(:pool, :name => 'Default Group')
      @event1 ||= Factory(:event, :user_id => @current_user.id, :pool_id => @pool.id)
      @event2 ||= Factory(:event, :user_id => @current_user.id, :pool_id => @pool.id)
      @event_other ||= Factory(:event, :pool_id => @pool.id)
    end

    describe "GET index" do

      it "should be successful when logged in" do
        controller.user_signed_in?.should be_true
        get :index
        response.should be_success
      end
  
      it "assigns all the user's events as @events" do
        get :index
        assigns(:events).should include(@event1, @event2)
        assigns(:events).should_not include(@event_other)
      end
    end
  
    describe "GET show" do
      it "assigns the requested event as @event" do
        get :show, :id => @event1.id
        assigns(:event).should == @event1
      end

      it "redirects if you try to show someone else's event" do
        get :show, :id => @event_other.id
        response.should redirect_to(root_path)
      end

      it "redirects if you try to send an arbitrary id" do
        get :show, :id => 77345
        response.should redirect_to(root_path)
      end
    end
  
    describe "GET new" do
      it "assigns a new event as @event" do
        event = Factory(:event)
        pool = Factory(:pool)
        @current_user.pools = [pool]
        Event.stub(:new) { event }
        get :new, :group_id => pool.id
        assigns(:event).should be(event)
      end

      it "redirects if you don't give it a group_id" do
        get :new
        response.should redirect_to(root_path)
      end

      it "redirects if you give it a group_id you don't belong to" do
        pool = Factory(:pool)
        get :new, :group_id => pool.id
        response.should redirect_to(root_path)
      end
    end
  
    describe "GET edit" do
      it "assigns the requested event as @event" do
        get :edit, :id => @event1.id
        assigns(:event).should == @event1
      end

      it "redirects if you try to show someone else's event" do
        get :edit, :id => @event_other.id
        response.should redirect_to(root_path)
      end

      it "redirects if you try to send an arbitrary id" do
        get :edit, :id => 77345
        response.should redirect_to(root_path)
      end
    end
  
    describe "POST create" do
      describe "with valid params" do
        it "assigns a newly created event as @event" do
          pool = Factory(:pool)
          @current_user.pools = [pool]
          mock_event(:save => true)
          mock_event.should_receive(:alter_schedule).with(
            :start_date => Time.now.in_time_zone(controller.current_user.time_zone).beginning_of_day
          )
          Event.stub(:new).with({
            'these' => 'params', 
            'user_id' => controller.current_user.id,
            'pool_id' => pool.id,
            'days'    => []
          }) { mock_event }
          post :create, :event => {'these' => 'params', 'pool_id' => pool.id}
          assigns(:event).should be(mock_event)
        end
  
        it "redirects to the created event" do
          Event.stub(:new) { mock_event(:save => true) }
          post :create, :event => {}
          response.should redirect_to(root_path)
        end
      end
  
      describe "with invalid params" do
        it "assigns a newly created but unsaved event as @event" do
          pool = Factory(:pool)
          @current_user.pools = [pool]
          event = Factory(:event)
          Event.stub(:new).with({
            'skip_dates' => 'foo', 
            'user_id' => controller.current_user.id,
            'pool_id' => pool.id,
            'days' => []
          }) { event }
          post :create, :event => {:skip_dates => 'foo', :pool_id => pool.id}
          assigns(:event).should be(event)
        end
      end
    end
  
    describe "PUT update" do
      describe "with valid params" do
        it "updates the requested event" do
          put :update, :id => @event1.id, :event => {'name' => 'NewName'}
          @event1.reload
          @event1.name.should == 'NewName'
          assigns(:event).should == @event1
          response.should redirect_to(root_path)
        end

        it "redirects if you try to show someone else's event" do
          get :update, :id => @event_other.id
          response.should redirect_to(root_path)
        end

        it "redirects if you try to send an arbitrary id" do
          get :update, :id => 77345
          response.should redirect_to(root_path)
        end
      end
  
      describe "with invalid params" do
        it "assigns the event as @event" do
          login_user
          event = Factory(:event, :user_id => @current_user.id)
          put :update, :id => event.id, :skip_dates => 'foo'
          assigns(:event).should == event
        end
      end
    end
  
    describe "DELETE destroy" do
      it "destroys the requested event" do
        event_id = @event1.id
        delete :destroy, :id => event_id
        Event.find_by_id(event_id).should be_nil
        response.should redirect_to(root_path)
      end
  
      it "Doesn't allow you to delete someone elses events" do
        other_event_id = @event_other.id
        delete :destroy, :id => other_event_id
        Event.find_by_id(other_event_id).should_not be_nil
        response.should redirect_to(root_path)
      end
    end
  end
end
