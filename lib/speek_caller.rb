class SpeekCaller
  def api_key
    'r7442fvnyvyhrpf7b7j5gmx9'
  end
  
  def base_url
    'http://api.speek.com'
  end

  def post_to_speek(url, args)
    Net::HTTP.post_form(URI.parse(url), args)
  end

  def api_url(string='callNow')
    base_url + "/calls/#{string}"
  end

  def start_call_for_event(event)
    post_to_speek(api_url, {
      :api_key => api_key,
      :description => event.name,
      :numbers => event.user.primary_phone.number_plain,
      :format => 'json',
    })
  end

  def add_event_to_call(event, call_id)
    post_to_speek(api_url('addParticipant'), {
      :api_key => api_key,
      :call_id => call_id,
      :numbers => event.user.primary_phone.number_plain,
      :format => 'json',
    })
  end

  def start_call_for_events(events)
    post_to_speek(api_url, {
      :api_key => api_key,
      :description => events[0].name,
      :numbers => events.map{|e| e.user.primary_phone.number_plain}.join(','),
      :format => 'json',
    })
  end

end