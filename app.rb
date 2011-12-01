require 'rubygems'
require 'bundler/setup'
Bundler.require

#Setup sinatra/geoloqi
set :geoloqi_client_id,     ENV['geoloqi_client_id']
set :geoloqi_client_secret, ENV['geoloqi_client_secret']
set :geoloqi_redirect_uri,  ENV['geoloqi_redirect_uri']
set :session_secret,        ENV['session_secret']
set :permanent_token,       ENV['permanent_token']

#Set layer_id
set :layer_id,              ENV['layer_id']

#Setup Trimet Variables
set :trimet_app_id,         ENV['trimet_app_id']
set :trimet_base_url,       'http://developer.trimet.org/ws/V1'

#Geoloqi will post information about the place, 
#user, and layer when a user arrives at a place
#See : https://developers.geoloqi.com/api/Trigger_Callback
post '/lookup/trimet/' do
  
  #Create a Hashie::Mash of the JSON post
  body = Hashie::Mash.new(JSON.parse(request.body.string))

  #Use RestClient to get the upcoming arrivals from Trimet
  #See : http://developer.trimet.org/ws_docs/arrivals_ws.shtml
  xml = Nokogiri::XML(RestClient.get "#{settings.trimet_base_url}/arrivals/locIDs/#{body.place.extra.stopid}/appID/#{settings.trimet_app_id}")

  #Holder variables for arrival and stop information
  arrivals = []
  location = xml.css("location").first()

  #Loop over every upcoming arrival
  xml.css('arrival').each do |arrival| 
    
    #Scheduled (no realtime data) or estimated (realtime data)
    unless arrival["estimated"].nil?
      time = (arrival["estimated"].to_i / 1000).round
      verb = "arrives"
    else
      time = (arrival["scheduled"].to_i / 1000).round
      verb = "scheduled to arrive"
    end
    
    #Calculate Arrival Times
    seconds_to_arrival = (time - Time.now().to_i);
    minutes_to_arrival = (time - Time.now().to_i)/60;

    if (minutes_to_arrival > 1)
      time_to_arrival = "#{minutes_to_arrival} minutes"
    elsif (minutes_to_arrival == 1)
      time_to_arrival = "#{minutes_to_arrival} minute"
    else
      time_to_arrival = "less then a minute"
    end
    
    #Push the arrival time into the array with a time so we can sort it later
    if minutes_to_arrival < 240 
      arrivals.push({
        text: "#{arrival["shortSign"]} #{verb} in #{time_to_arrival}" ,
        time: seconds_to_arrival
      })
    end

  end

  if arrivals.empty?

    #There are no upcoming arrivals but lets tell the user that
    message = Geoloqi.post(settings.permanent_token, 'message/send', {
      :layer_id => settings.layer_id,
      :user_id => body.user.user_id,
      :text => "No arrivals at #{location["desc"]} for the next 4 hours."
    });
    puts "#{message} #{text}"
  
  else
    
    #There are some arrivals sort them time
    arrivals.sort! { |x,y| x[:time] <=> y[:time] }
    
    #Create a string of arrival times
    text = arrivals.slice!(0..2).collect! { |x|
     x[:text] 
    }.join(", ")
    
    #Use your permanent access token to send a message to the 
    #user use Geoloqi.post a instead of geoloqi.post becuase 
    #there is no access token from a logged in user
    Geoloqi.post(settings.permanent_token, 'message/send', {
      :layer_id => settings.layer_id,
      :user_id => body.user.user_id,
      :text => "Arrivals at #{location["desc"]}, #{text}.",
      :url => "http://trimet.org/arrivals/small/tracker?locationID=#{body.place.extra.stopid}"
    });

  end
end