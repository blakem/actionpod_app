class UserMailer < ActionMailer::Base
  include ApplicationHelper
  helper :application
  include PagesHelper
  helper :pages
  
  default :from => "15 Minute Calls <support@15minutecalls.com>"
  
  def conference_email(user, participants)
    @current_user = user
    @participants = [user] + participants.select{ |p| p.id != user.id }
    date = Time.now
    @date = date.strftime("%A, %B #{date.day.ordinalize}")
    @mailer = true
    mail(:to => @current_user.email, :subject => "[15mc] Conference Notes for #{@date}")
  end
end
