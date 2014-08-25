require 'sinatra'
require 'json'
require 'sass'
require 'parse-ruby-client'
require 'haml'
require 'sinatra/flash'
require 'pp'
require 'time'
require 'mail'
require 'rack-google-analytics'
require 'uri'
require 'mongo'
require 'open-uri'
require 'domainatrix'

configure do
  enable :sessions
  
  set :session_secret, 'this_is_secret'
  set :region_hash, {"QuidditchUK" => "QUK","US Northwest" => "USNW","US West" => "USWE", "US Midwest" => "USMW", "US Southwest" => "USSW", "US South" => "USSO", "US Northeast" => "USNE", "US Mid-Atlantic" => "USMA", "Canada" => "CANA", "Australia" => "AUST", "Italy" => "ITAL", "Other" => "OTHR", "All Regions" => "ALL","None" => "NONE"}
  # this is actually a little dumb because it's just lucky that both lists are the first letters and sort the same way. 
  set :region_names, settings.region_hash.keys[0..-3].sort
  set :region_codes, settings.region_hash.values[0..-3].sort
  # TIME BETWEEN ATTEMPTS
  # 604800 sec = 1 week
  set :waiting, 604800
  set :test_names, {ass: "Assistant", snitch: "Snitch", head: "Head", sample: "Sample"}
  set :updated_at, Time.now.utc
  set :time_string, '%e %B, %l:%M%P'
  # world clock string format
  set :wc_string, '%Y%m%dT%H%M'

  set :killed, false

  # mongo is just for registration codes
  set :conn, Mongo::MongoClient.from_uri(ENV['KINECT_URI'])
  set :keys, settings.conn.db('kinect')['refbook_keys']

  Parse.init :application_id => ENV['REFBOOK_PARSE_APP_ID'],
           :master_key        => ENV['REFBOOK_PARSE_API_KEY']

  if settings.development?
    # this is so we can test on multiple local computers
    set :bind, '0.0.0.0'
  # else
    # require 'newrelic_rpm'
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

  # use Rack::GoogleAnalytics, :tracker => 'UA-42341849-2'
end

# helpers

# returns true if and only if the user is logged in
def logged_in?
  session[:user] != nil
end

def admin?
  logged_in? and session[:user]['admin']
end

def paid?
  logged_in? and session[:user]['paid']
end

def affiliate?
  logged_in? and ["QUK", "AUS"].include? session[:user]['region']
end
# gets the nice name from the key
# passing "USMW" returns "US Midwest"
# I don't love this system and may redo it
def reg_reverse(reg)
  settings.region_hash.select do |k, v|
    v == reg
  end.keys.first
end

# given a person (parse) object, returns their full name
def name_maker(person)
  "#{person['firstName']} #{person['lastName']}"
end

def pull_user(id=nil)
  uid = id || session[:user]['objectId']
  Parse::Query.new("_User").eq("objectId", uid).get.first
end

# originally created to ease the transition between js bools and 
# ruby bools, I'm not sure if I need it anymore
def to_bool(str)
  str.downcase == 'true' || str == '1'
end

def validate(key, region)
  begin
    # pull from mongo
    keys = settings.keys.find_one

    #re-format just in case
    key.gsub!('-','')
    key.insert(9,'-')
    key.insert(6,'-')
    key.insert(4,'-')


    if keys[region].include? key
      keys[region].delete key
      settings.keys.save(keys)
      return true
    else
      return false
    end
  rescue Exception => e
    puts 'VALIDATION ERROR'
    puts key
    puts region
    puts e
    return false
  end
end

# IMPORTANT
# renders the view and layout in the correct language
# views are in the following setup:
# /views
# |-- /EN
#   |--a.haml
#   |--b.haml
# |-- /FR
#   |--a.haml
#   |--b.haml
# 
# and so forth for all language codes available
# (which will probably be [EN|FR|IT|ES])
def display(path = request.path_info[1..-1], layout = true)
  if settings.development?
    if layout
      haml "#{@lang}/#{path}".to_sym, layout: "#{@lang}/layout".to_sym
    else
      haml "#{@lang}/#{path}".to_sym, layout: false
    end
  else
    # begin
      if layout
        haml "#{@lang}/#{path}".to_sym, layout: "#{@lang}/layout".to_sym
      else
        haml "#{@lang}/#{path}".to_sym, layout: false
      end
    # rescue
      # redirect '/logout'
    # end
  end
