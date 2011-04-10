require 'spec_helper'

describe "Users" do
  
  describe "signup" do
    
    describe "failure" do
      it "should not make a new user" do
        lambda do
          visit new_user_registration_path
          fill_in "Invite Code",            :with => ""
          fill_in "Name",                   :with => ""
          fill_in "Email",                  :with => ""
          fill_in "Primary Phone",          :with => ""
          fill_in "Title",                  :with => ""
          fill_in "Time Zone",              :with => ""
          fill_in "Password",               :with => ""
          fill_in "Password Confirmation",  :with => ""
          click_button
          response.should render_template('registrations/new')
          response.should have_selector('div#error_explanation')
        end.should_not change(User, :count)
      end
    end
    
    describe "success" do
      it "should make a new user" do
        lambda do
          visit new_user_registration_path
          fill_in "Invite Code",            :with => "xyzzy"
          fill_in "Name",                   :with => "Example User"
          fill_in "Email",                  :with => "example@example.org"
          fill_in "Primary Phone",   :with => "415 111 2222"
          fill_in "Time Zone",              :with => "Pacific Time (US & Canada)"
          fill_in "Password",               :with => "a"*10
          fill_in "Password Confirmation",  :with => "a"*10
          click_button
          response.should have_selector('div.flash.notice', :content => 'You have signed up successfully')
          response.should render_template('pages/profile')
        end.should change(User, :count).by(1)
      end
    end
  end
  
  describe "signin" do
  
    describe "failure" do
      it "should not sign a user in" do
        visit new_user_session_path
        fill_in "Email",      :with => ""
        fill_in "Password",   :with => ""
        click_button
        response.should have_selector('div.flash.alert', :content => "Invalid email or password")
        response.should render_template('sessions/new')
      end
    end    
  
    describe "success" do
      before(:each) do
        @user = Factory(:user)
      end
      it "should sign a user in and out" do
        visit new_user_session_path
        fill_in "Email",      :with => @user.email
        fill_in "Password",   :with => @user.password
        click_button
        controller.user_signed_in?.should be_true
        click_link "Logout"
        controller.user_signed_in?.should be_false          
      end        
    end  
  end
end
