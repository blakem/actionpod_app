require 'spec_helper'

describe "Phones" do
  describe "GET /phones" do
    it "works! (now write some real specs)" do
      user = Factory(:user)
      visit new_user_session_path
      fill_in "Email",      :with => user.email
      fill_in "Password",   :with => user.password
      click_button
      controller.user_signed_in?.should be_true

      visit phones_path
      response.status.should be(200)
    end
  end
end
