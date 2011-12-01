require 'rubygems'
require 'bundler/setup'
Bundler.require

#Set Configuration Variables
PermanentAccessToken = ENV["permanent_token"]
LayerID = ENV["layer_id"]
TestUserID = ENV["userid"]
ApplicationURL = "http://trimet4geoloqi.heroku.com/lookup/trimet/"

desc 'Send Trigger Callback'
task :send_callback, :stopid do |t, args|

  stopid = args[:stopid] || 3635

  #In practice you will get more data posted to your application.
  #This is just the minimum amount required to make this work.
  data = {
    "user"=>{
      "user_id"=> TestUserID
    },
    "place"=>{
      "display_name"=> "something",
      "extra"=> {
        "stopid"=> stopid.to_s
      },
    }, 
  }.to_json

  RestClient.post ApplicationURL, data
  puts "POST sent to #{ApplicationURL}, You should recive arrival for Stop ID #{stopid} shortly"
end

desc 'Import places from a GTFS file'
task :import, :path do |t, args|  
  file = File.new(args[:path], 'r')

  #Setup a batch
  batches = {
     access_token: PermanentAccessToken,
     batch: []
  }

  #Loop over each line in the file and push it into the batch
  file.each_line("\n") do |row|
    if file.lineno > 1
      columns = row.split(",")
      batches[:batch] << {
        relative_url: "place/create",
        body: {
          latitude: columns[4],
          longitude: columns[5],
          name: "#{columns[2]} (Stop ID #{columns[0]})",
          layer_id: LayerID,
          description: columns[3],
          radius: columns[2].include?("MAX") ? 25 : 12,
          extra: {
            stopid: columns[0]
          }
        }
      }

      puts "Line No. #{file.lineno} : #{columns[2]} (StopID #{columns[0]})"
    end
  end

  #Post the batch to the server with your permanent token
  #this means the job will not time out
  Geoloqi.post PermanentAccessToken, 'batch/run', batches
  "Batch of #{file.lineno - 1} Places Sent to Geoloqi"
end