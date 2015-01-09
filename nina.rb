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

class Trans
  include DataMapper::Resource
  property :id, String, :key => true
  property :name, String
  property :status, String
end

DataMapper.finalize
Settings.auto_upgrade!
Guids.auto_upgrade!
Trans.auto_upgrade!

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

# puts tvshow_exist?("The Big Bang Theory")

class Nina < Sinatra::Application
  attr :trans, :tvshow_folder

  get '/' do
    # send_file File.expand_path('index.html', settings.public_folder)
    slim :home, :pretty => true
  end

  get '/transfers.json' do
    set_trans_list()
    # content_type :json
    @trans.to_json
  end

  get '/tvshows.json' do
    set_tvshow_folder()
    tvshows = []
    if @tvshow_folder && File.directory?(@tvshow_folder)
      Dir.entries(@tvshow_folder).each do |file|
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
    @tvshow_folder = json["tvshow_folder"]
    if @tvshow_folder && File.directory?(@tvshow_folder)
      app_settings().update(json)
      ""
    else
      [500, "#{@tvshow_folder} does not exist"]
    end
  end

  post '/test_rule.json' do
    json = JSON.parse(request.body.read)
    tid = json["tid"]
    pattern = json["pattern"]
    kind = json["kind"].strip
    name = json["name"]
    result = {ok: false, action: "No match"}
    # trans = Trans.all()
    set_trans_list()
    set_tvshow_folder()
    @trans.each do |tran|
      puts tran
      if tran[:id] == tid
        puts tran[:name]
        if tran[:name] =~ /#{pattern}/
          result = {ok: true, action: "copy to #{@tvshow_folder}/#{name}"}
        end
        break
      end
    end

    puts tid, pattern, kind, name
    result.to_json()
  end

  def app_settings()
    x = Settings.get(1)
    if not x
      x = Settings.create(:tvshow_folder => '~/Downloads/tvshows')
    end
    x
  end

  def set_trans_list()
    if not @trans
      lines = `transmission-remote --list`
      @trans = []
      lines.split("\n").each do |line|
        id = line[0..3]
        status = line[57..69]
        name = line[70..-1]
        if name && id && status
          id.strip!()
          status.strip!()
          if status == 'Finished'
            @trans += [{id:id, name:name, status:status}]
          end
        end
      end
    end
  end

  def set_tvshow_folder()
    if not @tvshow_folder
      @tvshow_folder = app_settings()[:tvshow_folder]
    end
  end

  run! if app_file == $0
end
