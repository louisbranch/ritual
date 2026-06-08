package tests

import "core:testing"
import "core:time"

import ritual "../src"

@(test)
test_time_parse :: proc(t: ^testing.T) {
	Case :: struct {
		input: string,
		want: ritual.Time_Of_Day,
		err:  ritual.Ritual_Field_Error,
	}

	cases := []Case {
		// valid
		{"06:30", ritual.Time_Of_Day(6 * time.Hour + 30 * time.Minute), .None},
		{"00:00", 0, .None},
		{"23:59", ritual.Time_Of_Day(23 * time.Hour + 59 * time.Minute), .None},

		// wrong shape
		{"", 0, .Invalid_Format},
		{"6:30", 0, .Invalid_Format}, // too short
		{"06:300", 0, .Invalid_Format}, // too long
		{"06-30", 0, .Invalid_Format}, // wrong separator

		// bad numbers
		{"ab:cd", 0, .Invalid_Number},
		{"06:cd", 0, .Invalid_Number},
		{"-6:30", 0, .Invalid_Number}, // sign in hours field

		// out of range
		{"24:00", 0, .Out_Of_Range},
		{"23:60", 0, .Out_Of_Range},
	}

	for c in cases {
		d, err := ritual.time_parse(c.input)
		testing.expectf(t, err == c.err, "time_parse(%q) err = %v, want %v", c.input, err, c.err)
		if c.err == .None {
			testing.expectf(t, d == c.want, "time_parse(%q) = %v, want %v", c.input, d, c.want)
		}
	}
}

@(test)
test_local_weekday :: proc(t: ^testing.T) {
	// One full week of known dates (verified against core:time/datetime).
	// Each instant is taken at noon UTC so the local date — and therefore the
	// weekday — is the same as the UTC date for any ordinary zone (UTC-12 ..
	// UTC+11), keeping the result stable regardless of the test host's timezone.
	Case :: struct {
		name:             string,
		year, month, day: int,
		want:             ritual.Weekday,
	}

	cases := []Case {
		{"sunday", 2026, 6, 7, .Sunday},
		{"monday", 2026, 6, 8, .Monday},
		{"tuesday", 2026, 6, 9, .Tuesday},
		{"wednesday", 2026, 6, 10, .Wednesday},
		{"thursday", 2026, 6, 11, .Thursday},
		{"friday", 2026, 6, 12, .Friday},
		{"saturday", 2026, 6, 13, .Saturday},
	}

	for c in cases {
		instant, ok := time.components_to_time(c.year, c.month, c.day, 12, 0, 0)
		testing.expectf(t, ok, "components_to_time(%s) failed", c.name)

		got := ritual.local_weekday(instant, context.allocator)
		testing.expectf(t, got == c.want, "local_weekday(%s) = %v, want %v", c.name, got, c.want)
	}
}
