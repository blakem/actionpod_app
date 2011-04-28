class UserMailer < ActionMailer::Base
  include ApplicationHelper
  helper :application
  include PagesHelper
  helper :pages
  
  default :from => "15-Minute Calls <support@15minutecalls.com>"
  
  def conference_email(user, participants)
    @current_user = user
    @participants = [user] + participants.select{ |p| p.id != user.id }
    @date = Time.now.strftime('%A, %B %d').sub(/ 0/, '')
    @mailer = true
    @next_call_time = @current_user.next_call_time
    @next_call_time = @next_call_time.strftime("%A %I:%M%P").sub(/ 0/,' ').titlecase if @next_call_time    
    mail(:to => @current_user.email, :subject => "[15mc] Conference Notes for #{@date}")
  end
end
