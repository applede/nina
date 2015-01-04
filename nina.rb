require 'sinatra'
require 'sinatra/reloader'
require 'slim'
require 'json'
require 'data_mapper'

DataMapper::setup(:default, "sqlite3://#{Dir.pwd}/nina.db")

class Settings
  include DataMapper::Resource
  property :tvshow_folder, String
end

DataMapper.finalize
Settings.auto_upgrade!

get '/' do
  # send_file File.expand_path('index.html', settings.public_folder)
  slim :home, :pretty => true
end

get '/transfers.json' do
  lines = `transmission-remote --list`
  list = []
  lines.split("\n").each do |line|
    id = line[0..3]
    status = line[57..69]
    name = line[70..-1]
    if name && id && status
      id.strip!()
      status.strip!()
      if status == 'Finished'
        list += [{id:id, name:name, status:status}]
      end
    end
  end
  content_type :json
  list.to_json
end

get '/tvshows.json' do
  [].to_json
end

post '/search_tvshow.json' do
  json = JSON.parse(request.body.read)
  puts json
  ""
end

get '/settings.json' do
  @settings = Settings.all()
  puts @settings
  [].to_json
end

post '/settings.json' do
  json = JSON.parse(request.body.read)
  tvshow_folder = json["tvshow_folder"]
  if tvshow_folder && File.exist?(tvshow_folder)
    ""
  else
    [500, "tvshow_folder #{tvshow_folder} not exist"]
  end
end
