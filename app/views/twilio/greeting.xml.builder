xml.instruct!
xml.Response do
  xml.Gather(:action => @postto, :numDigits => 1, :finishOnKey => 1) do
    xml.Say "Hello, welcome to your #{@event_name}."
    xml.Say "Please press 1 to join the conference" 
  end
end