end

# EMAIL FUNCTIONS #

# For whatever reason, we need the mail gem in it's own little function
# this is just for test results, could add other message stuff
def email_results(email, pass, test)
  mail = Mail.deliver do
    to email
    from 'IRDP <irdp.rdt@gmail.com>'
    subject 'Referee Test Results'
    html_part do
      body "Hey there!<br><br>The IRDP has received and recorded your results. You can see your #{pass ? 'other testing opporunities' : 'cooldown timer'} on the <a href=\"http://refdevelopment.com/testing/#{pass ? '' : test}\">testing page</a>.<br><br>Thank you for choosing the International Referee Development Program for your referee training needs.<br><br>Until next time,<br><br>~the IRDP<br><br>"
    end
  end
end

def register_purchase(text)
  mail = Mail.deliver do 
    to "trigger@ifttt.com"
    from 'beamneocube@gmail.com'
    subject text
    html_part do 
      body "asdf"
    end
  end
end

def notify_of_review(reviewee)
  mail = Mail.deliver do 
    to reviewee
    from 'IRDP <irdp.rdt@gmail.com>'
    subject "You've been reviewed!"
    html_part do 
      body "Hey there!<br><br>Someone has written a review about you and it's been approved (or recently edited) by an IRDP RDT member. Head over to your <a href=\"http://refdevelopment.com/profile\">profile</a> to read it!<br><br>~the IRDP<br><br>"
    end
  end
end

def report_bad(user_id)
  mail = Mail.deliver do
    to 'beamneocube@gmail.com'
    from 'IRDP <irdp.rdt@gmail.com>'
    subject 'Someone submitted a test early!'
    html_part do
      body "User #{user_id} just tried to finish a test before the alotted amount of time. Check it out!"
    end
  end
end

def weekly_testing_update()
  # some nice email styling
  td_start = '<td style="background-color: white; padding: 3px;">'
  table_start = '<table style="width: 800px; background-color: darkgray;">'

  body_text = "These are all of the people who have attempted an IRDP test in the past week. An 80% is required to pass.
    <br><br>
    #{table_start}
      <tr>
      #{td_start}<strong>Name</strong></td>
      #{td_start}<strong>Type</strong></td>
      #{td_start}<strong>Percentage</strong></td>
      #{td_start}<strong>Time (UTC)</strong></td>
      </tr>"
  begin
    user_dump = Parse::Query.new("_User").eq('region','QUK').get
    users = {}
    user_dump.each do |u|
      users[u['objectId']] = name_maker(u)
    end

    test_dump = Parse::Query.new("testAttempt").tap do |q|
      q.greater_than("createdAt", Parse::Date.new((Time.now - 604800).to_datetime))
    end.get
    tests = []

    test_dump.each do |t|
      if users.include? t['taker']
        body_text += "<tr>#{td_start}#{users[t['taker']]}</td>
          #{td_start}#{settings.test_names[t['type'].to_sym]}</td>
          #{td_start}#{t['percentage']}%</td>
          #{td_start}#{Time.parse(t['updatedAt']).strftime(settings.time_string)}</td>
          </tr>"
      end
    end

    body_text += "</table><br><br>If you've got any questions, reach out to David at david@relateiq.com.<br><br> ~IRDP"

    mail = Mail.deliver do
      # to 'beamneocube@gmail.com'
      to 'gameplay@quidditchuk.org'
      from 'IRDP <irdp.rdt@gmail.com>'
      subject 'Weekly Test Result Update'
      html_part do 
        content_type 'text/html; charset=UTF-8'
        body body_text
      end
    end

    return 1
  rescue
    return nil
  end
end

