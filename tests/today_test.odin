package tests

import "core:log"
import "core:os"
import "core:testing"
import "core:time"

import ritual "../src"

// command_today reads <user data dir>/ritual. We point the user data dir at our
// fixtures via XDG_DATA_HOME so the whole load path runs against known files.
// Both phases live in one test so the env var is never mutated concurrently by
// a parallel test.
@(test)
test_command_today :: proc(t: ^testing.T) {
	context.allocator = context.temp_allocator
	defer free_all(context.temp_allocator)

	// command_today logs per-file failures at error level; the test runner would
	// count those logs as test failures, so silence the logger here. We assert
	// on the returned entries instead.
	context.logger = log.nil_logger()

	// --- valid fixtures: every file loads cleanly ---
	{
		dir, _ := os.join_path({#directory, "fixtures", "valid"}, context.temp_allocator)
		os.set_env("XDG_DATA_HOME", dir)
		defer os.unset_env("XDG_DATA_HOME")

		cmd, err := ritual.command_today(context.temp_allocator)
		testing.expect(t, err == nil, "command_today returned an error")
		testing.expect_value(t, len(cmd.entries), 2)

		// Directory order is filesystem-dependent, so index by name.
		by_name := make(map[string]ritual.Ritual_Parse)
		for e in cmd.entries do by_name[e.ritual.name] = e

		yoga, has_yoga := by_name["Nightly Yoga"]
		testing.expect(t, has_yoga, "expected a \"Nightly Yoga\" ritual")
		testing.expect_value(t, yoga.error, ritual.Ritual_Parse_Error.None)
		testing.expect_value(t, yoga.ritual.start, ritual.Time_Of_Day(21 * time.Hour))
		testing.expect_value(
			t,
			yoga.ritual.end,
			ritual.Time_Of_Day(21 * time.Hour + 25 * time.Minute),
		)
		testing.expect_value(t, yoga.ritual.repeat, ritual.EVERY_DAY)

		mind, has_mind := by_name["Mindfulness"]
		testing.expect(t, has_mind, "expected a \"Mindfulness\" ritual")
		testing.expect_value(t, mind.error, ritual.Ritual_Parse_Error.None)
		testing.expect_value(
			t,
			mind.ritual.start,
			ritual.Time_Of_Day(6 * time.Hour + 30 * time.Minute),
		)
		testing.expect_value(
			t,
			mind.ritual.end,
			ritual.Time_Of_Day(6 * time.Hour + 45 * time.Minute),
		)
		testing.expect_value(t, mind.ritual.repeat, ritual.EVERY_DAY)
	}

	// --- invalid fixtures: errors are classified per file, not fatal ---
	{
		dir, _ := os.join_path({#directory, "fixtures", "invalid"}, context.temp_allocator)
		os.set_env("XDG_DATA_HOME", dir)
		defer os.unset_env("XDG_DATA_HOME")

		cmd, err := ritual.command_today(context.temp_allocator)
		testing.expect(t, err == nil, "command_today returned an error")
		testing.expect_value(t, len(cmd.entries), 3)

		by_file := make(map[string]ritual.Ritual_Parse)
		for e in cmd.entries do by_file[e.file] = e

		notjson, has_notjson := by_file["notjson.json"]
		testing.expect(t, has_notjson, "expected notjson.json entry")
		testing.expect_value(t, notjson.error, ritual.Ritual_Parse_Error.JSON_Error)

		// badfields.json fails every field at once: each is classified
		// independently rather than collapsing to the first failure.
		bad, has_bad := by_file["badfields.json"]
		testing.expect(t, has_bad, "expected badfields.json entry")
		testing.expect_value(t, bad.error, ritual.Ritual_Parse_Error.Field_Error)
		testing.expect_value(t, bad.validation[.Name], ritual.Ritual_Field_Error.Empty)
		testing.expect_value(t, bad.validation[.Description], ritual.Ritual_Field_Error.Empty)
		testing.expect_value(t, bad.validation[.Start], ritual.Ritual_Field_Error.Invalid_Format)
		testing.expect_value(t, bad.validation[.End], ritual.Ritual_Field_Error.Out_Of_Range)
		testing.expect_value(t, bad.validation[.Repeat], ritual.Ritual_Field_Error.Invalid_Format)

		// end-before-start is a cross-field check: both fields parse cleanly on
		// their own, so it is flagged on Start and End together.
		rev, has_rev := by_file["endbeforestart.json"]
		testing.expect(t, has_rev, "expected endbeforestart.json entry")
		testing.expect_value(t, rev.error, ritual.Ritual_Parse_Error.Field_Error)
		testing.expect_value(t, rev.validation[.Start], ritual.Ritual_Field_Error.End_Before_Start)
		testing.expect_value(t, rev.validation[.End], ritual.Ritual_Field_Error.End_Before_Start)
	}
}
