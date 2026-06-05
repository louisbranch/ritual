package tests

import "core:testing"
import "core:time"

import ritual "../src"

@(test)
test_ritual_to_string :: proc(t: ^testing.T) {
	context.allocator = context.temp_allocator
	defer free_all(context.temp_allocator)

	Case :: struct {
		r:    ritual.Ritual,
		want: string,
	}

	cases := []Case{
		{
			ritual.Ritual{
				name = "Morning",
				description = "Wake up routine",
				start = ritual.Time_Of_Day(6 * time.Hour + 30 * time.Minute),
				end = ritual.Time_Of_Day(7 * time.Hour + 45 * time.Minute),
				repeat = ritual.EVERY_DAY,
			},
			"[06:30 - 07:45] Morning: Wake up routine",
		},
		// Midnight start renders as 00:00, not blank or 24:00.
		{
			ritual.Ritual{
				name = "Night",
				description = "wind down",
				start = ritual.Time_Of_Day(0),
				end = ritual.Time_Of_Day(23 * time.Hour + 59 * time.Minute),
			},
			"[00:00 - 23:59] Night: wind down",
		},
		// Empty name and description still produce a well-formed line.
		{
			ritual.Ritual{
				start = ritual.Time_Of_Day(8 * time.Hour),
				end = ritual.Time_Of_Day(8 * time.Hour + 30 * time.Minute),
			},
			"[08:00 - 08:30] : ",
		},
	}

	for c in cases {
		got := ritual.ritual_to_string(c.r, context.temp_allocator)
		testing.expectf(
			t,
			got == c.want,
			"ritual_to_string() = %q, want %q",
			got,
			c.want,
		)
	}
}
