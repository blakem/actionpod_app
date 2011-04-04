xml.instruct!
xml.Response do
    xml.Say "Joining a conference room."
    xml.Dial(:timeLimit => @timelimit) do
      xml.Conference "MyRoom"
    end
end
