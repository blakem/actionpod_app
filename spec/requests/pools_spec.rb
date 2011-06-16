require 'spec_helper'

# -  describe "GET /pools" do
# -    it "works! (now write some real specs)" do
# -      visit pools_path
# -      response.status.should be(200)

def log_user_in(user)
  visit new_user_session_path
  fill_in "Email",      :with => user.email
  fill_in "Password",   :with => user.password
  click_button
  controller.user_signed_in?.should be_true
end

describe "Pools" do
  
  describe "failure" do
    it "should not create a new pool with invalid args" do
      expect {
        user = Factory(:user)
        log_user_in(user)
        click_link 'Manage Groups'
        response.should render_template('pages/manage_groups')
        click_link 'Create a new group'
        response.should render_template('pools/new')
        fill_in "Name",       :with => ''
        fill_in "Call Time Limit", :with => 'abc'
        click_button
        response.should render_template('pools/new')
        response.should have_selector('div.flash.alert', :content => "Name can't be blank")
        response.should have_selector('div.flash.alert', :content => "Timelimit is not a number")
      }.should_not change(Pool, :count)
    end
  end
  
  describe "success" do
    it "should create a new pool with valid args" do
      user = Factory(:user)
      log_user_in(user)
      expect {
        click_link 'Manage Groups'
        response.should render_template('pages/manage_groups')
        click_link 'Create a new group'
        response.should render_template('pools/new')
        fill_in "Name",       :with => 'Testing Testing Group'
        fill_in "Call Time Limit", :with => '20'
        click_button
        response.should render_template('pools/invite')
        response.should have_selector('div.flash.notice', :content => "Group was successfully created")
      }.should change(Pool, :count).by(1)
    end
  
    it "should edit an existing pool" do
      user = Factory(:user)
      pool = Factory(:pool, :admin_id => user.id)
      user.pools = [pool]
      log_user_in(user)
      expect {  
        click_link 'Manage Groups'
        response.should render_template('pages/manage_groups')
        click_link "Edit"
        response.should render_template('pools/edit')
        fill_in "Name",  :with => 'A New Name'
        click_button
        response.should render_template('pools/show')
        response.should have_selector('div.flash.notice', :content => "Group was successfully updated")
      }.should_not change(Pool, :count)
      pool.reload
      pool.name.should == 'A New Name'
    end
  end
end
