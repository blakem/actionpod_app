require 'spec_helper'

describe Preference do
  before(:each) do
    @user = Factory(:user)
    @other_user = Factory(:user, :email => Factory.next(:email))  
    @attr = { :other_user_id => @other_user.id, :prefer_more => true }
  end
  
  it "should create a new instance with valid attributes" do
    @user.preferences.create!(@attr)
  end
  
  describe "preference methods" do
  
    before(:each) do
      @preference = @user.preferences.create!(@attr)
    end
    
    it "should have an user attribute" do
      @preference.should respond_to(:user)
    end
  
    it "should have the right user" do
      @preference.user.should == @user
    end
  
    it "should have an other_user attribute" do
      @preference.should respond_to(:other_user)
    end
    
    it "should have the right other_user" do
      @preference.other_user.should == @other_user
    end   

    it "should have a prefer_more attribute" do
      @preference.should respond_to(:prefer_more)
    end
    
    it "should have the right value for prefer_more" do
      @preference.prefer_more.should == true
    end   
  end
  
  describe "validations" do
  
    it "should require a user_id" do
      Preference.new(@attr).should_not be_valid      
    end
  
    it "should require an other_user_id" do
      @user.preferences.build.should_not be_valid
    end
    
    it "should require a prefer_more flag" do
      @attr.delete(:prefer_more)
      Preference.new(@attr).should_not be_valid      
    end    
  end
  
  describe "preference_string method" do
    it "should have a string method that returns 'prefers' or 'avoids'" do
      preference = Preference.new(@attr.merge({:user_id => @user.id}))
      preference.preference_string.should == 'prefers'
      preference.prefer_more = false
      preference.preference_string.should == 'avoids'      
    end
  end
end
