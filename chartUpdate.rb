require 'date'
require 'PP'
require 'sqlite3'

require_relative 'replaySupport.rb'

# TODO: Genericize the hard-coded "jubi" and "FezTheDispenser" logic
# TODO: Manage row size of Trends table automatically

# pull out all the data
db = SQLite3::Database.open "replays.db"
games = (db.execute "SELECT * from game").map { |game| Game.new(*game) }.sort_by{|game| game.date}
performances = (db.execute "SELECT * from performance").map { |performance_array|
  PERFORMANCE_COLUMNS.zip(performance_array).to_h
}
db.close


# group data by ID
gamesByID = games.map { |game| [game.date, game] }.to_h
performancesByID = performances.group_by { |performance| performance[:date] }
epoch = Date.new(1970,1,1) # we use this to clump games by int(days) from epoch
gamesByDay = games.group_by { |game| (Time.at(game.date).to_datetime - epoch).to_i }.to_h

# tally wins and scores based on the game of the session
sessionStats = []
gamesByDay.each { |day, session|
  session.each_index { |game_index|
    # game_index is the # of games deep in each evening's session.
    sessionStats[game_index] ||= (NAMES + [:games, :wins]).each_with_object(0).to_h
    
    # iterate the count of games played total at this time in a session.
    sessionStats[game_index][:games] += 1
    sessionStats[game_index][:wins] += 1 if session[game_index].won
    
    # now get the performances for this date, and add in our scores 
    sessionPerformances = performancesByID[session[game_index].date]
    sessionPerformances.each { |performance| # :name will be jubi and FezTheDispenser
      sessionStats[game_index][performance[:name]] += performance[:score]
    }
  }
}

# tally all the data into a lost and won hash
winTotals = NAMES.map { |name| [name, Hash.new(0)] }.to_h
lossTotals = NAMES.map { |name| [name, Hash.new(0)] }.to_h
performances.each { |performance|
  tempTotals = gamesByID[performance[:date]].won ? winTotals : lossTotals
  tempTotals[performance[:name]][:assists] += performance[:assists]
  tempTotals[performance[:name]][:goals] += performance[:goals]
  tempTotals[performance[:name]][:saves] += performance[:saves]
  tempTotals[performance[:name]][:score] += performance[:score]
  tempTotals[performance[:name]][:shots] += performance[:shots]
}

# sum the loss and win totals together into generic totals hash
totals = winTotals.merge(lossTotals) { |name, winPerf, lossPerf|
  winPerf.merge(lossPerf) { |stat, winVal, lossVal| winVal + lossVal }
}

# count our win/loss ratio
wonGames = games.count { |game| game.won }
lostGames = games.size - wonGames
puts "#{wonGames} wins, #{lostGames} lost"

# rows and columns to store data in Numbers spreadsheet
rows = {"jubi" => 2, "FezTheDispenser" => 3}
columns = {:score => "B", :goals => "C", :saves => "D", :assists => "E", :shots => "G"}
trendColumns = {:games => "E", :wins => "F", "jubi" => "A", "FezTheDispenser" => "B"}

# update the charts with everything
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
  tell the fourth table of the first sheet of document 1
    #{
      sessionStats.each_with_index.map { |session, gameNumber|
        trendColumns.map { |attribute, column|
          "set the value of cell \"#{column}#{gameNumber+2}\" to #{session[attribute]}"
        }.join("\n")
      }.join("\n")
    }
  end tell
end tell")