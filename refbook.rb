require 'sinatra'
require 'json'
require 'mongo'
require 'sass'
require 'parse-ruby-client'
require 'haml'
require 'sinatra/flash'
require 'pp'
require 'time'

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
  @region_keys = settings.region_keys.keys
  # puts @team_list
  haml :create
end

post '/create' do
    # could have lastAss, lastHead, lastSnitch to enforce retake time
    # also, i'll check CM, but we may want to store all of the attempts for our records
  user = Parse::User.new({
    # username is actually email, secretly
    :username => params[:username],
    :password => params[:password],
    :email => params[:username],
    :assRef => false,
    :snitchRef => false,
    :headRef => false,
    :passedFieldTest => false,
    :admin => false,
    :firstName => params[:fn].capitalize,
    :lastName => params[:ln].capitalize,
    # the regex titlecases
    :team => params[:team].split(/(\W)/).map(&:capitalize).join,
    # because of dropdown, there shouldn't ever be no region, but this is 
    # just in case. Region errors really break stuff.
    :region => settings.region_keys[params[:region]] || "NONE"
    # :last_ass => T
  })

  begin
    session[:user] = user.save
    flash[:issue] = "Account creation successful"
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

get '/tests/:which' do
  # tests table (probably needed) will have the following rows:
  #   taker: (objectId of test taker)
  #   type: ass|head|snitch
  #   score: int
  #   percentage: int
  #   duration?: h-m-s (can probably convert to second/Time value
  #   ^ mostly for interesting stat purposes
  #   time: Time.now.to_s

  #   find all test attempts from that user id, find the (single) type attempt, 
  #   then, update it with most recent attempt (and Time.now) for comparison.
  #   If they pass, display the link for the relevant test(s). When they finish, 
  #   update the relevent test entry wtih the most recent test

  # p = Parse::Query.new("testAttempt",{taker: '7ZELn11laF'}).tap do |att|
    # att.type == params[:which]
    # att.type == 'ass'
  # end.get

#   if not p.empty?
#     if Time.now - Time.parse(p.first["time"]) > 604800

#     else
#       flash[:issue] = "It hasn't been long enough since your last attempt"
#   end

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

get '/cm' do 
  # FIX - should update most recent user's test of that type with new time, not
  # not make a new one

  # TODO: make sure user is logged in (so you can update cookie). 
  p = {}
  p = Parse::Query.new("testAttempt").eq("taker", params[:cm_user_id]).get
  # there's at least one attempty by this person
  if p.empty?
    p = Parse::Object.new("testAttempt")
    p["taker"] = params[:cm_user_id]
  end

  p["score"] = params[:cm_ts].to_i
  p["percentage"] = params[:cm_tp].to_i
  p["duration"] = params[:cm_td]
  p["type"] = params[:cm_return_test_type]
  p["time"] = Time.now.to_s
  p.save

  pp p
  user_to_update = Parse::Query.new("_User").eq("objectId", params[:cm_user_id]).get.first

  if params[:cm_tp].to_i > 80
    flash[:issue] = "You passed the #{params[:cm_return_test_type]} ref test, go you!"
    user_to_update[params[:cm_return_test_type].to_s+"Ref"] = true
    user_to_update.save
  else
    flash[:issue] = "You failed, try again in a week!"
  end
  redirect '/'
end

# get '/admin' do
  # this'll list links to important stuff
  # also, unique team names to catch typos/etc
# end

get '/search' do 
  @region_keys = settings.region_keys.keys[0..settings.region_keys.values.size-3]
  @region_values = settings.region_keys.values[0..settings.region_keys.values.size-3]
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
      entry = [person["firstName"], person["lastName"], 
        person["team"], person["username"]]
      
      # assignment because reuby returns are weird
      entry << j = person['assRef'] ? 'Y' : 'N'
      entry << j = person['snitchRef'] ? 'Y' : 'N'
      entry << j = person['headRef'] ? 'Y' : 'N'

      if params[:region] == 'ALL'
        entry << reg_reverse(person['region'])
      end

      @refs << entry
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