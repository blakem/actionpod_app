xml.instruct!
xml.Response do
  xml.Gather(:action => @postto, :numDigits => 1) do
    xml.Say "Hello."
    xml.Say "Please press 1 to join the conference" 
  end
end
