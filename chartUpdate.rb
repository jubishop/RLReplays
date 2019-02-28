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

#
# # group data by ID
# gamesByID = games.map { |game| [game.id, game] }.to_h
# performancesByID = performances.group_by {|per| per.gameID}
# epoch = Date.new(1970,1,1)
# gamesByDay = games.group_by { |game| (Time.at(game.date).to_datetime - epoch).to_i }.to_h
# # tally wins/scores based on the game of the session
# sessionStats = []
# gamesByDay.each { |day, session|
#   session.each_index { |game_index|
#     sessionStats[game_index] ||= {"jubi" => 0, "FezTheDispenser" => 0, :games => 0, :wins => 0}
#     sessionStats[game_index][:games] += 1
#     sessionStats[game_index][:wins] += 1 if (session[game_index].ourScore > session[game_index].theirScore)
#     daysPerformances = performancesByID[session[game_index].id]
#     ["jubi", "FezTheDispenser"].each { |name|
#       results = daysPerformances.find{ |performance| performance.name == name}
#       sessionStats[game_index][name] += results.score
#     }
#   }
# }
#
# # tally all the data into a lost and won hash
# winTotals = {"jubi" => Hash.new(0), "FezTheDispenser" => Hash.new(0)}
# lossTotals = {"jubi" => Hash.new(0), "FezTheDispenser" => Hash.new(0)}
# performances.each { |performance|
#   if (["jubi", "FezTheDispenser"].include? performance.name)
#     thisGame = gamesByID[performance.gameID]
#     tempTotals = thisGame.ourScore > thisGame.theirScore ? winTotals : lossTotals
#     tempTotals[performance.name][:assists] += performance.assists
#     tempTotals[performance.name][:goals] += performance.goals
#     tempTotals[performance.name][:saves] += performance.saves
#     tempTotals[performance.name][:score] += performance.score
#     tempTotals[performance.name][:shots] += performance.shots
#   end
# }
#
# # sum the loss and win totals together into generic totals hash
# totals = Hash[winTotals.map { |key, total|
#   [key, Hash[total.map { |attrib, val| [attrib, val + lossTotals[key][attrib]] }]]
# }]
#
#
# # count our win/loss ratio
# wonGames, lostGames = 0, 0
# games.each { |game|
#   if (game.ourScore > game.theirScore)
#     wonGames += 1
#   else
#     lostGames += 1
#   end
# }
# puts "#{wonGames} wins, #{lostGames} lost"
#
# # rows and columns to store data in Numbers spreadsheet
# rows = {"jubi" => 2, "FezTheDispenser" => 3}
# columns = {:score => "B", :goals => "C", :saves => "D", :assists => "E", :shots => "G"}
# trendColumns = {:games => "E", :wins => "F", "jubi" => "A", "FezTheDispenser" => "B"}
#
# # update the chart with everything
# osascript("
# tell application \"Numbers\"
#   activate
#   open \"/Users/jubishop/Desktop/ReplayWork/Charts.numbers\"
#   tell the first table of the first sheet of document 1
#     #{
#       rows.map { |name, row|
#         columns.map { |attribute, column|
#           "set the value of cell \"#{column}#{row}\" to #{totals[name][attribute] / games.size.to_f}"
#         }.join("\n")
#       }.join("\n")
#     }
#   end tell
#   tell the second table of the first sheet of document 1
#     #{
#       rows.map { |name, row|
#         columns.map { |attribute, column|
#           "set the value of cell \"#{column}#{row}\" to #{winTotals[name][attribute] / wonGames.to_f}"
#         }.join("\n")
#       }.join("\n")
#     }
#   end tell
#   tell the third table of the first sheet of document 1
#     #{
#       rows.map { |name, row|
#         columns.map { |attribute, column|
#           "set the value of cell \"#{column}#{row}\" to #{lossTotals[name][attribute] / lostGames.to_f}"
#         }.join("\n")
#       }.join("\n")
#     }
#   end tell
#   tell the fourth table of the first sheet of document 1
#     #{
#       sessionStats.each_with_index.map { |session, gameNumber|
#         trendColumns.map { |attribute, column|
#           "set the value of cell \"#{column}#{gameNumber+2}\" to #{session[attribute]}"
#         }.join("\n")
#       }.join("\n")
#     }
#   end tell
# end tell")