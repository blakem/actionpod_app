class MemberTracker
  def contact_stranded_members
    User.all.each do |user|
      if user.events.empty? and user.placed_count == 0 and user.created_at < Time.now - 2.days
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

  def send_team_focus_email(date)
    user1 = User.find_by_email('blakem@15minutecalls.com')
    user2 = User.find_by_email('tommy2hats@gmail.com')
    user3 = User.find_by_email('damian@damiansol.com')
    user4 = User.find_by_email('touchbrian@gmail.com')
    date_string = date.strftime("%A, %B #{date.day.ordinalize}")
    UserMailer.conference_email(
      user1,
      [user1, user2, user3, user4], 
      "Team Focus Lists for #{date_string}",
      'deltachallenge-team-focus@googlegroups.com',
      'Blake Mills <blakem30@yahoo.com>',
    ).deliver
  end
end