require 'spec_helper'

describe "Intros" do
  
  describe "success" do
    it "should edit user.about for the current user" do
      # log in
      user = Factory(:user, :confirmed_at => Time.now)
      visit new_user_session_path
      fill_in "Email",      :with => user.email
      fill_in "Password",   :with => user.password
      click_button
      controller.user_signed_in?.should be_true
      
      # update intro
      click_link 'Update Your Intro'
      fill_in "Update Your Introduction",  :with => 'My New Intro'
      click_button
      response.should have_selector('div.flash.notice', :content => 'Your introduction was successfully updated')
      user.reload
      user.about.should == 'My New Intro'
    end
  end
end
