package tests

import "core:testing"
import "core:time"
import "core:time/datetime"

import ritual "../src"

@(test)
test_time_parse :: proc(t: ^testing.T) {
	Case :: struct {
		input: string,
		want: ritual.Time_Of_Day,
		err:  ritual.Parse_Error,
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
test_is_today :: proc(t: ^testing.T) {
	// Known weekdays (verified against core:time/datetime):
	//   2026-06-04 Thu, -05 Fri, -06 Sat, -07 Sun, -08 Mon.
	thu := datetime.Date{year = 2026, month = 6, day = 4}
	sat := datetime.Date{year = 2026, month = 6, day = 6}
	sun := datetime.Date{year = 2026, month = 6, day = 7}

	Case :: struct {
		name:   string,
		repeat: ritual.Repeat,
		date:   datetime.Date,
		want:   bool,
	}

	cases := []Case {
		// weekday present in the repeat set
		{"matching weekday", {.Thursday}, thu, true},
		// weekday absent from the repeat set
		{"non-matching weekday", {.Friday, .Saturday}, thu, false},
		// every-day ritual matches any date
		{"daily on weekday", ritual.EVERY_DAY, thu, true},
		{"daily on weekend", ritual.EVERY_DAY, sat, true},
		// empty repeat set never matches
		{"never", {}, thu, false},
		// weekend-only ritual
		{"weekend match", {.Saturday, .Sunday}, sun, true},
		{"weekend miss", {.Saturday, .Sunday}, thu, false},
	}

	for c in cases {
		r := ritual.Ritual {
			repeat = c.repeat,
		}
		got := ritual.is_today(r, c.date)
		testing.expectf(t, got == c.want, "is_today(%s) = %v, want %v", c.name, got, c.want)
	}
}
