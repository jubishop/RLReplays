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

db = SQLite3::Database.open "replays.db"
games = (db.execute "SELECT * from game").map { |game| Game.new(*game) }
gamesByID = games.map { |game| [game.id, game] }.to_h
performances = (db.execute "SELECT * from performance").map { |performance| Performance.new(*performance) }
db.close

totals = {"jubi" => Hash.new(0), "FezTheDispenser" => Hash.new(0)}
performances.each { |performance|
  if (totals.has_key? performance.name)
    totals[performance.name][:assists] += performance.assists
    totals[performance.name][:goals] += performance.goals
    totals[performance.name][:saves] += performance.saves
    totals[performance.name][:score] += performance.score
    totals[performance.name][:shots] += performance.shots
  end
}

rows = {"jubi" => 2, "FezTheDispenser" => 3}
columns = {:score => "B", :goals => "C", :saves => "D", :assists => "E", :shots => "F"}
setString = rows.map { |name, row|
  columns.map { |attribute, column|
    "set the value of cell \"#{column}#{row}\" to #{totals[name][attribute] / games.size.to_f}"
  }.join("\n")
}.join("\n")

osascript("
tell application \"Numbers\"
  activate
  open \"/Users/jubishop/Desktop/ReplayWork/Charts.numbers\"
  tell the first table of the first sheet of document 1
    #{setString}
  end tell
end tell")