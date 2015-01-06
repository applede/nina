require 'sinatra/base'
# require 'sinatra/reloader'
require 'slim'
require 'json'
require 'data_mapper'

DataMapper::setup(:default, "sqlite3://#{Dir.pwd}/nina.db")

class Settings
  include DataMapper::Resource
  property :id, Serial
  property :tvshow_folder, String
end

DataMapper.finalize
Settings.auto_upgrade!

class Nina < Sinatra::Application
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
    tvshow_folder = app_settings()[:tvshow_folder]
    tvshows = []
    if tvshow_folder && File.directory?(tvshow_folder)
      Dir.entries(tvshow_folder).each do |file|
        tvshows += [{ name: file }] unless file =~ /^\./
      end
    end
    tvshows.to_json
  end

  post '/search_tvshow.json' do
    json = JSON.parse(request.body.read)
    puts json
    ""
  end

  get '/settings.json' do
    app_settings().to_json()
  end

  post '/settings.json' do
    json = JSON.parse(request.body.read)
    tvshow_folder = json["tvshow_folder"]
    if tvshow_folder && File.directory?(tvshow_folder)
      app_settings().update(json)
      ""
    else
      [500, "#{tvshow_folder} does not exist"]
    end
  end

  post '/test_rule.json' do
    json = JSON.parse(request.body.read)
    pattern = json["pattern"]
    kind = json["kind"]
    name = json["name"]
    puts pattern, kind, name
  end

  def app_settings()
    x = Settings.get(1)
    if not x
      x = Settings.create(:tvshow_folder => '~/Downloads/tvshows')
    end
    x
  end

  run! if app_file == $0
end
