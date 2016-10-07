
require 'parse-ruby-client'
require 'dotenv'
require 'csv'

Dotenv.load

Parse.init :application_id => ENV['REFBOOK_PARSE_APP_ID'],
           :master_key        => ENV['REFBOOK_PARSE_API_KEY'],
           :quiet => true

csv = CSV.open('canadians.csv', 'wb+')
csv << ['Name', 'HR', 'SR', 'AR']

Parse::Query.new('_User').tap do |u|
  # u.limit = 1000
  # u.skip = 1000
  u.eq('region', 'CANA')
end.get.each do |u|
  if u['rb8Ass'] || u['rb8Snitch']
    csv << [
      "#{u['firstName']} #{u['lastName']}",
      u['rb8Head'],
      u['rb8Snitch'],
      u['rb8Ass']
    ]
  end

  # ['Ass', 'Snitch', 'Head'].each do |t|
    # u["rb8#{t}"] = u["#{t.downcase}Ref"]
    # u["#{t.downcase}Ref"] = false
  # end

  # u['region'] = 'QNL'
  # u['passedFieldTest'] = false

  # u.save
  # puts "saved #{u['firstName']} #{u['lastName']}"
end

csv.close
