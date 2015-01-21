require 'sinatra/base'
# require 'sinatra/reloader'
require 'sinatra/config_file'
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

class Rules
  include DataMapper::Resource
  property :id, Serial
  property :pattern, String
  property :action, String
  property :kind, String
  property :name, String
  property :rename, String
end

DataMapper.finalize
Settings.auto_upgrade!
Guids.auto_upgrade!
Trans.auto_upgrade!
Rules.auto_upgrade!

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

class Transfer
  attr :unrar
end

class Nina < Sinatra::Application
  attr :trans, :tvshow_folder

  register Sinatra::ConfigFile
  config_file 'config.yml'

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

  def renamed(pattern, rename, src)
    return src.sub(Regexp.new(pattern, Regexp::IGNORECASE), rename)
  end

  def apply_rule(file, rules, real)
    index = rules.find_index do |rule|
      file =~ Regexp.new(rule.pattern, Regexp::IGNORECASE)
    end
    if index
      rule = rules[index]
      dest = ''
      if rule['rename']
        dest = renamed(rule.pattern, rule.rename, file)
      end
      if real
        if rule.action == 'keep'
          `cp '#{full_path}/#{file}' '#{@tvshow_folder}/#{rule.name}/#{dest}'`
          # puts "cp '#{full_path}/#{file}' '#{@tvshow_folder}/#{rule.name}/#{dest}'"
        elsif rule.action == 'unrar'
          unrar = true
          `unrar e -o+ "#{full_path}/#{file}" "#{full_path}/"`
        end
      end
      return true, unrar, [{type:"success", file: file, rule: rule, dest: dest}]
    else
      return false, false, [{type:"error", file: file, rule: {}, dest: ''}]
    end
  end

  def run_rules(real)
    set_tvshow_folder()
    rules = Rules.all()
    result = []
    lines = `transmission-remote --list`
    lines.split("\n").each do |line|
      Transfer.new(line)
      id = line[0..3]
      status = line[57..69]
      name = line[70..-1]
      if name && id && status
        id.strip!()
        status.strip!()
        if status == 'Finished'
          info = `transmission-remote -t #{id} --info`
          info.split("\n").find_index do |info_line|
            info_line =~ /Location: (.+)/
          end
          full_path = $1 + "/" + name
          files = []
          file_results = []
          unrar = false
          if is_dir = File.directory?(full_path)
            Dir.entries(full_path).each do |file|
              next if file == '.' || file == '..'
              success, unrar, file_result = apply_rule(file, rules, real)
              file_results += [file_result]
              unless success
                result += [{transfer: name, file_results: file_results}]
                return result
              end
              # index = rules.find_index do |rule|
              #   file =~ Regexp.new(rule.pattern, Regexp::IGNORECASE)
              # end
              # if index
              #   rule = rules[index]
              #   dest = ''
              #   if rule['rename']
              #     dest = renamed(rule.pattern, rule.rename, file)
              #   end
              #   if real
              #     if rule.action == 'keep'
              #       `cp '#{full_path}/#{file}' '#{@tvshow_folder}/#{rule.name}/#{dest}'`
              #       # puts "cp '#{full_path}/#{file}' '#{@tvshow_folder}/#{rule.name}/#{dest}'"
              #     elsif rule.action == 'unrar'
              #       unrar = true
              #       `unrar e -o+ "#{full_path}/#{file}" "#{full_path}/"`
              #     end
              #   end
              #   file_results += [{type:"success", file: file, rule: rule, dest: dest}]
              # else
              #   file_results += [{type:"error", file: file, rule: {}, dest: ''}]
              #   result += [{transfer: name, file_results: file_results}]
              #   return result
              # end
            end
            if real
              unless unrar
                `transmission-remote -t #{id} --remove`
                `rm -rf #{full_path}`
                # puts "rm -rf #{full_path}"
              end
            end
          else
            success, unrar, file_result = apply_rule(full_path, rules, real)
            file_results += [file_result]
            unless success
              result += [{transfer: name, file_results: file_results}]
              return result
            end
          end
          result += [{transfer: name, file_results: file_results}]
        end
      end
    end
    return result
  end

  get '/test_run' do
    run_rules(false).to_json()
  end

  get '/run' do
    run_rules(true).to_json()
  end

  def valid_rule(json)
    pattern = json['pattern']
    action = json['action']
    kind = json['kind']
    name = json['name']
    return false unless pattern
    return false unless pattern.length > 0
    return false unless action
    if action == 'ignore'
      return true
    elsif action == 'unrar'
      return true
    elsif action == 'keep'
      return false unless ['tvshow', 'movie', 'porn'].include?(kind)
      return false unless name
      return false unless name.length > 0
      return true
    end
    return false
  end

  post '/add_rule' do
    json = JSON.parse(request.body.read)
    if valid_rule(json)
      rule = Rules.create(json)
      if rule.saved?
        result = rule
      else
        result = {id:-1}
      end
    end
    result.to_json()
  end

  get '/rules' do
    rules = Rules.all()
    rules.to_json()
  end

  post '/rule/:id' do |id|
    json = JSON.parse(request.body.read)
    if valid_rule(json)
      rule = Rules.get(id)
      if rule.update(json)
        result = rule
      else
        result = {id:-1}
      end
    end
    result.to_json()
  end

  post '/test_rule' do
    json = JSON.parse(request.body.read)
    pattern = json['rule']['pattern']
    rename = json['rule']['rename']
    example = json['example']
    result = {dest: ""}
    if pattern && rename && example
      result = {dest: renamed(pattern, rename, example)}
    end
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
            info = `transmission-remote -t #{id} --info`
            location = ''
            info.split("\n").each do |info_line|
              if info_line =~ /Location: (.+)/
                location = $1
                break
              end
            end
            full_path = location + "/" + name
            files = []
            if is_dir = File.directory?(full_path)
              Dir.entries(full_path).each do |file|
                files += [file] unless file[0] == '.'
              end
            end
            @trans += [{id:id, name:name, files:files, is_dir:is_dir, status:status}]
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
