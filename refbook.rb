require 'sinatra'
require 'json'
require 'mongo'
require 'sass'
require 'parse-ruby-client'
require 'haml'
require 'sinatra/flash'

include Mongo

configure do
  enable :sessions
  set :session_secret, 'this_is_secret'

  Parse.init :application_id => '7Wm6hqr7ij43PkytuISZAO0dIAr8JJtkDlJVClox',
           :master_key        => 'PMmErBeV7KbgPN7XcZXG2qbcYkLzs1Er6gpzs0Jx'

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
  @team_list = []
  teams = Parse::Query.new("_User").tap do |team|
    team.exists("Team")
  end.get
  teams.each do |t|
    @team_list << t["Team"]
  end
  @team_list = @team_list.to_set.to_a
  puts @team_list
  haml :create
end

post '/create' do
    user = Parse::User.new({
    # username is actually email, secretly
    :username => params[:username],
    :password => params[:password],
    :assRef => false,
    :snitchRef => false,
    :headRef => false,
    :admin => false,
    :team => params[:team].split(/(\W)/).map(&:capitalize).join
  })
  begin
    session[:user] = user.save
    redirect '/'
  rescue
    flash[:issue] = "Try an original name, dummy"
    redirect '/create'
  end
end

get '/tests' do
  @type = params[:test]
  haml :tests
end

get '/grade' do
  @test = params[:test]
  if params[:pass] == 'true'
    @pass = true
    session[:user][@test+'Ref'] = true
    session[:user] = session[:user].save
  else
    @pass = false
  end

  haml :grade
  # parse stuff
end

# get '/admin' do
  # this'll list links to important stuff
  # also, unique team names to catch typos/etc
# end

get '/login' do
  # session[:user] = {username: 'david', team: 'michigan'}

  # redirect '/'
  haml :login
end

post '/login' do
  begin
    session[:user] = Parse::User.authenticate(params[:username], params[:password])
    redirect '/'
  rescue
    flash[:issue] = "Invalid login credientials"
    redirect '/login'
  end
  
end

get '/logout' do 
  session[:user] = nil
  redirect '/'
end

# renders css
get '/styles.css' do
  scss :refbook
end