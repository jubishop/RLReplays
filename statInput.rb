require 'json'
require 'PP'
require 'sqlite3'

class String
  def titleize
    split(/(\W)/).map(&:capitalize).join
  end
end

class Game
  attr_accessor :date, :won
  def initialize(*args)
    @date, @won = *args
  end
end

AUTH_KEY = 'DgzegKeRKU4ajZZ9lBXHwx6qUVcZoXzqoDcbBilM'
NAMES = ['jubi', 'FezTheDispenser']

raise "Usage: ruby statInput.rb <replayFolder>" unless ARGV.first
replayFolder = ARGV.first

# open DB
db = SQLite3::Database.open "replays.db"

# cache existing games to skip any dupes
games = (db.execute "SELECT * from game").map { |game| Game.new(*game) }
gamesByDate = games.map { |game| [game.date, game] }.to_h

# gather csv file from ballchasing.com for every new replay file in given folder
Dir["#{replayFolder}*"].each { |file|
  # skip this one if already stored in db
  gameDate = File.mtime(file).to_i
  if (gamesByDate.has_key? gameDate)
    puts "Skipped #{file}"
    next
  end

  # upload Replay to ballchasing and wait for processing
  response = `curl -v -F file=@#{file} -H Authorization:#{AUTH_KEY} https://ballchasing.com/api/v2/upload`
  replayID = JSON::parse(response)['id']
  
  # get and parse CSV file associated with uploaded replay
  containsJubi, tries = false, 0
  while (not containsJubi and tries < 3)
    sleep 5 # need to sleep until we have it
    csv_data = `curl -L http://ballchasing.com/dl/stats/players/#{replayID}/#{replayID}-players.csv`
    containsJubi = csv_data.include? "jubi"
    tries += 1
  end
  raise "Could not fetch csv" if (tries >= 3)

  header, *rows = csv_data.split("\n")
  headers = header.split(';').map { |header| header.titleize }
  playerData = rows.map { |row|
    row.split(';').each_with_index.map { |attribute, index|
      [headers[index], attribute]
    }.to_h
  }
  
  # calculate dates, scores, and winners/losers per game
  ourScore, theirScore = 0, 0
  playerData.each { |player|
    if (NAMES.include? player['Player Name'])
      ourScore += player['Goals'].to_i
    else
      theirScore += player['Goals'].to_i
    end
  }
  wonGame = ourScore > theirScore ? 1 : 0
  
  # store game into db
  puts "Now inserting game with date: #{gameDate}"
  db.execute "INSERT INTO game VALUES(#{gameDate}, #{wonGame})"
  
  # now add all player performances into db
  playerData.each { |player|
    if (NAMES.include? player['Player Name'])
      db.execute "INSERT INTO performance('date', '#{player.keys.join('\',\'')}') " +
        "VALUES(#{gameDate}, '#{player.values.join('\',\'')}')"
    end
  }
  
  puts "Added #{file} with date: #{gameDate}"
}

# close DB
db.close