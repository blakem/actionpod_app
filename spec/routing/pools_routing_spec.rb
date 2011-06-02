require "spec_helper"

describe PoolsController do
  describe "routing" do

    it "routes to #index" do
      get("/pools").should route_to("pools#index")
    end

    it "routes to #new" do
      get("/pools/new").should route_to("pools#new")
    end

    it "routes to #show" do
      get("/pools/1").should route_to("pools#show", :id => "1")
    end

    it "routes to #edit" do
      get("/pools/1/edit").should route_to("pools#edit", :id => "1")
    end

    it "routes to #create" do
      post("/pools").should route_to("pools#create")
    end

    it "routes to #update" do
      put("/pools/1").should route_to("pools#update", :id => "1")
    end

    it "routes to #destroy" do
      delete("/pools/1").should route_to("pools#destroy", :id => "1")
    end

  end
end
