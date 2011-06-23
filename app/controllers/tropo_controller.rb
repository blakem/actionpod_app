class TropoController < ApplicationController
  def greeting
    t = Tropo::Generator.new
    t.say "Welcome to your call!" 
    render :inline => t.response
  end
end
