
require 'parse-ruby-client'
require 'dotenv'

Dotenv.load

Parse.init :application_id => ENV['REFBOOK_PARSE_APP_ID'],
           :master_key        => ENV['REFBOOK_PARSE_API_KEY'],
           :quiet => true

Parse::Query.new('_User').tap do |u|
  u.limit = 1000
  u.skip = 1000
  # u.exists('rb8Head', false)
end.get.each do |u|
  # ['Ass', 'Snitch', 'Head'].each do |t|
    # u["rb8#{t}"] = u["#{t.downcase}Ref"]
    # u["#{t.downcase}Ref"] = false
  # end

  if u['hrWrittenAttemptsRemaining'] > 0
    u['hrWrittenAttemptsRemaining'] = 0
    u.save
    puts "saved #{u['firstName']} #{u['lastName']}"
  end

  # u['rb8Field'] = u['passedFieldTest']
  # u['passedFieldTest'] = false

  # u.save
  # puts "saved #{u['firstName']} #{u['lastName']}"
end
