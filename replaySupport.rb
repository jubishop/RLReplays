require 'date'

AUTH_KEY = 'DgzegKeRKU4ajZZ9lBXHwx6qUVcZoXzqoDcbBilM'

NAMES = [
  'jubi',
  'FezTheDispenser'
]
  
PERFORMANCE_COLUMNS = [
  :id,
  :date,
  :team,
  :name,
  :platform,
  :duration,
  :score,
  :goals,
  :assists,
  :saves,
  :shots,
  :bpm,
  :amount_collected,
  :amount_collected_big_pads,
  :amount_collected_small_pads,
  :count_collected_big_pads,
  :count_collected_small_pads,
  :amount_stolen,
  :amount_stolen_big_pads,
  :amount_stolen_small_pads,
  :count_stolen_big_pads,
  :count_stolen_small_pads,
  :zero_boost_time,
  :avg_speed,
  :total_distance,
  :time_slow_speed,
  :time_boost_speed,
  :time_supersonic_speed,
  :time_on_ground,
  :time_low_in_air,
  :time_high_in_air,
  :avg_distance_to_ball,
  :avg_distance_to_ball_has_possession,
  :avg_distance_to_ball_no_possession,
  :time_behind_ball,
  :time_in_front_of_ball,
  :time_defensive_half,
  :time_offensive_half,
  :time_defensive_third,
  :time_neutral_third,
  :time_offensive_third,
  :demos_inflicted,
  :demos_taken
]

class String
  def titleize
    split(/(\W)/).map(&:capitalize).join
  end
end

class Time
  def to_datetime
    seconds = sec + Rational(usec, 10**6)
    offset = Rational(utc_offset, 60 * 60 * 24)
    DateTime.new(year, month, day, hour, min, seconds, offset)
  end
end

class Game
  attr_accessor :date
  def initialize(*args)
    @date, @won = *args
  end
  def won
    @won == 1
  end
end

def osascript(script)
  system 'osascript', *script.split(/\n/).map { |line| ['-e', line] }.flatten
end