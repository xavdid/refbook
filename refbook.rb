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

def name_maker(person)
  "#{person['firstName']} #{person['lastName']}"
end

get '/' do
  haml :index
end

def admin
end
get '/admin' do
  # this'll list links to important stuff
  # also, unique team names to catch typos/etc
  if not logged_in? or not session[:user]['admin']
    flash[:issue] = "Admins only, kid"
    redirect '/'
  else
    @review_list = []
    reviews = Parse::Query.new("review").get

    reviews.each do |r|
      q = Parse::Query.new("_User").eq("objectId",r['referee'].parse_object_id).get.first
      a = [r['reviewerName'], r['reviewerEmail'], r['isCaptain'], r['region'], name_maker(q), r['team'], r['opponent'], r['rating'], r['comments'], r['show'], r['objectId'], q['objectId']]
      # hide the name of reviews made about you
      if r['referee'].parse_object_id == session[:user]['objectId']
        a[0] = "REDACTED"
        a[1] = "REDACTED"
      end
      @review_list << a
    end

    haml :admin
  end
end

def cm
end
get '/cm' do 
  # TODO: make sure user is logged in (so you can update cookie). 

  # cases:
  #   A: no attempts at all
  #   B: no attempts for this test
  #   C: attempted this test

  attempt_list = Parse::Query.new("testAttempt").eq("taker", params[:cm_user_id]).get
  if attempt_list.empty?
    # A
    att = Parse::Object.new("testAttempt")
    att["taker"] = params[:cm_user_id]
  else
    # C
    att = attempt_list.select do |a|
      a["type"] == params[:cm_return_test_type]
    end
    if att.empty?
      # B
      att = Parse::Object.new("testAttempt")
      att["taker"] = params[:cm_user_id]
    else
      att = att.first
    end
  end

  att["score"] = params[:cm_ts].to_i
  att["percentage"] = params[:cm_tp].to_i
  att["duration"] = params[:cm_td]
  att["type"] = params[:cm_return_test_type]
  att["time"] = Time.now.to_s
  att.save
  pp 'afster'
  pp att
  user_to_update = Parse::Query.new("_User").eq("objectId", params[:cm_user_id]).get.first

  if params[:cm_tp].to_i >= 80
    flash[:issue] = "You passed the #{params[:cm_return_test_type]} ref test, go you!"
    user_to_update[params[:cm_return_test_type].to_s+"Ref"] = true
    user_to_update.save
  else
    flash[:issue] = "You failed, try again in a week!"
  end
  redirect '/'
end

def create
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

get '/info' do 
  haml :info
end

get '/login' do
  haml :login
end

def login
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

def logout
end
get '/logout' do 
  session[:user] = nil
  flash[:issue] = "Successfully logged out!"
  redirect '/'
end

def profile
end
get '/profile' do 
  if not logged_in?
    flash[:issue] = "Log in to see your profile"
    redirect '/'
  else
    @review_list = []

    reviews = Parse::Query.new("review").tap do |q|
      q.eq("referee", Parse::Pointer.new({
        "className" => "_User",
        "objectId"  => session[:user]['objectId']
      }))
    end.get

    reviews.each do |r|
      if r['show']
      # q = Parse::Query.new("_User").eq("objectId",r['referee'].parse_object_id).get.first
      # a = [r['reviewerName'], r['reviewerEmail'], r['isCaptain'], r['region'], name_maker(q), r['team'], r['opponent'], r['rating'], r['comments']]
        a = [r['rating'], r['comments']]
        @review_list << a
      end
    end

    haml :profile
  end
end

def reset
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

def review
end
get '/review' do 
  @region_keys = settings.region_keys.keys[0..settings.region_keys.values.size-3]
  q = Parse::Query.new("_User").get
  @refs = {}

  @region_keys.each do |r|
    @refs[r] = []
  end


  q.each do |person|
    if person["assRef"] or person["snitchRef"]
      # [id, fN + lN]
      p = [person['objectId'], name_maker(person)]

      @refs[reg_reverse(person['region'])] << p
    end
  end

  @refs = @refs.to_json
  haml :review
end

post '/review' do 
  rev = Parse::Object.new('review')
  rev['reviewerName'] = params[:name]
  rev['reviewerEmail'] = params[:email]
  rev['isCaptain'] = params[:captain] ? true : false
  rev['region'] = settings.region_keys[params[:region]]

  p = Parse::Pointer.new({})
  p.class_name = "_User"
  p.parse_object_id = params[:referee]
  rev['referee'] = p

  rev['date'] = params[:date]
  rev['team'] = params[:team]
  rev['opponent'] = params[:opponent]
  rev['rating'] = params[:rating]
  rev['comments'] = params[:comments]

  rev.save

  flash[:issue] = "Thanks for your review!"
  redirect '/review'
  # params.to_s
end

get '/reviews/:review_id' do
  review = Parse::Query.new("review").eq("objectId", params[:review_id]).get.first
  review.to_json
end

def search
end
get '/search/?' do 
  # THIS ASSUMES that all and none are the last two regions, take care
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
    if person["assRef"] or person["snitchRef"]
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
  end

  @refs = @refs.sort_by{|i| i[1]}

  haml :search
end

def settings
end
get '/settings' do 
  haml :settings
end

post '/settings' do 

end

def tests
end
get '/tests/:which' do
  if not logged_in?
    flash[:issue] = "Must log in to test"
    redirect '/'
  end
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

  @good = true

  attempt_list = Parse::Query.new("testAttempt").eq("taker", session[:user]['objectId']).get
  if not attempt_list.empty?
    # at least 1 attempt
    att = attempt_list.select do |a|
      a["type"] == params[:which]
    end
    if not att.empty?
      # they've taken this test sometime
      att = att.first
      # TIME BETWEEN ATTEMPTS
      if Time.now - Time.parse(att['time']) < 30
        @good = false
        @try_unlocked = Time.parse(att['time']) + 30
        @t1 = Time.now
        @t2 = Time.parse(att['time'])
      end
    end
  end

  haml :tests
end

# renders css
get '/styles.css' do
  scss :refbook
end