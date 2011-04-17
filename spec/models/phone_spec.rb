require 'spec_helper'

describe Phone do
  it "has a phone" do
    user = Factory(:user)
    phone = Factory(:phone, :user_id => user.id)
    phone.user.should == user
    phone.primary.should == false
  end
  
  it "should munge your primary phone string into a standard format" do
    user = Factory(:user)
    phone1 = Phone.create(:string => '+14154441234', :user_id => user.id)
    phone1.number.should == '+14154441234'
    phone2 = Phone.create(:string => '4154441234', :user_id => user.id)
    phone2.number.should == '+14154441234'
    phone3 = Phone.create(:string => '415-444-1234', :user_id => user.id)
    phone3.number.should == '+14154441234'
    phone3 = Phone.create(:string => '(415) 444.1234', :user_id => user.id)
    phone3.number.should == '+14154441234'
    phone3.string = '(415) 666.1234'
    phone3.save
    phone3.number.should == '+14156661234'
    phone3.string = 'xyzzy'
    phone3.valid?.should be_false
    phone3.errors[:string].should include("is invalid")
    phone3.string = ''
    phone3.valid?.should be_false
    phone3.errors[:string].should include("can't be blank")
    phone3.number = ''
    phone3.valid?.should be_false
    phone3.errors[:number].should include("can't be blank")
  end
  
end
