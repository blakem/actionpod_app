class UserMailer < ActionMailer::Base
  default :from => "15-Minute Calls <support@15minutecalls.com>"
  
  def conference_email(user, participants)
    @user = user
    @url  = "http://example.com/login"
    mail(:to => user.email,
        :subject => "[15mc] Conference Notes for %{Time.now.strftime('%A %B %d')}")
  end
end
