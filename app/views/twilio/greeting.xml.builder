xml.instruct!
xml.Response do
  xml.Gather(:action => @postto, 'numDigits' => '1', 'finishOnKey' => '#') do
    xml.Say "Welcome to your #{@event_name}. Please press 1 to join the conference" 
  end
end
