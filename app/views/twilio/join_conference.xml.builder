xml.instruct!
xml.Response do
    xml.Say "Joining a conference room."
    xml.Dial(:timeLimit => 15) do
      xml.Conference "MyRoom"
    end
    xml.Say "Time is up. Goodbye."
end
