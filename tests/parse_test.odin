package tests

import "core:fmt"
import "core:os"
import "core:testing"
import "core:time"

import ritual "../src"

@(test)
test_weekday_parse :: proc(t: ^testing.T) {
	Case :: struct {
		input:   string,
		want_wd: ritual.Weekday,
		want_err: ritual.Parse_Error,
	}

	cases := []Case{
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
test_ritual_json_decode_weekdays :: proc(t: ^testing.T) {
	context.allocator = context.temp_allocator
	defer free_all(context.temp_allocator)

	doc := `{
		"name": "Morning",
		"description": "Wake up routine",
		"start": "06:30",
		"end": "07:45",
		"repeat": ["Mon", "we", "FRIDAY"],
		"steps": ["stretch", "coffee"]
	}`

	r, err := ritual.ritual_json_decode(transmute([]byte)doc, context.temp_allocator)
	testing.expect_value(t, err.cause, nil)
	testing.expect_value(t, r.name, "Morning")
	testing.expect_value(t, r.start, ritual.Time_Of_Day(6 * time.Hour + 30 * time.Minute))
	testing.expect_value(t, r.end, ritual.Time_Of_Day(7 * time.Hour + 45 * time.Minute))
	testing.expect_value(t, r.repeat, ritual.Repeat{.Monday, .Wednesday, .Friday})
	testing.expect_value(t, len(r.steps), 2)
}

@(test)
test_ritual_json_decode_daily :: proc(t: ^testing.T) {
	context.allocator = context.temp_allocator
	defer free_all(context.temp_allocator)

	doc := `{
		"name": "Daily",
		"description": "every day",
		"start": "08:00",
		"end": "08:30",
		"repeat": "daily",
		"steps": ["go"]
	}`

	r, err := ritual.ritual_json_decode(transmute([]byte)doc, context.temp_allocator)
	testing.expect_value(t, err.cause, nil)
	testing.expect_value(t, r.repeat, ritual.EVERY_DAY)
}

@(test)
test_ritual_json_decode_end_before_start :: proc(t: ^testing.T) {
	context.allocator = context.temp_allocator
	defer free_all(context.temp_allocator)

	// end equal to start is rejected too: end must be strictly after start.
	for end in ([]string{"06:30", "06:00"}) {
		doc := fmt.tprintf(
			`{{
				"name": "Bad",
				"description": "end not after start",
				"start": "06:30",
				"end": "%s",
				"repeat": "daily",
				"steps": ["go"]
			}}`,
			end,
		)

		_, err := ritual.ritual_json_decode(transmute([]byte)doc, context.temp_allocator)
		testing.expect_value(t, err.cause, ritual.Parse_Error.End_Before_Start)
		testing.expect_value(t, err.field, ritual.Ritual_Field.End)
	}
}

@(test)
test_ritual_json_decode_errors :: proc(t: ^testing.T) {
	context.allocator = context.temp_allocator
	defer free_all(context.temp_allocator)

	Case :: struct {
		name:       string,
		doc:        string,
		want_field: ritual.Ritual_Field,
		want_err:   ritual.Parse_Error,
	}

	// A well-formed document, used as the baseline each case mutates a single
	// field of so the failure under test is the only thing that differs.
	ok := `{
		"name": "X",
		"description": "d",
		"start": "06:30",
		"end": "07:45",
		"repeat": "daily",
		"steps": ["go"]
	}`

	cases := []Case {
		// Malformed JSON collapses to a Format-level failure before any field is
		// reached.
		{"not json", `not json at all`, .Format, .Invalid_Format},
		{"truncated", `{"name": "X"`, .Format, .Invalid_Format},
		{"empty", ``, .Format, .Invalid_Format},

		// start: time_parse rejects shape, non-numbers, and out-of-range values.
		{"start bad shape", `{"name":"X","description":"d","start":"6:30","end":"07:45","repeat":"daily","steps":["go"]}`, .Start, .Invalid_Format},
		{"start not number", `{"name":"X","description":"d","start":"ab:30","end":"07:45","repeat":"daily","steps":["go"]}`, .Start, .Invalid_Number},
		{"start out of range", `{"name":"X","description":"d","start":"24:00","end":"07:45","repeat":"daily","steps":["go"]}`, .Start, .Out_Of_Range},

		// end: same time_parse path, plus the End_Before_Start ordering check.
		{"end bad shape", `{"name":"X","description":"d","start":"06:30","end":"7:45","repeat":"daily","steps":["go"]}`, .End, .Invalid_Format},
		{"end out of range", `{"name":"X","description":"d","start":"06:30","end":"07:60","repeat":"daily","steps":["go"]}`, .End, .Out_Of_Range},
		{"end equals start", `{"name":"X","description":"d","start":"06:30","end":"06:30","repeat":"daily","steps":["go"]}`, .End, .End_Before_Start},
		{"end before start", `{"name":"X","description":"d","start":"06:30","end":"06:00","repeat":"daily","steps":["go"]}`, .End, .End_Before_Start},

		// repeat: only "daily" or a non-empty array of valid weekday names.
		{"repeat bad string", `{"name":"X","description":"d","start":"06:30","end":"07:45","repeat":"weekly","steps":["go"]}`, .Repeat, .Invalid_Format},
		{"repeat empty array", `{"name":"X","description":"d","start":"06:30","end":"07:45","repeat":[],"steps":["go"]}`, .Repeat, .Invalid_Format},
		{"repeat bad weekday", `{"name":"X","description":"d","start":"06:30","end":"07:45","repeat":["funday"],"steps":["go"]}`, .Repeat, .Invalid_Format},
		{"repeat empty weekday", `{"name":"X","description":"d","start":"06:30","end":"07:45","repeat":[""],"steps":["go"]}`, .Repeat, .Empty},
		{"repeat non-string element", `{"name":"X","description":"d","start":"06:30","end":"07:45","repeat":[1],"steps":["go"]}`, .Repeat, .Invalid_Format},
		{"repeat wrong type", `{"name":"X","description":"d","start":"06:30","end":"07:45","repeat":42,"steps":["go"]}`, .Repeat, .Invalid_Format},
	}

	for c in cases {
		_, err := ritual.ritual_json_decode(transmute([]byte)c.doc, context.temp_allocator)
		testing.expectf(
			t,
			err.cause == c.want_err,
			"%s: ritual_json_decode error = %v, want %v",
			c.name,
			err.cause,
			c.want_err,
		)
		testing.expectf(
			t,
			err.field == c.want_field,
			"%s: ritual_json_decode field = %v, want %v",
			c.name,
			err.field,
			c.want_field,
		)
	}

	// Sanity check the baseline decodes cleanly, so the cases above really are
	// isolating one failure rather than tripping over a broken template.
	_, ok_err := ritual.ritual_json_decode(transmute([]byte)ok, context.temp_allocator)
	testing.expect_value(t, ok_err.cause, nil)
}

@(test)
test_load_error_to_string :: proc(t: ^testing.T) {
	context.allocator = context.temp_allocator
	defer free_all(context.temp_allocator)

	e := ritual.Load_Error {
		file  = "rituals/work.json",
		cause = ritual.Field_Error{field = .End, cause = ritual.Parse_Error.Out_Of_Range},
	}
	testing.expect_value(
		t,
		ritual.load_error_to_string(e, context.temp_allocator),
		"rituals/work.json: End field: Out_Of_Range",
	)
}

@(test)
test_rituals_load_from_dir :: proc(t: ^testing.T) {
	context.allocator = context.temp_allocator
	defer free_all(context.temp_allocator)

	// Anchor to this file's directory so the test works regardless of cwd.
	dir, join_err := os.join_path({#directory, "fixtures"}, context.temp_allocator)
	testing.expect_value(t, join_err, nil)

	rituals, err := ritual.rituals_load_from_dir(dir, context.temp_allocator)
	testing.expect_value(t, err.cause, nil)
	testing.expect_value(t, len(rituals), 2)

	// Directory order is filesystem-dependent, so index by name.
	by_name := make(map[string]ritual.Ritual)
	for r in rituals do by_name[r.name] = r

	yoga, has_yoga := by_name["Nightly Yoga"]
	testing.expect(t, has_yoga, "expected a \"Nightly Yoga\" ritual")
	testing.expect_value(t, yoga.start, ritual.Time_Of_Day(21 * time.Hour))
	testing.expect_value(t, yoga.end, ritual.Time_Of_Day(21 * time.Hour + 25 * time.Minute))
	testing.expect_value(t, yoga.repeat, ritual.EVERY_DAY)

	mind, has_mind := by_name["Mindfulness"]
	testing.expect(t, has_mind, "expected a \"Mindfulness\" ritual")
	testing.expect_value(t, mind.start, ritual.Time_Of_Day(6 * time.Hour + 30 * time.Minute))
	testing.expect_value(t, mind.end, ritual.Time_Of_Day(6 * time.Hour + 45 * time.Minute))
	testing.expect_value(t, mind.repeat, ritual.EVERY_DAY)
}