# Rendering helpers
def email_link(a={})
  if a.include? :subject
    @subject = URI.encode("?subject=#{a[:subject]}")
  else
    @subject = ''
  end

  if a.include? :text
    @text = a[:text]
  else
    @text = 'irdp.rdt@gmail.com'
  end
  haml :email_link
end

def local_time(time, message='', text=nil)
  @time = time
  @message = message
  @text = text || 'UTC'
  haml :local_time
end

def paypal_button
  @id = session[:user]['objectId']
  if session[:user]['region'] == 'AUST'
    display('AU_paypal', false)
  elsif session[:user]['region'] == 'QUK'
    display('QU_paypal', false)
  else
    display('US_paypal', false)
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
  if settings.development?
    # this is the local switch
    @killed = settings.killed
  else
    # this is the production (live) switch
    @killed = settings.killed
  end

  # so we never have a null language
  if logged_in?
    @lang = session[:user]['lang']
  else
    @lang = "EN"
  end

  # admins can use site even when it's locked
  if not admin?
    if @killed and !['/layout','/login','/logout','/release','/paid','/styles.css', '/off'].include? request.path_info
      redirect '/off'
    end
  end

  # subdomain redirection
  if not settings.development?
    url = Domainatrix.parse(request.url)
    if url.subdomain.size > 0
      redirect 'http://refdevelopment.com'+url.path
    end
  end

  # pp request

end

# routes
def index 
end
get '/' do
  @title = {"EN" => "Home", "FR" => "Page d'Accueil"}[@lang]
  @section = "index"
  display :index
end

def about
end
get '/about' do
  @title = {"EN" => "About the IRDP", "FR" => "Infos"}[@lang]
  @section = "info"
  display
end


# it would be nice to be able to download all of this info as a CSV
def admin
end
get '/admin' do
  @title = "Admin"
  if not logged_in?
    redirect '/login?d=/admin'
  elsif not admin?
    flash[:issue] = "Admins only"
    redirect '/'
  else
    @review_list = []
    reviews = Parse::Query.new("review").get

    reviews.each do |r|
      # THIS WAS POORLY THOUGHT OUT 
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
        r['now'], #12
        r['type'] #13
      ]
      # hide the name of reviews made about you
      if r['referee'].parse_object_id == session[:user]['objectId']
        a[0] = "REDACTED"
        a[1] = "REDACTED"
      end
      @review_list << a
    end

    display
  end
end

def cm
end
get '/cm' do 
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
    end.first
    if not att
      # B
      att = Parse::Object.new("testAttempt")
      att["taker"] = params[:cm_user_id]  
    else
      if Time.now.utc - Time.parse(att['time']) < settings.waiting - 500
        flash[:issue] = "I'm not sure how you took the test again so quicky, but it's possible that your results weren't recoreded. Check your status on the relevant testing page, then email david@relateiq.com for more info."
        report_bad(att['taker'])
        redirect '/'
      end
    end

  end

  att["score"] = params[:cm_ts].to_i
  att["percentage"] = params[:cm_tp].to_i
  att["duration"] = params[:cm_td]
  att["type"] = params[:cm_return_test_type]
  att["time"] = Time.now.utc.to_s
  att.save

  user_to_update = pull_user(params[:cm_user_id])

  @email = user_to_update['email']
  @score = params[:cm_tp]
  puts 'to', @email, @score
  if params[:cm_tp].to_i >= 80
    pass = true
    flash[:issue] = "You passed the #{settings.test_names[params[:cm_return_test_type].to_sym]} ref test, go you!"
    user_to_update[params[:cm_return_test_type].to_s+"Ref"] = true
    session[:user] = user_to_update.save
  else
    pass = false
    flash[:issue] = "You were unsuccessful in your attempt. Try again in a week!"
  end
  email_results(@email, pass, params[:cm_return_test_type]) if not settings.development?
  redirect '/' if pass
  redirect "/testing/#{params[:cm_return_test_type]}"
end

def contact
end
get '/contact' do
  @title = "Contact the IRDP"
  @section = "info"

  display
end

