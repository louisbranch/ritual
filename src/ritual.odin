package ritual

import "base:runtime"
import "core:strings"
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
	steps:       [dynamic]string,
}

// ritual_clone deep-copies r's string fields into allocator, so the result is
// independent of the memory backing r.
ritual_clone :: proc(r: Ritual, allocator: runtime.Allocator) -> Ritual {
	c := r
	c.name = strings.clone(r.name, allocator)
	c.description = strings.clone(r.description, allocator)
	c.steps = make([dynamic]string, len(r.steps), allocator)
	for s, i in r.steps do c.steps[i] = strings.clone(s, allocator)
	return c
}

ritual_to_string :: proc(r: Ritual, allocator: runtime.Allocator) -> string {
	hm :: 5 // HH:MM only
	start_buf, end_buf: [time.MIN_HMS_LEN]byte

	start := time.duration_to_string_hms(time.Duration(r.start), start_buf[:])
	end := time.duration_to_string_hms(time.Duration(r.end), end_buf[:])

	return strings.concatenate(
		{"[", start[:hm], " - ", end[:hm], "] ", r.name, ": ", r.description},
		allocator,
	)
}
