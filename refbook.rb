require 'sinatra'
require 'json'
require 'mongo'
require 'sass'
require 'parse-ruby-client'
require 'haml'
require 'sinatra/flash'
require 'pp'
require 'time'
require 'mail'
require 'rack-google-analytics'

include Mongo

configure do
  enable :sessions
  set :session_secret, 'this_is_secret'
  set :region_hash, {"US West" => "USWE", "US Midwest" => "USMW", "US Southwest" => "USSW", "US South" => "USSO", "US Northeast" => "USNE", "US Mid-Atlantic" => "USMA", "Canada" => "CANA", "Oceania" => "OCEA", "Italy" => "ITAL", "All Regions" => "ALL","None" => "NONE"}
  set :region_names, ["US West", "US Midwest", "US Southwest", "US South", "US Northeast", "US Mid-Atlantic", "Canada", "Oceania", "Italy"]
  set :region_codes, ["USWE", "USMW", "USSW", "USSO", "USNE", "USMA", "CANA", "OCEA", "ITAL"]

  Parse.init :application_id => ENV['REFBOOK_PARSE_APP_ID'],
           :master_key        => ENV['REFBOOK_PARSE_API_KEY']

  if settings.development?
    # this is so we can test on multiple local computers
    set :bind, '0.0.0.0'
  else
    require 'newrelic_rpm'
  end

  Mail.defaults do
    delivery_method :smtp, { 
      :address   => "smtp.sendgrid.net",
      :port      => 587,
      :domain    => "refdevelopment.com",
      :user_name => ENV['SENDGRID_USERNAME'],
      :password  => ENV['SENDGRID_PASSWORD'],
      :authentication => 'plain',
      :enable_starttls_auto => true 
    }
  end

  use Rack::GoogleAnalytics, :tracker => 'UA-42341849-2'
end

# helpers

def logged_in?
    session[:user] != nil
end

def reg_reverse(reg)
  settings.region_hash.select do |k, v|
    v == reg
  end.keys.first
end

def name_maker(person)
  "#{person['firstName']} #{person['lastName']}"
end

def to_bool(str)
  str.downcase == 'true' || str == '1'
end

def display(path = request.path_info[1..-1], layout = true)
  if layout
    haml "#{@lang}/#{path}".to_sym, layout: "#{@lang}/layout".to_sym
  else
    haml "#{@lang}/#{path}".to_sym, layout: false
  end
end

def email_results(email, pass, score, unlock)
  mail = Mail.deliver do
    to email
    from 'IRDP <beamneocube@gmail.com>'
    subject 'Referee Test Results'
    text_part do
      if pass
        body "You passed with a score of #{score}! Why don't you give the snitch test a go?\n\nHope to hear from you soon!"
      else
        body "Unfortunately, you didn't pass the test (you got a score of #{score}). Take a week to think about the test and give it another go at #{unlock} (US Eastern Time)."
      end
    end
  end
end

not_found do
  display(404, false)
end

error 500 do
  display(500,false)
end

# kill switch
def before
end
before do 
  @killed = false
  if not session[:user].nil?
    @lang = session[:user]['lang']
  else
    @lang = "EN"
  end
  if @killed and !['/off','/styles.css'].include? request.path_info
    redirect '/off'
  end
end


# routes

get '/' do
  @title = "Home"
  # haml "#{@lang}/index".to_sym, layout: "#{@lang}/layout".to_sym
  display :index
end