def create
end
get '/create' do
  @title = "Create an Account!"
  @team_list = []
  teams = Parse::Query.new("_User").tap do |team|
    team.exists("team")
  end.get
  teams.each do |t|
    @team_list << t["team"]
  end
  @team_list = @team_list.to_set.to_a
  @region_keys = settings.region_names
  display
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
    :hrWrittenAttemptsRemaining => 0,
    :passedFieldTest => false,
    :admin => false,
    :paid => validate(params[:code],settings.region_hash[params[:region]]),
    :lang => params[:lang] || 'EN',
    :firstName => params[:fn].capitalize,
    :lastName => params[:ln].capitalize,
    :team => params[:team],
    # because of dropdown, there shouldn't ever be no region, but this is 
    # just in case. Region errors really break stuff.
    :region => settings.region_hash[params[:region]] || "NONE"
  })


  begin
    session[:user] = user.save
    flash[:issue] = "Account creation successful - #{session[:user]['paid'] ? '' : 'non'}paid version"
    redirect '/'
  rescue
    # usually only fails for invalid email, but it could be other stuff
    # may way to rescue specific parse errors
    flash[:issue] = "Email already in use (or invalid)"
    redirect back
  end
end

def faq
end
get '/faq' do
  @title = "FAQ"
  @section = "info"
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

def info
end
get '/info' do 
  @title = {"EN" => "Information", "FR" => "Infos"}[@lang]
  @section = 'info'
  display
end

# def leagues
# end
# get '/leagues' do
#   @title = 'Affiliate Leagues'
#   @section = 'info'
#   display
# end

def lock
end
get '/lock' do
  if params[:code] != ENV['REFBOOK_LOCK_CODE']
    flash[:issue] = 'Invalid Code'
    redirect '/'
  else
    settings.killed = true
  end
  "Successful locked at #{Time.now} - #{settings.killed}"
end

def login
end
get '/login' do
  @title = "Login"
  display
end

post '/login' do
  begin
    session[:user] = Parse::User.authenticate(params[:username], params[:password])
    session.options[:expire_after] = 2592000 # 30 days
    redirect params[:d]
  rescue
    flash[:issue] = "Invalid login credentials"
    redirect "/login?d=#{params[:d]}"
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
    # flash[:issue] = "Maintenance is done, carry on!"
    redirect '/'
  else
    display(:off, false)
  end
end

def pay
end
get '/pay' do
  @title = 'Purchase an IRDP Membership!'
  if logged_in?
    @id = session[:user]['objectId']
  end
  display
end

def paid
end
# get ca$h get m0ney
post '/paid' do
  id = params["custom"].split('|')[0].split('=')[1]
  type = params["custom"].split('|')[1].split('=')[1]
  # unnamed ref payments don't count
  if id == 'Sb33WyBziN'
    return {status: 200, message: "ok"}.to_json
  end
  user_to_update = Parse::Query.new("_User").eq("objectId", id).get.first
  # puts params
  if type == 'hr'
    user_to_update['hrWrittenAttemptsRemaining'] = 4
  elsif type == 'ac'
    user_to_update['paid'] = true
  else
    halt 500
  end
  user_to_update.save
  register_purchase("#irdp #{user_to_update['firstName']} #{user_to_update['lastName']} ||| #{type} ||| #{user_to_update['objectId']} ||| #{user_to_update['region']}")
  return {status: 200, message: "ok"}.to_json
end

def profile
end
get '/profile' do
  @title = {"EN" => "Profile", "FR" => "Profil"}[@lang]

  if not logged_in?
    redirect '/login?d=/profile'
  end
  @review_list = []

  reviews = Parse::Query.new("review").tap do |q|
    q.eq("referee", Parse::Pointer.new({
      "className" => "_User",
      "objectId"  => session[:user]['objectId']
    }))
  end.get

  # count reviews
  @total = 0
  @counts = {'excellent'=> 0, 'good' => 0, 'average' => 0, 'poor' => 0}
  reviews.each do |r|
    if r['comments'].size == 0
      @counts[r['rating']] += 1
    elsif r['show']
      a = [r['rating'].capitalize, r['comments'], settings.test_names[r['type'].to_sym]]
      @review_list << a
      @total += 1
    end
  end

  @url = session[:user]['profPic'] ? 
    session[:user]['profPic'] : '/images/person_blank.png'
  display
