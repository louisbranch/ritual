package tests

import "core:os"
import "core:strings"
import "core:testing"

import ritual "../src"

// command_weekday loads <user data dir>/ritual, filters to the rituals whose
// repeat set contains the given weekday, and prints them sorted by start time.
// We point the user data dir at the weekday fixtures via XDG_DATA_HOME so the
// whole command runs end-to-end against known-good files, and pass an explicit
// weekday so the result doesn't depend on the day the test happens to run.
//
// The fixtures hold a daily "Stretch" (no description) and a Monday-only
// "Monday Standup" (with description), so a single pair of cases exercises
// weekday filtering, start-time sorting, and both description render forms.
//
// command_weekday logs per-file failures at error level, which the test runner
// counts as failures; the fixtures parse cleanly, so it stays silent and the
// printed output is the success signal.
@(test)
test_command_weekday :: proc(t: ^testing.T) {
	context.allocator = context.temp_allocator
	defer free_all(context.temp_allocator)

	dir, _ := os.join_path({#directory, "fixtures", "weekday"}, context.temp_allocator)
	os.set_env("XDG_DATA_HOME", dir)
	defer os.unset_env("XDG_DATA_HOME")

	Case :: struct {
		weekday: ritual.Weekday,
		want:    string,
	}

	cases := []Case {
		// Monday: both rituals match, sorted by start. Stretch has no
		// description (omitted in the fixture) so it renders without a colon.
		{
			.Monday,
			"[07:00 - 07:10] Stretch\n[09:00 - 09:15] Monday Standup: Daily sync\n",
		},
		// Tuesday: the Monday-only standup is filtered out.
		{.Tuesday, "[07:00 - 07:10] Stretch\n"},
	}

	for c in cases {
		out, errw := strings.builder_make(), strings.builder_make()
		err := ritual.command_weekday(
			strings.to_writer(&out),
			strings.to_writer(&errw),
			context.temp_allocator,
			c.weekday,
		)
		testing.expectf(t, err == nil, "command_weekday(%v) returned an error: %v", c.weekday, err)
		got := strings.to_string(out)
		testing.expectf(
			t,
			got == c.want,
			"command_weekday(%v) output = %q, want %q",
			c.weekday,
			got,
			c.want,
		)
	}
}
