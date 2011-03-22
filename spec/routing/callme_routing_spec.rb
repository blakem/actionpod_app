require "spec_helper"

describe CallmeController do

  describe "routing" do

    it "recognizes and generates #index" do
      { :get => "/callme" }.should route_to(:controller => "callme", :action => "index")
    end

    it "can :get to makecall" do
      { :get => "/callme/makecall" }.should route_to(:controller => "callme", :action => "makecall")
    end

    it "can :post to makecall" do
      { :post => "/callme/makecall" }.should route_to(:controller => "callme", :action => "makecall")
    end
  end
end
