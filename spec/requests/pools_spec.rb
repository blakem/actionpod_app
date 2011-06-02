require 'spec_helper'

describe "Pools" do
  describe "GET /pools" do
    it "works! (now write some real specs)" do
      visit pools_path
      response.status.should be(200)
    end
  end
end
