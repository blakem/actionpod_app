require 'spec_helper'

describe Conference do
  it "can save to the database" do
    Conference.create!
  end
end
