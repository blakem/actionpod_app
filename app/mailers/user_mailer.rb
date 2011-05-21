class UserMailer < ActionMailer::Base
  include ApplicationHelper
  helper :application
  include PagesHelper
  helper :pages
  
  default :from => "15 Minute Calls <support@15minutecalls.com>"
  
  def conference_email(user, participants, subject = 'default', to = 'default')
    @current_user = user
    @participants = [user] + participants.select{ |p| p.id != user.id }
    date = Time.now
    @date = date.strftime("%A, %B #{date.day.ordinalize}")
    @mailer = true
    subject = "[15mc] Conference Notes for #{@date}" if subject == 'default'
    to = @current_user.email if to == 'default'
    mail(:to => to, :subject => subject)
  end
  
  def member_message(user, sender, message)
    @message_body = message
    mail(
      :to => user.email,
      :subject => "Message from your 15mc buddy: #{sender.name}",
      :from => "#{sender.name} <#{sender.email}>",
    )
  end

  def message_to_blake(message, subject = "Soooper Cool")
    @message = message
    mail(
      :to => 'blakem@15minutecalls.com',
      :subject => subject,
      :from => "Blake Mills <blakem@15minutecalls.com>"
    )
  end
end
