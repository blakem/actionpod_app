require 'spec_helper'

describe "Plans" do
  
  describe "success" do
    it "should create a new event / edit an existing event / delete an existing event" do
      # log in
      user = Factory(:user, :confirmed_at => Time.now)
      visit new_user_session_path
      fill_in "Email",      :with => user.email
      fill_in "Password",   :with => user.password
      click_button
      controller.user_signed_in?.should be_true
      user.current_plan.should be_nil
      user.plans.should be_empty

      # show error on empty plan
      click_link 'Update your Plan'
      expect {
        fill_in "Update Plan",      :with => ''
        click_button
      }.should_not change(Plan, :count)
      response.should render_template('pages/plan')
      response.should have_selector('div.flash.alert', :content => 'blank')
      user.current_plan.should be_nil
      user.plans.should be_empty
      
      # Create new plan
      expect {
        fill_in "Update Plan",      :with => 'Plan #1'
        click_button
      }.should change(Plan, :count).by(1)
      response.should have_selector('div.flash.notice', :content => 'Your plan was successfully updated')
      user.reload
      user.current_plan.body.should == 'Plan #1'
      user.plans.count.should == 1

      # Create second plan
      click_link 'Update your Plan'
      expect {
        fill_in "Update Plan",      :with => 'Plan #2'
        click_button
      }.should change(Plan, :count).by(1)
      response.should have_selector('div.flash.notice', :content => 'Your plan was successfully updated')
      user.reload
      user.current_plan.body.should == 'Plan #2'
      user.plans.count.should == 2
    end
  end
end
