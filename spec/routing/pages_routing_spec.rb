require "spec_helper"

describe PagesController do
  describe "routing" do

    it "recognizes and generates #home" do
      { :get => "/" }.should route_to(:controller => "pages", :action => "home")
    end

    it "recognizes and generates #my_profile" do
      { :get => "/pages/my_profile" }.should route_to(:controller => "pages", :action => "my_profile")
    end

    it "recognizes and generates #profile" do
      { :get => "/member/blakem" }.should route_to(:controller => "pages", :action => "profile", :handle => "blakem")
    end

    it "recognizes and generates #join" do
      { :get => "/pages/join" }.should route_to(:controller => "pages", :action => "join")
    end

    it "recognizes and generates #callcal" do
      { :post => "/pages/callcal" }.should route_to(:controller => "pages", :action => "callcal")
    end
  end
end
