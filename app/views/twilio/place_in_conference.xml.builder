xml.instruct!
xml.Response do
    xml.Say "Welcome. On the call today we have #{@names}"
    xml.Dial(:timeLimit => @timelimit) do
      xml.Conference "#{@conference}"
    end
    xml.Say "Time is up. Goodbye."
end
