ENV['RACK_ENV'] = 'test'
require 'minitest/autorun'
require 'rack/test'

require_relative '../refbook.rb'
include Rack::Test::Methods

class RefbookTest < MiniTest::Test
  def app
    Sinatra::Application
  end

  # need to call functions test_XXXX
  def test_up
    get '/'
    assert last_response.ok?
  end

  def test_it_says_hello_world
    get '/', {}, "rack.session" => {user: {"lang" => "FR"}}
    assert last_response.body.include?('Accueil'), 'body had wrong text'
  end

  # def test_it_says_hello_to_a_person
    # get '/search/ALL'
    # assert last_response.ok?
  # end
  
end