def admin
end
get '/admin' do
  @title = "Admin"
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
      a = [
        r['reviewerName'], #0
        r['reviewerEmail'], #1
        r['isCaptain'], #2
        r['region'], #3
        name_maker(q), #4
        r['team'], #5
        r['opponent'], #6
        r['rating'], #7
        r['comments'], #8
        r['show'], #9
        r['objectId'], #10
        q['objectId'], #11
        r['now'] #12
      ]
      # hide the name of reviews made about you
      if r['referee'].parse_object_id == session[:user]['objectId']
        a[0] = "REDACTED"
        a[1] = "REDACTED"
      end
      @review_list << a
    end

    # haml "#{@lang}/admin".to_sym, layout: "#{@lang}/layout".to_sym
    display
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

  if not params.include? 'cm_user_id'
    flash[:issue] = "Error, no user ID. If you feel like you've reached this in error, contact an administrator"
    redirect '/'
  end

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

  user_to_update = Parse::Query.new("_User").eq("objectId", params[:cm_user_id]).get.first
  @email = session[:user]['email']
  @score = params[:cm_tp]
  puts 'to', @email, @score
  if params[:cm_tp].to_i >= 80
    pass = true
    flash[:issue] = "You passed the #{params[:cm_return_test_type]} ref test, go you!"
    user_to_update[params[:cm_return_test_type].to_s+"Ref"] = true
    session[:user] = user_to_update.save
    @unlock = ''
  else
    pass = false
    @unlock = (Time.parse(att['time']) + 300).strftime('%b %e,%l:%M %p')
    flash[:issue] = "You failed, try again in a week!"
  end
  email_results(@email, pass, @score, @unlock)
  redirect '/'
end

def create
end
get '/create' do
  @title = "Create an account!"
  @team_list = []
  teams = Parse::Query.new("_User").tap do |team|
    team.exists("team")
  end.get
  teams.each do |t|
    @team_list << t["team"]
  end
  @team_list = @team_list.to_set.to_a
  @region_keys = settings.region_names
  # puts @team_list
  display
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
    :attemptsRemaining => 0,
    :passedFieldTest => false,
    :admin => false,
    :lang => params[:lang] || 'EN',
    :firstName => params[:fn].capitalize,
    :lastName => params[:ln].capitalize,
    # the regex titlecases
    :team => params[:team].split(/(\W)/).map(&:capitalize).join,
    # because of dropdown, there shouldn't ever be no region, but this is 
    # just in case. Region errors really break stuff.
    :region => settings.region_hash[params[:region]] || "NONE"
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

def faq
end
get '/faq' do
  @title = "FAQ"
  display
end

def field
end
get '/field/:referee' do 
  ref = Parse::Query.new("_User").eq("objectId", params[:referee]).get.first
  puts ref
  ref['passedFieldTest'] = true
  ref.save
  flash[:issue] = "#{name_maker(ref)} has passed their field test!"
  redirect "/search/#{params[:reg]}"
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

  # haml "#{@lang}/grade".to_sym, layout: "#{@lang}/layout".to_sym
  redirect '/'
end

get '/info' do 
  @title = "Information"
  display
end

get '/login' do
  @title = "Login"
  display
end

def login
end
post '/login' do
  begin
    session[:user] = Parse::User.authenticate(params[:username], params[:password])
    redirect '/'
  rescue
    flash[:issue] = "Invalid login credentials"
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

def off
end
get '/off' do
  if not @killed
    flash[:issue] = "Maintenance is done, carry on!"
    redirect '/'
  else
    # haml "#{@lang}/off".to_sym, layout: false
    display(:off, false)
  end
end

def profile
end
get '/profile' do
  @title = "Profile"
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
    @total = 0
    reviews.each do |r|
      if r['show']
      # q = Parse::Query.new("_User").eq("objectId",r['referee'].parse_object_id).get.first

        a = [r['rating'], r['comments']]
        @review_list << a
        @total += 1
      end
    end

    display
  end
end

get '/profile/:ref_id' do
  @ref = Parse::Query.new('_User').eq("objectId",params[:ref_id]).get.first
  if @ref.nil?
    flash[:issue] = "Profile not found"
    redirect '/search/ALL'
  else
    @title = "#{@ref['firstName']} #{@ref['lastName']}"
    display :public_profile
  end
end

def reset
end
get '/reset' do 
  @title = "Reset Your Password"
  display
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
  @title = "Review a Referee"
  @region_keys = settings.region_names
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
  display
end

