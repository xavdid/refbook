# move australian refs to RB 8 certs

Parse.init :application_id => ENV['REFBOOK_PARSE_APP_ID'],
           :master_key        => ENV['REFBOOK_PARSE_API_KEY'],
           :quiet => true

a = Parse::Query.new("_User").eq("region", "AUST").get

eid = 'wUu1ar2FkF'

tests = 0
users = 0

a.each do |u|
  unless u['objectId'] == eid
    u['assRef'] = false
    u['snitchRef'] = false
    u['headRef'] = false
    u['passedFieldTest'] = false
    u['hrWrittenAttemptsRemaining'] = false

    u.save
    users += 1

    q = Parse::Query.new("testAttempt").eq("taker", u['objectId']).get

    q.each do |t|
      t.parse_delete
      tests += 1
    end
  end
end

puts "Refreshed #{users} users and removed #{tests} test attempts"