package ritual

import "core:time"

Weekday :: time.Weekday
Repeat :: bit_set[Weekday]

EVERY_DAY :: Repeat{.Sunday, .Monday, .Tuesday, .Wednesday, .Thursday, .Friday, .Saturday}

// Time_Of_Day is a wall-clock time as an offset since midnight (0 ..< 24h).
// Distinct from time.Duration so a time-of-day can't be mixed with a length.
Time_Of_Day :: distinct time.Duration

Ritual :: struct {
	name:        string,
	description: string,
	start:       Time_Of_Day, // time of day, see parse_time
	end:         Time_Of_Day, // time of day, see parse_time
	repeat:      Repeat,
	steps:       [dynamic]string,
}
