ENV['RACK_ENV'] = 'test'
require 'minitest/autorun'
require 'rack/test'

require_relative '../refbook.rb'
include Rack::Test::Methods

class RefbookTest < MiniTest::Test
  def app
    Sinatra::Application
  end
  
  def setup
    @user_cookie = {user: {}}
  end

  def set_en
    @user_cookie[:user].merge!("lang" => "EN")
  end

  def set_fr
    @user_cookie[:user].merge!("lang" => "FR")
  end

  def set_it
    @user_cookie[:user].merge!("lang" => "IT")
  end

  def paid
    @user_cookie[:user].merge!("paid" => true)
  end

  # Test that all pages load and have text in each language

  def test_en_404
    get '/qwere'
    assert last_response.body.include?('exist')
  end

  def test_en_500
    get '/break'
    assert last_response.body.include?('wrong')
  end
  
  def test_en_about
    get '/about'
    assert last_response.body.include?('utilizing')
  end
  
  def test_en_contact
    get '/contact'
    assert last_response.body.include?('shared')
  end
  
  def test_en_create
    get '/create'
    assert last_response.body.include?('correct')
  end
  
  def test_en_faq
    get '/faq'
    assert last_response.body.include?('offered')
  end
  
  def test_en_index
    get '/'
    assert last_response.body.include?('referees around the world')
  end
  
  def test_en_info
    get '/info'
    assert last_response.body.include?('formation')
  end
  
  def test_en_login
    get '/login'
    assert last_response.body.include?('Forgot')
  end
  
  def test_en_pay
    get '/pay'
    assert last_response.body.include?('to make a purchase')
  end
  
  def test_en_public_profile
    get '/profile/NDrskOZtwl'
    assert last_response.body.include?('review for')
  end
  
  def test_en_review
    get '/review'
    assert last_response.body.include?('anonymous')
  end
  
  def test_en_personal_review
    get '/review/NDrskOZtwl'
    assert last_response.body.include?('David')
  end

  def test_en_risk
    get '/risk'
    assert last_response.ok?
  end
  
  def test_en_search
    get '/search/ALL'
    assert last_response.body.include?('currently')

    get '/search/USWE'
    assert last_response.body.include?('David')
  end
  
  def test_en_testing
    get '/testing'
    assert last_response.body.include?('funds for the IRDP')
    assert last_response.body.include?('use to evaluate')
  end

  # french
  def test_fr_404
    set_fr
    get '/qwere'
    assert last_response.body.include?('exist')
  end

  def test_fr_500
    set_fr
    get '/break'
    assert last_response.body.include?('wrong')
  end
  
  def test_fr_about
    set_fr
    get '/about'
    assert last_response.body.include?('utilizing')
  end
  
  def test_fr_contact
    set_fr
    get '/contact'
    assert last_response.body.include?('shared')
  end
  
  def test_fr_create
    set_fr
    get '/create'
    assert last_response.body.include?('correct')
  end
  
  def test_fr_faq
    set_fr
    get '/faq'
    assert last_response.body.include?('offered')
  end
  
  def test_fr_index
    set_fr
    get '/'
    assert last_response.body.include?('referees around the world')
  end
  
  def test_fr_info
    set_fr
    get '/info'
    assert last_response.body.include?('formation')
  end
  
  def test_fr_login
    set_fr
    get '/login'
    assert last_response.body.include?('Forgot')
  end
  
  def test_fr_pay
    set_fr
    get '/pay'
    assert last_response.body.include?('to make a purchase')
  end
  
  def test_fr_public_profile
    set_fr
    get '/profile/NDrskOZtwl'
    assert last_response.body.include?('review for')
  end
  
  def test_fr_review
    set_fr
    get '/review'
    assert last_response.body.include?('anonymous')
  end
  
  def test_fr_personal_review
    set_fr
    get '/review/NDrskOZtwl'
    assert last_response.body.include?('David')
  end

  def test_fr_risk
    set_fr
    get '/risk'
    assert last_response.ok?
  end
  
  def test_fr_search
    set_fr
    get '/search/ALL'
    assert last_response.body.include?('currently')

    get '/search/USWE'
    assert last_response.body.include?('David')
  end
  
  def test_fr_testing
    set_fr
    get '/testing'
    assert last_response.body.include?('funds for the IRDP')
    assert last_response.body.include?('use to evaluate')
  end

  # italian
  def test_it_404
    set_it
    get '/qwere'
    assert last_response.body.include?('exist')
  end

  def test_it_500
    set_it
    get '/break'
    assert last_response.body.include?('wrong')
  end
  
  def test_it_about
    set_it
    get '/about'
    assert last_response.body.include?('utilizing')
  end
  
  def test_it_contact
    set_it
    get '/contact'
    assert last_response.body.include?('shared')
  end
  
  def test_it_create
    set_it
    get '/create'
    assert last_response.body.include?('correct')
  end
  
  def test_it_faq
    set_it
    get '/faq'
    assert last_response.body.include?('offered')
  end
  
  def test_it_index
    set_it
    get '/'
    assert last_response.body.include?('referees around the world')
  end
  
  def test_it_info
    set_it
    get '/info'
    assert last_response.body.include?('formation')
  end
  
  def test_it_login
    set_it
    get '/login'
    assert last_response.body.include?('Forgot')
  end
  
  def test_it_pay
    set_it
    get '/pay'
    assert last_response.body.include?('to make a purchase')
  end
  
  def test_it_public_profile
    set_it
    get '/profile/NDrskOZtwl'
    assert last_response.body.include?('review for')
  end
  
  def test_it_review
    set_it
    get '/review'
    assert last_response.body.include?('anonymous')
  end
  
  def test_it_personal_review
    set_it
    get '/review/NDrskOZtwl'
    assert last_response.body.include?('David')
  end

  def test_it_risk
    set_it
    get '/risk'
    assert last_response.ok?
  end
  
  def test_it_search
    set_it
    get '/search/ALL'
    assert last_response.body.include?('currently')

    get '/search/USWE'
    assert last_response.body.include?('David')
  end
  
  def test_it_testing
    set_it
    get '/testing'
    assert last_response.body.include?('funds for the IRDP')
    assert last_response.body.include?('use to evaluate')
  end

  def test_unpaid
    # telling me about paid content
    # should have affiliate have affiliate register bugger
  end

  def test_paid
    # shouldn't have help
    # should have hidden guides
  end

  def test_up
    get '/'
    assert last_response.ok?
  end

  def test_it_says_hello_world
    get '/', {}, "rack.session" => {user: {"lang" => "FR"}}
    assert last_response.body.include?('Accueil')
  end

  # def test_it_says_hello_to_a_person
    # get '/search/ALL'
    # assert last_response.ok?
  # end
  
end