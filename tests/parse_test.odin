package tests

import "core:encoding/json"
import "core:os"
import "core:path/filepath"
import "core:testing"
import "core:time"

import ritual "../src"

// rituals_parse reads every ritual document in a directory. We point it at our
// fixture directories directly so the whole load path runs against known files.
@(test)
test_rituals_parse :: proc(t: ^testing.T) {
	context.allocator = context.temp_allocator
	defer free_all(context.temp_allocator)

	// --- valid fixtures: every file loads cleanly ---
	{
		dir, _ := os.join_path({#directory, "fixtures", "valid", "ritual"}, context.temp_allocator)

		entries, err := ritual.rituals_parse(dir, context.temp_allocator)
		testing.expect(t, err == nil, "rituals_parse returned an error")
		testing.expect_value(t, len(entries), 2)

		// Directory order is filesystem-dependent, so index by name.
		by_name := make(map[string]ritual.Ritual_Parse)
		for e in entries do by_name[e.ritual.name] = e

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
		dir, _ := os.join_path(
			{#directory, "fixtures", "invalid", "ritual"},
			context.temp_allocator,
		)

		entries, err := ritual.rituals_parse(dir, context.temp_allocator)
		testing.expect(t, err == nil, "rituals_parse returned an error")
		testing.expect_value(t, len(entries), 3)

		// e.file is the absolute path; index by base name so the fixtures can be
		// looked up by their filenames below.
		by_file := make(map[string]ritual.Ritual_Parse)
		for e in entries do by_file[filepath.base(e.file)] = e

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

@(test)
test_weekday_parse :: proc(t: ^testing.T) {
	Case :: struct {
		input:    string,
		want_wd:  ritual.Weekday,
		want_err: ritual.Ritual_Field_Error,
	}

	cases := []Case {
		// 2-letter, 3-letter, and full forms for each day.
		{"su", .Sunday, .None},
		{"sun", .Sunday, .None},
		{"sunday", .Sunday, .None},
		{"mo", .Monday, .None},
		{"mon", .Monday, .None},
		{"monday", .Monday, .None},
		{"tu", .Tuesday, .None},
		{"tue", .Tuesday, .None},
		{"tuesday", .Tuesday, .None},
		{"we", .Wednesday, .None},
		{"wed", .Wednesday, .None},
		{"wednesday", .Wednesday, .None},
		{"th", .Thursday, .None},
		{"thu", .Thursday, .None},
		{"thursday", .Thursday, .None},
		{"fr", .Friday, .None},
		{"fri", .Friday, .None},
		{"friday", .Friday, .None},
		{"sa", .Saturday, .None},
		{"sat", .Saturday, .None},
		{"saturday", .Saturday, .None},

		// Case-insensitive matching.
		{"MON", .Monday, .None},
		{"Friday", .Friday, .None},
		{"WeDnEsDaY", .Wednesday, .None},

		// Errors.
		{"", {}, .Empty},
		{"x", {}, .Invalid_Format},
		{"mond", {}, .Invalid_Format},
		{"sundays", {}, .Invalid_Format},
		{"wednesdays", {}, .Invalid_Format}, // 10 chars, over the length cap
		{"funday", {}, .Invalid_Format},
		{" mon", {}, .Invalid_Format},
	}

	for c in cases {
		wd, err := ritual.weekday_parse(c.input)
		testing.expectf(
			t,
			err == c.want_err,
			"weekday_parse(%q) error = %v, want %v",
			c.input,
			err,
			c.want_err,
		)
		testing.expectf(
			t,
			wd == c.want_wd,
			"weekday_parse(%q) = %v, want %v",
			c.input,
			wd,
			c.want_wd,
		)
	}
}

@(test)
test_repeat_parse :: proc(t: ^testing.T) {
	context.allocator = context.temp_allocator
	defer free_all(context.temp_allocator)

	// repeat_parse consumes the schema's `repeat` oneOf as a raw json.Value, so
	// the cases are built as json values rather than routed through a full decode.
	arr :: proc(elems: ..json.Value) -> json.Value {
		a := make(json.Array, 0, len(elems))
		append(&a, ..elems)
		return a
	}

	Case :: struct {
		name:     string,
		input:    json.Value,
		want_rep: ritual.Repeat,
		want_err: ritual.Ritual_Field_Error,
	}

	cases := []Case {
		// "daily" expands to every weekday.
		{"daily", json.String("daily"), ritual.EVERY_DAY, .None},
		// An array of weekday names in any of the accepted forms/cases.
		{
			"weekday array",
			arr(json.String("Mon"), json.String("we"), json.String("FRIDAY")),
			{.Monday, .Wednesday, .Friday},
			.None,
		},
		// Any string other than "daily" is rejected.
		{"unknown string", json.String("weekly"), {}, .Invalid_Format},
		// schema requires minItems 1.
		{"empty array", arr(), {}, .Invalid_Format},
		// Element errors propagate from weekday_parse.
		{"bad weekday", arr(json.String("funday")), {}, .Invalid_Format},
		{"empty weekday", arr(json.String("")), {}, .Empty},
		// Non-string elements, and non-string/array values, are malformed.
		{"non-string element", arr(json.Integer(1)), {}, .Invalid_Format},
		{"wrong type", json.Integer(42), {}, .Invalid_Format},
	}

	for c in cases {
		rep, err := ritual.repeat_parse(c.input)
		testing.expectf(
			t,
			err == c.want_err,
			"%s: repeat_parse error = %v, want %v",
			c.name,
			err,
			c.want_err,
		)
		if c.want_err == .None {
			testing.expectf(
				t,
				rep == c.want_rep,
				"%s: repeat_parse = %v, want %v",
				c.name,
				rep,
				c.want_rep,
			)
		}
	}
}
