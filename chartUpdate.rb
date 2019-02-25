def osascript(script)
  system 'osascript', *script.split(/\n/).map { |line| ['-e', line] }.flatten
end

class Game
  attr_accessor :id, :date, :ourScore, :theirScore
  def initialize(*args)
    @id, @date, @ourScore, @theirScore = *args
  end
  def to_s
    "Game: (id)#{@id}, (date)#{@date}, (ourScore)#{@ourScore}, (theirScore)#{@theirScore}."
  end
end

class Performance
  attr_accessor :id, :gameID, :name, :assists, :goals, :saves, :score, :shots, :ourTeam
  def initialize(*args)
    @id, @gameID, @name, @assists, @goals, @saves, @score, @shots, @ourTeam = *args
  end
  def to_s
    "Performance of #{@name}...game: #{@gameID}, #{@goals} goals, #{@score} total score."
  end
end

require 'sqlite3'

# pull out all the data
db = SQLite3::Database.open "replays.db"
games = (db.execute "SELECT * from game").map { |game| Game.new(*game) }
gamesByID = games.map { |game| [game.id, game] }.to_h
performances = (db.execute "SELECT * from performance").map { |performance| Performance.new(*performance) }
db.close

# tally all the data into a lost and won hash
winTotals = {"jubi" => Hash.new(0), "FezTheDispenser" => Hash.new(0)}
lossTotals = {"jubi" => Hash.new(0), "FezTheDispenser" => Hash.new(0)}
performances.each { |performance|
  if (["jubi", "FezTheDispenser"].include? performance.name)
    thisGame = gamesByID[performance.gameID]
    tempTotals = thisGame.ourScore > thisGame.theirScore ? winTotals : lossTotals
    tempTotals[performance.name][:assists] += performance.assists
    tempTotals[performance.name][:goals] += performance.goals
    tempTotals[performance.name][:saves] += performance.saves
    tempTotals[performance.name][:score] += performance.score
    tempTotals[performance.name][:shots] += performance.shots
  end
}

# sum the loss and win totals together into generic totals hash
totals = Hash[winTotals.map { |key, total|
  [key, Hash[total.map { |attrib, val| [attrib, val + lossTotals[key][attrib]] }]]
}]

# count our win/loss ratio
wonGames, lostGames = 0, 0
games.each { |game|
  if (game.ourScore > game.theirScore)
    wonGames += 1
  else
    lostGames += 1
  end
}
puts "#{wonGames} wins, #{lostGames} lost, total"

# rows and columns to store data in Numbers spreadsheet
rows = {"jubi" => 2, "FezTheDispenser" => 3}
columns = {:score => "B", :goals => "C", :saves => "D", :assists => "E", :shots => "G"}

osascript("
tell application \"Numbers\"
  activate
  open \"/Users/jubishop/Desktop/ReplayWork/Charts.numbers\"
  tell the first table of the first sheet of document 1
    #{
      rows.map { |name, row|
        columns.map { |attribute, column|
          "set the value of cell \"#{column}#{row}\" to #{totals[name][attribute] / games.size.to_f}"
        }.join("\n")
      }.join("\n")
    }
  end tell
  tell the second table of the first sheet of document 1
    #{
      rows.map { |name, row|
        columns.map { |attribute, column|
          "set the value of cell \"#{column}#{row}\" to #{winTotals[name][attribute] / wonGames.to_f}"
        }.join("\n")
      }.join("\n")
    }
  end tell
  tell the third table of the first sheet of document 1
    #{
      rows.map { |name, row|
        columns.map { |attribute, column|
          "set the value of cell \"#{column}#{row}\" to #{lossTotals[name][attribute] / lostGames.to_f}"
        }.join("\n")
      }.join("\n")
    }
  end tell
end tell")