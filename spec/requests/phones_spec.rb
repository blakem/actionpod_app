require 'spec_helper'

def log_user_in(user)
  visit new_user_session_path
  fill_in "Email",      :with => user.email
  fill_in "Password",   :with => user.password
  click_button
  controller.user_signed_in?.should be_true
end

describe "Phones" do
  
  describe "failure" do
    it "should not create a new phone with invalid args" do
      expect {
        user = Factory(:user, :email => 'purple@example.com', :confirmed_at => Time.now)
        log_user_in(user)
  
        click_link 'Add or Delete Phones'
        response.should render_template('phones/index')
        click_link 'Add a New Phone Number'
        response.should render_template('phones/new')
        fill_in "Phone Number",  :with => '111 222 333'
        click_button
        response.should render_template('phones/new')
        response.should have_selector('div.flash.alert', :content => "Phone Number is invalid")
      }.should_not change(Phone, :count)
    end
  end

  describe "success" do
    it "should create a new phone with valid args" do
      user = Factory(:user, :email => 'purple@example.com', :confirmed_at => Time.now)
      log_user_in(user)
      expect {
        click_link 'Add or Delete Phones'
        response.should render_template('phones/index')
        click_link 'Add a New Phone Number'
        response.should render_template('phones/new')
        fill_in "Phone Number",  :with => '111 222 3335'
        click_button
        response.should render_template('phones/index')
        response.should have_selector('div.flash.notice', :content => "Phone was successfully created")
      }.should change(Phone, :count).by(1)
    end

    it "should edit an existing phone" do
      user = Factory(:user, :email => 'purple@example.com', :confirmed_at => Time.now)
      phone = Factory(:phone, :user_id => user.id, :primary => true)
      log_user_in(user)
      expect {  
        click_link 'Add or Delete Phones'
        response.should render_template('phones/index')
        click_link 'Edit'
        response.should render_template('phones/edit')
        fill_in "Phone Number",  :with => '555 222 3335'
        click_button
        response.should render_template('phones/index')
        response.should have_selector('div.flash.notice', :content => "Phone was successfully updated")
      }.should_not change(Phone, :count)
      phone.reload
      phone.number.should == '+15552223335'
    end
  end
end
