class_name RoundDifficulty
extends RefCounted
## Interpolated pacing values; the curve uses elapsed round time in seconds.

const STAGES := [
	[0.0, 0.82, 1.05, 1.00],
	[15.0, 0.64, 0.95, 1.04],
	[35.0, 0.48, 0.82, 1.09],
	[50.0, 0.36, 0.75, 1.14],
	[60.0, 0.30, 0.68, 1.20],
]

var throw_interval: float
var flight_time: float
var music_rate: float


func _init(interval: float, flight: float, rate: float) -> void:
	throw_interval = interval
	flight_time = flight
	music_rate = rate


static func at_time(elapsed: float) -> RoundDifficulty:
	# Columns: elapsed seconds, throw interval, flight time, music rate.
	for i in range(1, STAGES.size()):
		var previous: Array = STAGES[i - 1]
		var next: Array = STAGES[i]
		if elapsed <= next[0]:
			var weight := smoothstep(previous[0], next[0], elapsed)
			return RoundDifficulty.new(
				lerpf(previous[1], next[1], weight),
				lerpf(previous[2], next[2], weight),
				lerpf(previous[3], next[3], weight))
	var last: Array = STAGES[-1]
	return RoundDifficulty.new(last[1], last[2], last[3])
