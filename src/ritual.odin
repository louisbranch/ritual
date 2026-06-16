package ritual

import "base:runtime"
import "core:fmt"
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
	start:       Time_Of_Day, // time of day, see time_parse
	end:         Time_Of_Day, // time of day, see time_parse
	repeat:      Repeat,
	steps:       []string,
}

// ritual_to_string renders the one-line display form shown to the user —
// "[HH:MM - HH:MM] name: description". It is not a full dump of the struct:
// repeat and steps are omitted.
ritual_to_string :: proc(r: Ritual, allocator: runtime.Allocator) -> string {
	start_h, start_m, _ := time.clock_from_duration(time.Duration(r.start))
	end_h, end_m, _ := time.clock_from_duration(time.Duration(r.end))

	if r.description == "" {
		return fmt.aprintf(
			"[%02d:%02d - %02d:%02d] %s",
			start_h,
			start_m,
			end_h,
			end_m,
			r.name,
			allocator = allocator,
		)
	}

	return fmt.aprintf(
		"[%02d:%02d - %02d:%02d] %s: %s",
		start_h,
		start_m,
		end_h,
		end_m,
		r.name,
		r.description,
		allocator = allocator,
	)
}
