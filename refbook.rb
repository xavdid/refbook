require 'sinatra'
require 'json'
require 'mongo'
require 'sass'
require 'parse-ruby-client'
require 'haml'

include Mongo

configure do
  # conn = MongoClient.from_uri(ENV['KINECT_URI'])
  # set :mongo_connection, conn
  # set :mongo_collection, conn.db('kinect')['db_cookie']
  # set :cookie, {}
  # set :user, {}
  enable :sessions
  set :session_secret, 'this_is_secret'

  Parse.init :application_id => '7Wm6hqr7ij43PkytuISZAO0dIAr8JJtkDlJVClox',
           :api_key        => 'VzsXMh7mzyuJ6qKToCOZQQrrpd7YRGamzzsnpJVG'
  # set_cookie
  # settings.dict[:cookie] = settings.mongo_collection.find_one
  if settings.development?
    set :env_db, 'localhost:4567'
    # this is so we can test on multiple local computers
    set :bind, '0.0.0.0'
  else
    set :env_db, 'refbook.herokuapp.com'
  end
end

get '/' do
  # if session[:user] == nil
  #   haml :index
  # else
  #   redirect '/nav',303
  # end
  haml :index
end