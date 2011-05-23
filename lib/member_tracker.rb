class MemberTracker
  def contact_stranded_members
    User.all.each do |user|
      if user.events.empty? and user.answered_count == 0 and user.created_at < Time.now - 2.days
        send_email_once(user, 'next_steps')
      end
    end
  end
  
  def send_email_once(user, type)
    return if MemberMail.find_by_user_id_and_email_type(user.id, type)
    if type == 'next_steps'
      UserMailer.member_next_steps(user).deliver
    end
    MemberMail.create!(:user_id => user.id, :email_type => type, :sent_at => Time.now)
  end
end