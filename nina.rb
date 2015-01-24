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
  property :pattern, String, :length => 100
  property :action, String
  property :kind, String
  property :name, String
  property :rename, String, :length => 100
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

$test = true
$tvshow_folder = ''

def sh(*args)
  puts args
  if not $test
    pid = spawn(*args)
    Process.wait(pid)
  end
end

def regex_option(pattern)
  if pattern =~ /[A-Z]/
    0
  else
    Regexp::IGNORECASE
  end
end

def renamed(pattern, rename, src)
  if rename.include?('$1')
    src =~ Regexp.new(pattern, regex_option(pattern))
    eval '"' + rename + '"'
  else
    src.sub(Regexp.new(pattern, regex_option(pattern)), rename)
  end
end

def db_error(errors)
  str = ""
  errors.each do |e|
    str += e[0]
  end
  str
end

class Transfer
  attr :id, :status, :name, :full_path, :result, :restart

  def self.from(line)
    id = line[0..3]
    status = line[57..69]
    name = line[70..-1]
    if name && id && status
      id.strip!()
      status.strip!()
      if status == 'Finished'
        return Transfer.new(id, status, name)
      end
    end
    return nil
  end

  def initialize(id, status, name)
    @id = id
    @status = status
    @name = name
    info = `transmission-remote -t #{@id} --info`
    info.split("\n").find_index do |line|
      line =~ /Location: (.+)/
    end
    @folder = $1
    @result = []
    @restart = false
  end

  def apply(rules)
    path = File.join(@folder, @name)
    if File.directory?(path)
      case apply_to_folder(rules, path)
      when :not_found
        return false
      when :retry
        @result = []
        if apply_to_folder(rules, path, true) == :not_found
          return false
        end
      end
    else
      if apply_to(rules, @folder, @name) == :not_found
        return false
      end
    end
    sh("transmission-remote", "-t", id, "--remove")
    sh("rm", "-rf", path)
    return true
  end

  def apply_to_folder(rules, folder, second_try = false)
    Dir.entries(folder).each do |file|
      next if file == '.' || file == '..'
      case apply_to(rules, folder, file, second_try)
      when :not_found
        return :not_found
      when :retry
        return :retry if not second_try
      end
    end
    return :ok
  end

  def apply_to(rules, folder, file, second_try = false)
    index = rules.find_index do |rule|
      file =~ Regexp.new(rule.pattern, regex_option(rule.pattern))
    end
    if index
      r = :ok
      path = File.join(folder, file)
      rule = rules[index]
      dest = ''
      if rule['rename']
        dest = renamed(rule.pattern, rule.rename, file)
      end
      if rule.action == 'copy'
        sh("cp", path, File.join($tvshow_folder, rule.name, dest))
      elsif rule.action == 'unrar'
        if not second_try
          r = :retry
          sh("unrar", "e", "-o+", path, folder)
        end
      end
      @result += [{type:"success", file: file, rule: rule, dest: dest}]
      return r
    else
      @result += [{type:"error", file: file, rule: {}, dest: ''}]
      return :not_found
    end
  end

  def result()
    return { transfer: @name, file_results: @result }
  end
end

class Nina < Sinatra::Application
  attr :trans, :app_settings, :running

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
    set_settings()
    tvshows = []
    if $tvshow_folder && File.directory?($tvshow_folder)
      Dir.entries($tvshow_folder).each do |file|
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
    set_settings().to_json()
  end

  post '/settings.json' do
    json = JSON.parse(request.body.read)
    $tvshow_folder = json["tvshow_folder"]
    if $tvshow_folder && File.directory?($tvshow_folder)
      @app_settings.update(json)
      ""
    else
      [500, "#{$tvshow_folder} does not exist"]
    end
  end

  post '/test_rule.json' do
    json = JSON.parse(request.body.read)
    tid = json["tid"]
    pattern = json["pattern"]
    kind = json["kind"].strip
    name = json["name"]
    result = {ok: false, action: "No match"}
    set_trans_list()
    set_settings()
    @trans.each do |tran|
      puts tran
      if tran[:id] == tid
        puts tran[:name]
        if tran[:name] =~ /#{pattern}/
          result = {ok: true, action: "copy to #{$tvshow_folder}/#{name}"}
        end
        break
      end
    end

    puts tid, pattern, kind, name
    result.to_json()
  end

  def run_rules(test)
    $test = test
    return [] if @running
    @running = true
    set_settings()
    rules = Rules.all()
    result = []
    lines = `transmission-remote --list`
    lines.split("\n").each do |line|
      transfer = Transfer.from(line)
      if transfer
        applied = transfer.apply(rules)
        result += [transfer.result()]
        break if not applied
      end
    end
    @running = false
    return result
  end

  get '/test_run' do
    run_rules(true).to_json()
  end

  get '/run' do
    run_rules(false).to_json()
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
    elsif action == 'copy'
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
        result = {id:-1, error:db_error(rule.errors)}
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
        result = {id:-1, error:db_error(rule.errors)}
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

  def set_settings()
    if not @app_settings
      @app_settings = Settings.get(1)
      if not @app_settings
        @app_settings = Settings.create(:tvshow_folder => '~/Downloads/tvshows')
      end
      $tvshow_folder = @app_settings.tvshow_folder
    end
  end

  run! if app_file == $0
end
