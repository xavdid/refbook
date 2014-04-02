require 'sinatra'
require 'json'
require 'mongo'
require 'sass'
require 'parse-ruby-client'
require 'haml'
require 'sinatra/flash'
require 'pp'

include Mongo

configure do
  enable :sessions
  set :session_secret, 'this_is_secret'
  set :region_keys, {"US West" => "USWE", "US Midwest" => "USMW", "US Southwest" => "USSW", "US South" => "USSO", "US Northeast" => "USNE", "US Mid-Atlantic" => "USMA", "Canada" => "CANA", "Oceania" => "OCEA", "Italy" => "ITAL", "All Regions" => "ALL","None" => "NONE"}

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
end

def reg_reverse(reg)
  settings.region_keys.select do |k, v|
    v == reg
  end.keys.first
end

get '/' do
  haml :index
end

get '/create' do
  @team_list = []
  teams = Parse::Query.new("_User").tap do |team|
    team.exists("team")
  end.get
  teams.each do |t|
    @team_list << t["team"]
  end
  @team_list = @team_list.to_set.to_a
  @region_list = settings.region_keys.keys
  # puts @team_list
  haml :create
end

post '/create' do
    user = Parse::User.new({
    # username is actually email, secretly
    :username => params[:username],
    :password => params[:password],
    :email => params[:username],
    :assRef => false,
    :snitchRef => false,
    :headRef => false,
    :admin => false,
    :firstName => params[:fn].capitalize,
    :lastName => params[:ln].capitalize,
    # the regex titlecases
    :team => params[:team].split(/(\W)/).map(&:capitalize).join,
    :region => settings.region_keys[params[:region]] || "NONE"
  })

  begin
    session[:user] = user.save
    redirect '/'
  rescue
    # usually only fails for invalid email, but it could be other stuff
    # may way to rescue specific parse errors
    flash[:issue] = "Email already in use (or invalid)"
    redirect '/create'
  end
end

get '/reset' do 
  haml :reset
end

post '/reset' do
  begin
    Parse::User.reset_password(params[:email])
    flash[:issue] = "You have been logged out, log in with new credentials"
    redirect '/logout'
  rescue
    flash[:issue] = "No user with that email"
    redirect '/reset'
  end
end

get '/tests' do
  @type = params[:test]
  haml :tests
end

get '/grade' do
  if params[:pass] == 'true'
    session[:user][@test+'Ref'] = true
    session[:user] = session[:user].save
  end

  if params[:pass] == 'true'
    flash[:issue] = "passed the #{params[:test]} ref test!"
  else
    flash[:issue] = "failed the #{params[:test]} ref test!"
  end

  # haml :grade
  redirect '/'
end

# get '/admin' do
  # this'll list links to important stuff
  # also, unique team names to catch typos/etc
# end

get '/search' do 
  haml :si
end

get '/search/:region' do 

  # could add head/snitch/ass status to class to easily hide/show rows

  @region_title = reg_reverse(params[:region])

  if @region_title.nil?
    flash[:issue] = "Invalid region code: #{params[:region]}"
    redirect '/search'
  end

  if params[:region] == 'ALL'
    q = Parse::Query.new("_User").get
  else
    q = Parse::Query.new("_User").eq("region",params[:region]).get
  end

  @refs = []
  q.each do |person|
      a = [person["firstName"], person["lastName"], 
        person["team"], person["username"]]
      
      # assignment because reuby returns are weird
      a << j = person['assRef'] ? 'Y' : 'N'
      a << j = person['snitchRef'] ? 'Y' : 'N'
      a << j = person['headRef'] ? 'Y' : 'N'

      if params[:region] == 'ALL'
        a << reg_reverse(person['region'])
      end

      @refs << a
  end

  @refs = @refs.sort_by{|i| i[1]}

  haml :search
end

get '/login' do
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
  flash[:issue] = "Successfully logged out!"
  redirect '/'
end

# renders css
get '/styles.css' do
  scss :refbook
end