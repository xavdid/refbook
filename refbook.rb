require 'sinatra'
require 'json'
require 'mongo'
require 'sass'
require 'parse-ruby-client'
require 'haml'

include Mongo

configure do
  enable :sessions
  set :session_secret, 'this_is_secret'

  Parse.init :application_id => '7Wm6hqr7ij43PkytuISZAO0dIAr8JJtkDlJVClox',
           :api_key        => 'VzsXMh7mzyuJ6qKToCOZQQrrpd7YRGamzzsnpJVG'

  if settings.development?
    set :env_db, 'localhost:4567'
    # this is so we can test on multiple local computers
    set :bind, '0.0.0.0'
  else
    set :env_db, 'refbook.herokuapp.com'
  end
end

# helpers do

# end

def logged_in?
    session[:user] != nil
    # 'yep'
end

get '/' do
  # if session[:user] == nil
  #   haml :index
  # else
  #   redirect '/nav',303
  # end
  haml :index
end

get '/create' do
  haml :create
end

post '/create' do
    user = Parse::User.new({
    :username => params[:username],
    :password => params[:password],
    :assRef => false,
    :snitchRef => false,
    :headRef => false
  })
  session[:user] = user.save
  redirect '/'
end

get '/login' do
  session[:user] = {username: 'david', team: 'michigan'}

  redirect '/'
end

get '/logout' do 
  session[:user] = nil
  redirect '/'
end

# renders css
get '/styles.css' do
  scss :refbook
end