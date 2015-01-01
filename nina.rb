require 'sinatra'
require 'sinatra/reloader'
require 'slim'

get '/' do
  slim :transfers, :pretty => true
end

get '/tvshows' do
  slim :tvshows
end
