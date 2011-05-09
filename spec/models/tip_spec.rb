require 'spec_helper'

describe Tip do
  it "requires a body" do
    tip = Tip.new
    tip.valid?.should be_false
    tip.errors[:body].should include("can't be blank")
    tip.body = "foobar"
    tip.valid?.should be_true    
  end
end
