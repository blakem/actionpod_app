xml.instruct!
xml.Response do
    xml.Say "Waiting for the other participants."
    xml.Dial(:timeLimit => @timelimit) do
      xml.Conference "HoldEvent#{@event.id}Pool#{@pool.id}"
    end
    xml.Say "Time is up. Goodbye."
end