post '/review' do 
  rev = Parse::Object.new('review')
  rev['reviewerName'] = params[:name]
  rev['reviewerEmail'] = params[:email]
  rev['isCaptain'] = params[:captain] ? true : false
  rev['region'] = settings.region_hash[params[:region]] || "None"

  p = Parse::Pointer.new({})
  p.class_name = "_User"
  p.parse_object_id = params[:referee] || 'Sb33WyBziN' #hardcoded unnamed ref
  rev['referee'] = p

  rev['date'] = params[:date]
  rev['team'] = params[:team]
  rev['opponent'] = params[:opponent]
  rev['rating'] = params[:rating]
  rev['comments'] = params[:comments]
  # show should be false by default, true for testing
  rev['show'] = true
  rev['now'] = Time.now.strftime('%b %e,%l:%M %p')
  rev.save

  flash[:issue] = "Thanks for your review!"
  redirect '/review'
end

def reviews
end
get '/reviews/:review_id' do
  @title = "Edit a Review"
  if not logged_in? or not session[:user]['admin']
    flash[:issue] = "Admins only, kid"
    redirect '/'
  else
    @r = Parse::Query.new("review").eq("objectId", params[:review_id]).get.first
    q = Parse::Query.new("_User").eq("objectId",@r['referee'].parse_object_id).get.first
    @name = name_maker(q)
    @review = @r.to_json
    display :edit_review
  end
end

post '/reviews/:review_id' do
  r = Parse::Query.new("review").eq("objectId", params[:review_id]).get.first

  r['show'] = to_bool(params[:show])
  r['comments'] = params[:comments]
  r.save

  flash[:issue] = "Review saved, it will #{r['show'] ? "" : "not"} be shown"
  redirect '/admin'
end

def search
end

get '/search/:region' do 
  @title = "Directory by Region"
  @reg = params[:region].upcase
  @region_title = reg_reverse(@reg)

  @region_keys = settings.region_names
  @region_values = settings.region_codes

  if @region_title.nil?
    flash[:issue] = "Invalid region code: #{@reg}"
    redirect '/search'
  end

  if @reg == 'ALL'
    q = Parse::Query.new("_User").get
  else
    q = Parse::Query.new("_User").eq("region",@reg).get
  end

  @refs = []
  q.each do |person|
    if person["assRef"] or person["snitchRef"]
      entry = [
        person["firstName"], 
        person["lastName"], 
        person["team"], 
        person["username"]
      ]
      
      # assignment because reuby returns are weird
      entry << j = person['assRef'] ? 'Y' : 'N'
      entry << j = person['snitchRef'] ? 'Y' : 'N'
      entry << j = person['headRef'] ? 'Y' : 'N'

      
      entry << reg_reverse(person['region']) # 7
      

      entry << person["objectId"] # 8

      entry << j = person['passedFieldTest'] ? 'Y' : 'N' # 9

      @refs << entry
    end
  end
  # @refs << @refs
  # @refs = @refs.sort_by{|i| i[1]}

  display :search
end

def settings
end
get '/settings' do 
  @title = "Settings"
  display
end

post '/settings' do  
  begin
    session[:user]['email'] = params[:username]
    session[:user]['username'] = params[:username]
    session[:user]['lang'] = params[:lang]
    session[:user] = session[:user].save
    flash[:issue] = "Settings sucessfully updated!"
    redirect '/'
  rescue
    session[:user] = Parse::Query.new("_User").eq("objectId",session[:user]['objectId']).get.first
    flash[:issue] = "There was an error (possibly because that email is improperly formatted or already in use by another user). Try again, then contact the administrator."
    redirect '/settings'
  end
end

def testing
end
get '/testing' do
  @title = "Testing Center"
  # right now, which can be anything. Nbd?
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
      # hardcoded - will do actual test discrim later
      a['type'] == 'ass'
      # a["type"] == params[:which]
    end
    if not att.empty?
      # they've taken this test sometime
      att = att.first
      # TIME BETWEEN ATTEMPTS
      # 604800 sec = 1 week
      waiting = 30
      if Time.now - Time.parse(att['time']) < waiting
        @good = false
        @try_unlocked = Time.parse(att['time']) + waiting
        @t1 = Time.now
        @t2 = Time.parse(att['time'])
      end
    end
  end

  display
end

# renders css
get '/styles.css' do
  scss :refbook
end