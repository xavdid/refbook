require 'csv'
require 'pp'
require 'parse-ruby-client'

Parse.init :application_id => ENV['REFBOOK_PARSE_APP_ID'],
           :master_key        => ENV['REFBOOK_PARSE_API_KEY'],
           :quiet => true

italians = Parse::Query.new('_User').tap do |q|
  q.eq('region', 'ITAL')
  q.limit = 1000
end.get.map do |x|
  [x['objectId'], {id: x['objectId'], name: "#{x['firstName']} #{x['lastName']}"}]
end.to_h

res = CSV.open("italian_results.csv", 'w+')
res << ['Date', 'Name', 'Test', 'Score', 'Passed?', 'Duration (MM:SS)']

%w(ar sr hr).each do |t|
  data = CSV.open("#{t}_results.csv").read
  # kill bad data
  data.shift(9)
  data.each do |row|
    # score: 2
    # date: 8
    # id: 13
    if italians.include?(row[13])
      res << [row[8], italians[row[13]][:name], t.upcase, row[2], row[2].to_i >= 80 ? true : false, "#{row[5]}:#{row[6]}"]
    end
  end
end

puts 'done'
