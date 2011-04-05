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
      response.should redirect_to('/users/sign_in')
    end
  end  

  describe "when logged in" do
    login_user
    before(:each) do
      @pool ||= Factory(:pool, :name => 'Default Pool')
      @event1 ||= Factory(:event, :user_id => @current_user.id)
      @event2 ||= Factory(:event, :user_id => @current_user.id)
      @event_other ||= Factory(:event)
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
        Event.stub(:new) { mock_event }
        get :new
        assigns(:event).should be(mock_event)
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
          pool = Pool.find_by_name('Default Pool')
          pool.should be_a_kind_of(Pool)
          Event.stub(:new).with({
            'these' => 'params', 
            'user_id' => controller.current_user.id, 
            'pool_id' => pool.id}
          ) { mock_event(:save => true) }
          post :create, :event => {'these' => 'params'}
          assigns(:event).should be(mock_event)
        end
  
        it "redirects to the created event" do
          Event.stub(:new) { mock_event(:save => true) }
          post :create, :event => {}
          response.should redirect_to(event_url(mock_event))
        end
      end
  
      describe "with invalid params" do
        it "assigns a newly created but unsaved event as @event" do
          pool = Pool.find_by_name('Default Pool')
          pool.should be_a_kind_of(Pool)
          Event.stub(:new).with({
            'these' => 'params', 
            'user_id' => controller.current_user.id,
            'pool_id' => pool.id
          }) { mock_event(:save => false) }
          post :create, :event => {'these' => 'params'}
          assigns(:event).should be(mock_event)
        end
  
        it "re-renders the 'new' template" do
          Event.stub(:new) { mock_event(:save => false) }
          post :create, :event => {}
          response.should render_template("new")
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
          response.should redirect_to(@event1)
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
          Event.stub(:where) { [mock_event(:update_attributes => false)] }
          put :update, :id => "1"
          assigns(:event).should be(mock_event)
        end
  
        it "re-renders the 'edit' template" do
          Event.stub(:where) { [mock_event(:update_attributes => false)] }
          put :update, :id => "1"
          response.should render_template("edit")
        end
      end
    end
  
    describe "DELETE destroy" do
      it "destroys the requested event" do
        event_id = @event1.id
        delete :destroy, :id => event_id
        Event.find_by_id(event_id).should be_nil
        response.should redirect_to(events_url)
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
