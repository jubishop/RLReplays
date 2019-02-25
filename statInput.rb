require 'json'
require 'PP'
require 'sqlite3'

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

system("rm -rf 'jsonFiles/'")
system("mkdir 'jsonFiles'")
Dir["#{replayFolder}*"].each { |file|
  system("./rattletrap-6.2.2-osx -c < #{file} > jsonFiles/#{File.basename(file, '.replay')}.json")
}

gameStats = Dir['./jsonFiles/*'].map { |file|
  replayFile = "#{replayFolder}#{File.basename(file, '.json')}.replay"
  ReplayStats.new(file, File.mtime(replayFile))
}

db = SQLite3::Database.open "replays.db"
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

puts "#{wins} wins  /  #{losses} losses"

system("rm -rf 'jsonFiles/'")
db.close