require 'sinatra/base'
# require 'sinatra/reloader'
require 'slim'
require 'json'
require 'data_mapper'
require 'rss'
require 'open-uri'

DataMapper::setup(:default, "sqlite3://#{Dir.pwd}/nina.db")

class Settings
  include DataMapper::Resource
  property :id, Serial
  property :tvshow_folder, String
end

class Guids
  include DataMapper::Resource
  property :guid, String, :key => true
end

DataMapper.finalize
Settings.auto_upgrade!
Guids.auto_upgrade!

def get_rss_torrent(search_term)
  result = []
  url = "http://kickass.so/usearch/#{search_term}/?rss=1"
  open(url) do |rss|
    feed = RSS::Parser.parse(rss)
    result += [{ title: feed.channel.title }]
    feed.items.each do |item|
      if not Guids.first(:guid => item.guid)
        # puts item
        # puts item.guid
        uri = URI(item.enclosure.url)
        file_path = "/tmp/#{item.title}.torrent"
        Net::HTTP.start(uri.host) do |http|
          # puts "get " + uri.path + '?' + uri.query
          resp = http.get(uri.path + '?' + uri.query)
          if resp.code == '302'
            uri = URI.escape(resp.header['location'], "[]")
            # puts uri
            open(file_path, "wb") do |file|
              file << open(uri).read
            end
            Guids.create(:guid => item.guid)
          else
            puts "not moved"
          end
        end
      end
    end
  end
  result
end

def get_rss(search_term)
  result = []
  url = "http://kickass.so/usearch/#{search_term}/?rss=1"
  open(url) do |rss|
    feed = RSS::Parser.parse(rss)
    feed.items.each do |item|
      result += [{title: item.title}]
    end
  end
  return result.to_json()
end

def cache(url)
end

def tvshow_exist?(series_name)
  escaped = URI.escape(series_name)
  url = "http://thetvdb.com/api/GetSeries.php?seriesname=#{escaped}"
  doc = Nokogiri::XML(open(url))
  series_names = doc.css("SeriesName")
  if series_names.length > 0 && series_names[0].content == series_name
    return true
  else
    return false
  end
end

puts tvshow_exist?("The Big Bang Theory")

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
    search_term = json['search_term']
    if search_term
      search_term = URI.escape(search_term)
      # puts search_term
      return get_rss(search_term)
    else
      return [].to_json()
    end
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
