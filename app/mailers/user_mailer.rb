class UserMailer < ActionMailer::Base
  default :from => "15-Minute Calls <support@15minutecalls.com>"
  
  def conference_email(user, participants)
    @user = user
    @url  = "http://example.com/login"
    date = Time.now.strftime('%A %B %d').sub(/ 0/, '')
    mail(:to => user.email,
        :subject => "[15mc] Conference Notes for #{date}")
  end
end