end

get '/profile/:ref_id' do
  @ref = Parse::Query.new('_User').eq("objectId",params[:ref_id]).get.first
  if @ref.nil?
    flash[:issue] = "Profile not found"
    redirect '/search/ALL'
  else
    @title = "#{@ref['firstName']} #{@ref['lastName']}"
    @url = @ref['profPic'] ? @ref['profPic'] : '/images/person_blank.png'

    display :public_profile
  end
end

def pull
end
get '/pull' do 
  if not logged_in? 
    flash[:issue] = "Must be logged in to refresh"
    redirect '/login?d=/pull'
  else
    session[:user] = pull_user
    flash[:issue] = "User object sucessfully updated"
    redirect '/'
  end
end

def qr
end
get '/qr' do
  @title = "QR"
  if not logged_in?
    redirect '/login?d=/qr'
  end
  u = "http://refdevelopment.com/review/#{session[:user]['objectId']}"
  @review_qr = "https://chart.googleapis.com/chart?cht=qr&chs=300x300&chl=#{URI::encode(u)}"
  display(:qr, false)
end

def refresh
end
get '/refresh' do
  # just to make sure we beat the paypal ping
  sleep(2.5) 
  session[:user] = Parse::Query.new("_User").eq("objectId", session[:user]['objectId']).get.first
  flash[:issue] = 'Payment confirmed. Thank you! You may need to logout and back in to register the upgrade.'
  redirect '/'
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
    redirect back
  end
end

def release
end
get '/release' do 
  # this isn't display because all the languages are already there
  # it could be updated if we add a language we didn't press release in
  haml :'EN/release', layout: false
end

def report
end
# this is a post so it'll play nice with IFTTT
# could eventually take in a region code so that this will work for anyone
get '/report' do 
  good = weekly_testing_update
  if good
    {status: 200}.to_json
  else
    {status: 500}.to_json
  end
end

def review
end
get '/review' do 
  @title = "Review a Referee"
  @section = 'review'

  @region_keys = settings.region_names
  @region_codes = settings.region_codes
  q = Parse::Query.new("_User").get
  @refs = {}

  @region_codes.each do |r|
    @refs[r] = []
  end


  q.each do |person|
    # you can only review if they've got some sort of cert
    if person["assRef"] or person["snitchRef"]
      # [id, fN + lN]
      p = [person['objectId'], name_maker(person)]

      @refs[person['region']] << p
    end
  end

  @refs = @refs.to_json
  display
end

get '/review/:id' do 
  @ref = Parse::Query.new("_User").eq("objectId", params[:id]).get.first
  halt 404 if @ref.nil?

  @url = @ref['profPic'] ? 
      @ref['profPic'] : '/images/person_blank.png'

  @title = "Review #{@ref['firstName']} #{@ref['lastName']}"
  @region_keys = settings.region_names
  # this is included so there's no error because of a missinv variable
  @refs = {}
  display :review
end

post '/review' do 
  rev = Parse::Object.new('review')
  rev['reviewerName'] = params[:name]
  rev['reviewerEmail'] = params[:email]
  rev['isCaptain'] = params[:captain] ? true : false
  rev['region'] = params[:region] || "None"

  p = Parse::Pointer.new({})
  p.class_name = "_User"
  # the correct user_id or hardcoded Unnamed Ref
  p.parse_object_id = params[:referee] || "Sb33WyBziN"

  rev['referee'] = p
  rev['type'] = params[:type]

  rev['date'] = params[:date]
  rev['team'] = params[:team]
  rev['opponent'] = params[:opponent]
  rev['rating'] = params[:rating]
  rev['comments'] = params[:comments]
  # show should be false by default, true for testing
  rev['show'] = false
  rev['now'] = Time.now.utc.strftime(settings.time_string)
  rev.save

  flash[:issue] = "Thanks for your review!"
  redirect back
end

