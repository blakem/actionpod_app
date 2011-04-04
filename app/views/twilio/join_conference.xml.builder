xml.instruct!
xml.Response do
    xml.Say "Joining a conference room for #{@timelimit} minutes"
    xml.Dial(:timeLimit => @timelimit) do
      xml.Conference "MyRoom"
    end
end
