class TwilioController < ApplicationController

  def greeting
    respond_to do |format|
        format.xml
    end
  end
end