def reviews
end
get '/reviews' do 
  @title = 'Reviews'
  @num = Parse::Query.new("review").get.size
  case @num
  when 0..10
    @text = "Well, everyone has to start somewhere!"
  when 11..30
    @text = "We're off to a great start, let's keep this going strong!"
  when 31..49
    @text = "We're charging up the hill to halfway. Let's get there!"
  when 50..65
    @text = "Halfway! That was easy mode, let's knock the rest of these out"
  when 66..90
    @text = "We're on the home stretch. Can we do it!?"
  when 91..99
    @text = "Knock knock knockin' on 100's door. Who's going to be lucky #100?"
  when 100..300
    @text = "We did it! We've crossed into 100 reviews!"
  end
  display
end

get '/reviews/:review_id' do
  @title = "Edit a Review"
  if not admin?
    # still using old bounce because there's no way someone is linking
    # right to this page. hopefully.
    flash[:issue] = "Admins only, kid"
    redirect '/'
  else
    @r = Parse::Query.new("review").eq("objectId", params[:review_id]).get.first
    q = Parse::Query.new("_User").eq("objectId",@r['referee'].parse_object_id).get.first
    @name = name_maker(q)
    pp @r
    pp session[:user]['objectId']
    @r['reviewerName'] = 'REDACTED' if @r['referee'].parse_object_id == session[:user]['objectId']
    @review = @r.to_json
    display :edit_review
  end
end

post '/reviews/:review_id' do
  r = Parse::Query.new("review").eq("objectId", params[:review_id]).get.first
  reviewee = Parse::Query.new("_User").eq("objectId",r['referee'].parse_object_id).get.first['email']
  r['show'] = to_bool(params[:show])
  r['comments'] = params[:comments]

  notify_of_review(reviewee) if r['show']
  
  r.save

  
  
  flash[:issue] = "Review saved, it will #{r['show'] ? "" : "not"} be shown"
  redirect '/admin'
end

def search
end
get '/search/:region' do 
  @title = "Directory by Region"
  @section = 'search'

  @reg = params[:region].upcase
  @us = @reg[0..1] == 'US'
  @region_title = reg_reverse(@reg)
  
  @region_values = settings.region_codes.reject{|p| p[0..1] == "US"}
  @region_keys = []
  @region_values.each{|r| @region_keys << reg_reverse(r)}

  @us_region_values = settings.region_codes.select{|p| p[0..1] == "US"}
  @us_region_keys = []
  @us_region_values.each do |r| 
    r = reg_reverse(r)
    @us_region_keys << r[2..r.size] 
  end
  
  # if @region_title.nil?
    # halt 404
  # end

  if @reg == 'ALL'
    q = Parse::Query.new("_User").get
  elsif @reg == "USQ"
    q = Parse::Query.new("_User").get.select{|p| p['region'][0..1] == "US"}
  else
    q = Parse::Query.new("_User").eq("region",@reg).get
  end

  @refs = []
  # build each row of the table
  q.each do |person|
    if person["assRef"] or person["snitchRef"]
      entry = [
        person["firstName"], # 0
        person["lastName"], # 1
        person["team"], # 2
        person["username"] # 3
      ]
      
      # assignment because reuby returns are weird
      entry << j = person['assRef'] ? 'Y' : 'N' # 4
      entry << j = person['snitchRef'] ? 'Y' : 'N' # 5
      entry << j = person['headRef'] ? 'Y' : 'N' # 6

      
      entry << reg_reverse(person['region']) # 7
      

      entry << person["objectId"] # 8

      entry << j = person['passedFieldTest'] ? 'Y' : 'N' # 9

      @refs << entry
    end
  end

  display :search
end

def settings
end
get '/settings' do 
  if not logged_in?
    redirect '/login?d=/settings'
  end
  @title = "Settings"
  display
end

