xml.instruct!
xml.Response do
    xml.Say "Joining a conference room"
    xml.Dial do
      xml.Conference "MyRoom"
    end
end
