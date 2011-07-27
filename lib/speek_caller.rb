class SpeekCaller
  def api_key
    'r7442fvnyvyhrpf7b7j5gmx9'
  end
  
  def base_url
    'http://api.speek.com'
  end

  def post_to_speek(string, args)
    Net::HTTP.post_form(URI.parse(api_url(string)), args.merge(
      :api_key => api_key,
    ))
  end

  def api_url(string='')
    base_url + "/calls/#{string}"
  end

  def start_call_for_event(event)
    post_to_speek('callNow', {
      :description => event.name,
      :numbers => event.user.primary_phone.number_plain,
      :format => 'json',
    })
  end

  def add_event_to_call(event, call_id)
    post_to_speek('addParticipant', {
      :call_id => call_id,
      :numbers => event.user.primary_phone.number_plain,
      :format => 'json',
    })
  end

  def start_call_for_events(events)
    post_to_speek('callNow', {
      :description => events[0].name,
      :numbers => events.map{|e| e.user.primary_phone.number_plain}.join(','),
      :format => 'json',
    })
  end
end