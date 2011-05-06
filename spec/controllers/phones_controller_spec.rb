require 'spec_helper'

describe PhonesController do

  def mock_phone(stubs={})
    @mock_phone ||= mock_model(Phone, stubs).as_null_object
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
      @phone1 = Factory(:phone, :user_id => @current_user.id, :primary => true)
      @phone2 = Factory(:phone, :user_id => @current_user.id)
      @phone_other = Factory(:phone)
    end
    
    describe "GET index" do
      it "should be successful when logged in" do
        controller.user_signed_in?.should be_true
        get :index
        response.should be_success
      end

      it "assigns all users phones as @phones" do
        get :index
        assigns(:phones).should include(@phone1, @phone2)
        assigns(:phones).should_not include(@other_phone)
      end
    end

    describe "GET show" do
      it "assigns the requested phone as @phone" do
        get :show, :id => @phone1.id
        assigns(:phone).should == @phone1
      end
      
      it "redirects if you try to show someone else's phone" do
        get :show, :id => @phone_other.id
        response.should redirect_to(root_path)
      end

      it "redirects if you try to send an arbitrary id" do
        get :show, :id => 77345
        response.should redirect_to(root_path)
      end
    end

    describe "GET new" do
      it "assigns a new phone as @phone" do
        Phone.stub(:new) { mock_phone }
        get :new
        assigns(:phone).should be(mock_phone)
      end
    end

    describe "GET edit" do
      it "assigns the requested phone as @phone" do
        get :edit, :id => @phone1.id
        assigns(:phone).should == @phone1
      end

      it "redirects if you try to show someone else's phone" do
        get :edit, :id => @phone_other.id
        response.should redirect_to(root_path)
      end

      it "redirects if you try to send an arbitrary id" do
        get :edit, :id => 77345
        response.should redirect_to(root_path)
      end
    end

    describe "POST create" do
      describe "with valid params" do
        it "assigns a newly created phone as @phone" do
          Phone.stub(:new).with({
            'these' => 'params', 
            'user_id' => controller.current_user.id,
          }) { mock_phone }
          post :create, :phone => {'these' => 'params'}
          assigns(:phone).should be(mock_phone)
        end

        it "redirects to the phone list" do
          Phone.stub(:new) { mock_phone(:save => true) }
          post :create, :phone => {}
          response.should redirect_to(phones_url)
        end

        it "setting the primary flag on a phone will unset it on all others" do
          post :create, :phone => {'string' => '123 333 4444', 'primary' => '1'}
          @phone1.reload
          @phone1.primary.should be_false
          response.should redirect_to(phones_path)
        end
      end

      describe "with invalid params" do
        it "assigns a newly created but unsaved phone as @phone" do
          Phone.stub(:new).with({
            'these' => 'params', 
            'user_id' => controller.current_user.id,
          }) { mock_phone(:save => false) }
          post :create, :phone => {'these' => 'params'}
          assigns(:phone).should be(mock_phone)
        end

        it "re-renders the 'new' template" do
          Phone.stub(:new) { mock_phone(:save => false) }
          post :create, :phone => {}
          response.should render_template("new")
        end
      end
    end

    describe "PUT update" do
      describe "with valid params" do
        it "updates the requested phone" do
          put :update, :id => @phone1.id, :phone => {'string' => '415 333 8765'}
          @phone1.reload
          @phone1.number.should == '+14153338765'
          assigns(:phone).should == @phone1
          response.should redirect_to(phones_path)
        end

        it "can't unset the primary flag on your primary phone" do
          put :update, :id => @phone1.id, :phone => {'string' => '415 333 8765', 'primary' => '0'}
          @phone1.reload
          @phone1.number.should == '+14153338765'
          @phone1.primary.should be_true
          assigns(:phone).should == @phone1
          response.should redirect_to(phones_path)
        end

        it "setting the primary flag on a phone will unset it on all others" do
          put :update, :id => @phone2.id, :phone => {'primary' => '1'}
          @phone2.reload
          @phone2.primary.should be_true
          assigns(:phone).should == @phone2
          @phone1.reload
          @phone1.primary.should be_false
          response.should redirect_to(phones_path)
        end

        it "redirects if you try to show someone else's phone" do
          get :update, :id => @phone_other.id
          response.should redirect_to(root_path)
        end

        it "redirects if you try to send an arbitrary id" do
          get :update, :id => 77345
          response.should redirect_to(root_path)
        end
      end

      describe "with invalid params" do

        it "assigns the phone as @phone" do
          Phone.stub(:where) { [mock_phone(:update_attributes => false)] }
          put :update, :id => "1"
          assigns(:phone).should be(mock_phone)
        end

        it "re-renders the 'edit' template" do
          Phone.stub(:where) { [mock_phone(:update_attributes => false)] }
          put :update, :id => "1"
          response.should render_template("edit")
        end
      end
    end
    
    describe "DELETE destroy" do
      it "destroys the requested phone" do
        phone_id = @phone2.id
        delete :destroy, :id => phone_id
        Phone.find_by_id(phone_id).should be_nil
        response.should redirect_to(phones_url)
      end

      it "Doesn't allow you to delete your primary phone" do
        phone_id = @phone1.id
        delete :destroy, :id => phone_id
        Phone.find_by_id(phone_id).should_not be_nil
        response.should redirect_to(phones_url)
      end

      it "Doesn't allow you to delete someone elses phones" do
        other_phone_id = @phone_other.id
        delete :destroy, :id => other_phone_id
        Phone.find_by_id(other_phone_id).should_not be_nil
        response.should redirect_to(root_path)
      end
    end
  end
end
