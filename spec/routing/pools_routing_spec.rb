require "spec_helper"

describe PoolsController do
  describe "routing" do

    it "routes to #index" do
      get("/groups").should route_to("pools#index")
    end

    it "routes to #new" do
      get("/groups/new").should route_to("pools#new")
    end

    it "routes to #show" do
      get("/groups/1").should route_to("pools#show", :id => "1")
    end

    it "routes to #edit" do
      get("/groups/1/edit").should route_to("pools#edit", :id => "1")
    end

    it "routes to #create" do
      post("/groups").should route_to("pools#create")
    end

    it "routes to #update" do
      put("/groups/1").should route_to("pools#update", :id => "1")
    end

    it "routes to #destroy" do
      delete("/groups/1").should route_to("pools#destroy", :id => "1")
    end

  end
end
