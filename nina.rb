require 'sinatra'
require 'sinatra/reloader'
require 'slim'
require 'json'

get '/' do
  # send_file File.expand_path('index.html', settings.public_folder)
  slim :transfers, :pretty => true
end

get '/transfers.json' do
  lines = `transmission-remote --list`
  puts lines
  list = []
  lines.split("\n").each do |line|
    id = line[0..3]
    status = line[57..69]
    name = line[70..-1]
    if name != nil && id.to_i != 0
      list += [{id:id, name:name, status:status}]
    end
  end
  content_type :json
  list.to_json
end

get '/tvshows.json' do
  [].to_json
end

post '/search_tvshow.json' do
  puts params
  ""
end