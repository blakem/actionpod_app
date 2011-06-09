class UserMailer < ActionMailer::Base
  include ApplicationHelper
  helper :application
  include PagesHelper
  helper :pages
  
  default :from => "Blake Mills <blakem@15minutecalls.com>"
  
  def conference_email(user, participants, subject = nil, to = nil, from = nil)
    @current_user = user
    @participants = [user] + participants.select{ |p| p.id != user.id }
    date = Time.now
    @date = date.strftime("%A, %B #{date.day.ordinalize}")
    @mailer = true
    subject ||= "[15mc] Conference Notes for #{@date}"
    to ||= @current_user.email
    from ||= "15 Minute Calls <support@15minutecalls.com>"
    mail(
      :to => to, 
      :from => from,
      :subject => subject,
    )
  end
  
  def member_message(user, sender, message)
    @message_body = message
    mail(
      :to => user.email,
      :subject => "Message from your 15mc buddy: #{sender.name}",
      :from => "#{sender.name} <#{sender.email}>",
    )
  end

  def member_invite(user, sender, message, pool)
    @personal_message = message
    @pool = pool
    @user = user
    @sender = sender
    mail(
      :to => user.email,
      :subject => "#{sender.name} has invited to to the group: #{sender.name}",
      :from => "#{sender.name} <#{sender.email}>",
    )
  end

  def message_to_blake(message, subject = "Soooper Cool")
    @message = message
    mail(
      :to => 'blakem@15minutecalls.com',
      :subject => subject,
    )
  end
  
  def member_next_steps(current_user)
    @user = current_user
    @timeslots = build_timeslots(current_user)
    mail(
      :to => current_user.email,
      :subject => '[15mc] Your next step: Sign up for a quick call.',
    )
  end
end