post '/settings' do  
  begin
    if params.include? 'tests'
      if params.include? 'ar'
        session[:user]['assRef'] = true 
      else
        session[:user]['assRef'] = false
      end
      if params.include? 'sr'
        session[:user]['snitchRef'] = true 
      else
        session[:user]['snitchRef'] = false
      end
      if params.include? 'hr'
        session[:user]['headRef'] = true 
      else
        session[:user]['headRef'] = false
      end
      if params.include? 'ft'
        session[:user]['passedFieldTest'] = true 
      else
        session[:user]['passedFieldTest'] = false
      end
    else
      session[:user]['email'] = params[:username]
      session[:user]['username'] = params[:username]
      session[:user]['lang'] = params[:lang]
    end
    session[:user] = session[:user].save
    flash[:issue] = "Settings sucessfully updated!"
    redirect '/'
  rescue
    session[:user] = Parse::Query.new("_User").eq("objectId",session[:user]['objectId']).get.first
    flash[:issue] = "There was an error (possibly because that email is improperly formatted or already in use by another user). Try again, then contact the administrator if the problem persists."
    redirect '/settings'
  end
end

def testing
end
get '/testing' do
  @title = "Testing Information Center"
  @section = 'testing'
  display
end

get '/testing/:which' do
   #   find all test attempts from that user id, find the (single) type attempt, 
  #   then, update it with most recent attempt (and Time.now) for comparison.
  #   If they pass, display the link for the relevant test(s). When they finish, 
  #   update the relevent test entry wtih the most recent test

  if not logged_in?
    flash[:issue] = "Must log in to test"
    redirect "/login?d=/testing/#{params[:which]}"
  end

  @title = "#{settings.test_names[params[:which].to_sym]} Referee Test"
  @section = 'testing'
  # right now, which can be anything. Nbd?
  
  if !["head", "snitch", "ass", "sample"].include? params[:which]
    halt 404
  end

  # why do computation if they've alreayd passed?
  display :test_links if session[:user][params[:which]+"Ref"]

  @good = true
  @attempts_remaining = true
  @prereqs_passed = true

  if session[:user]['region'] == "AUST"
    # rulebook 7!
    @tests = {ass: 'ap953ab5d46d258b', snitch: "yqc53ab5e83e8128", head: "6b953ab5f5bbd1c4", sample: "xnj533d065451038"}
    @rb = 7
  else
    # rulebook 8!
    @tests = {ass: 'jmk53c853467f7c6', snitch: "6kr53c853f4914d8", head: "qjp53c854a5530ff", sample: "xnj533d065451038"}
    @rb = 8.0
  end
  
  # refresh user object
  if params[:which] == 'head'
    session[:user] = Parse::Query.new("_User").eq("objectId", session[:user]['objectId']).get.first

    if session[:user]['hrWrittenAttemptsRemaining'] <= 0
      @attempts_remaining = false
    end

    if not session[:user]['assRef'] or not session[:user]['snitchRef']
      @prereqs_passed = false
    end
  end
  attempt_list = Parse::Query.new("testAttempt").eq("taker", session[:user]['objectId']).get
  if not attempt_list.empty?
    # at least 1 attempt
    att = attempt_list.select do |a|
      # hardcoded - will do actual test discrim later
      a['type'] == params[:which]
    end
    if not att.empty?
      # they've taken this test sometime
      att = att.first
      
      if Time.now.utc - Time.parse(att['time']) < settings.waiting
        @good = false
        @try_unlocked = Time.parse(att['time']) + settings.waiting
        @t1 = Time.now.utc
        @t2 = Time.parse(att['time'])
      end
    end
  end

  display :test_links
end

def upload
end
post '/upload' do
  photo = Parse::File.new({
    body: IO.read(params[:myfile][:tempfile]),
    local_filename: URI.encode(params[:myfile][:filename]),
    content_type: params[:myfile][:type]
  })

  h = photo.save
  puts h
  session[:user]['profPic'] = photo.url
  session[:user] = session[:user].save
  redirect '/profile'
end

def valid
end
get '/validate' do 
  if validate(params[:code],session[:user]['region'])
    user_to_update = pull_user
    user_to_update['paid'] = true
    session[:user] = user_to_update.save
    flash[:issue] = 'Registration Successful'
    redirect '/'
  else
    flash[:issue] = 'Invalid or already used code'
    redirect '/settings'
  end
end

# renders css
get '/styles.css' do
  scss :refbook
end

