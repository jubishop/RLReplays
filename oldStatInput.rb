require 'json'
require 'PP'
require 'sqlite3'

# holds all the stats for one player performance in one game
class Player
  attr_accessor :name, :assists, :goals, :saves, :score, :shots, :teamID
  def initialize(stats)
    @name = stats['Name']['value']['str']
    @assists = stats['Assists']['value']['int']
    @goals = stats['Goals']['value']['int']
    @saves = stats['Saves']['value']['int']
    @score = stats['Score']['value']['int']
    @shots = stats['Shots']['value']['int']
    @teamID = stats['Team']['value']['int']
  end

  def to_h
    [name, self]
  end
end

# holds all the stats about a specific replay
class ReplayStats
  attr_accessor :date, :players, :ourScore, :theirScore
  def initialize(file, date)
    @date = date
    @data = JSON::parse(File.open(file).read)['header']['body']['properties']['value']
    @players = @data['PlayerStats']['value']['array'].map { |stats|
      Player.new(stats['value']).to_h
    }.to_h
    team0Score = @data.has_key?('Team0Score') ? @data['Team0Score']['value']['int'] : 0
    team1Score = @data.has_key?('Team1Score') ? @data['Team1Score']['value']['int'] : 0
    @ourScore, @theirScore = *(self.jubi.teamID == 0 ? [team0Score, team1Score] : [team1Score, team0Score])
  end

  def won?
    @ourScore > @theirScore
  end

  def method_missing(name, *args, &block)
    super unless @players.has_key? name.to_s
    @players[name.to_s]
  end
end


raise "Usage: ruby statInput.rb <replayFolder>" unless ARGV.first
replayFolder = ARGV.first

# clear out old jsonFiles temp directory
system("rm -rf 'jsonFiles/'")
system("mkdir 'jsonFiles'")

# generate json file out of every replay file in given folder
Dir["#{replayFolder}*"].each { |file|
  system("./rattletrap-6.2.2-osx -c < #{file} > jsonFiles/#{File.basename(file, '.replay')}.json")
}

# create a ReplayStats object off every json file generated
gameStats = Dir['./jsonFiles/*'].map { |file|
  replayFile = "#{replayFolder}#{File.basename(file, '.json')}.replay"
  ReplayStats.new(file, File.mtime(replayFile))
}
system("rm -rf 'jsonFiles/'")

# open the db and piipe all the data into it
db = SQLite3::Database.open "oldReplays.db"
wins, losses = 0, 0
gameStats.each { |game|
  game.won? ? wins += 1 : losses += 1
  db.execute "INSERT INTO game(Date, OurScore, TheirScore) " +
    "VALUES(#{game.date.to_i}, #{game.ourScore}, #{game.theirScore})"
  game_id = db.last_insert_row_id
  game.players.each { |name, player|
    command = "INSERT INTO performance(Name, GameID, Assists, Goals, Saves, Score, Shots, OurTeam) " +
      "VALUES(#{name.dump}, #{game_id}, #{player.assists}, #{player.goals}, " +
      "#{player.saves}, #{player.score}, #{player.shots}, " +
      "#{player.teamID == game.jubi.teamID ? 1 : 0})"
    db.execute command
  }
}
db.close

puts "#{wins} wins  /  #{losses} losses"