xml.instruct!
xml.Response do
    xml.Say "Welcome."
    xml.Dial(:timeLimit => @timelimit) do
      xml.Conference "#{@conference}"
    end
    xml.Say "Time is up. Goodbye."
end
