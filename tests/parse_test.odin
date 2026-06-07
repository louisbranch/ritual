package tests

import "core:fmt"
import "core:testing"
import "core:time"

import ritual "../src"

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

	e := ritual.ritual_json_decode(transmute([]byte)doc, context.temp_allocator)
	testing.expect_value(t, e.error, ritual.Ritual_Parse_Error.None)
	testing.expect_value(t, e.ritual.name, "Morning")
	testing.expect_value(t, e.ritual.start, ritual.Time_Of_Day(6 * time.Hour + 30 * time.Minute))
	testing.expect_value(t, e.ritual.end, ritual.Time_Of_Day(7 * time.Hour + 45 * time.Minute))
	testing.expect_value(t, e.ritual.repeat, ritual.Repeat{.Monday, .Wednesday, .Friday})
	testing.expect_value(t, len(e.ritual.steps), 2)
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

	e := ritual.ritual_json_decode(transmute([]byte)doc, context.temp_allocator)
	testing.expect_value(t, e.error, ritual.Ritual_Parse_Error.None)
	testing.expect_value(t, e.ritual.repeat, ritual.EVERY_DAY)
}

@(test)
test_ritual_json_decode_end_before_start :: proc(t: ^testing.T) {
	context.allocator = context.temp_allocator
	defer free_all(context.temp_allocator)

	// end equal to start is rejected too: end must be strictly after start, and
	// the ordering failure is flagged on both fields.
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

		e := ritual.ritual_json_decode(transmute([]byte)doc, context.temp_allocator)
		testing.expect_value(t, e.error, ritual.Ritual_Parse_Error.Field_Error)
		testing.expect_value(t, e.validation[.Start], ritual.Ritual_Field_Error.End_Before_Start)
		testing.expect_value(t, e.validation[.End], ritual.Ritual_Field_Error.End_Before_Start)
	}
}

@(test)
test_ritual_json_decode_parse_errors :: proc(t: ^testing.T) {
	context.allocator = context.temp_allocator
	defer free_all(context.temp_allocator)

	// Malformed documents never reach field validation: they collapse to a
	// single Parse_Error before any field is inspected.
	docs := []string {
		`not json at all`,
		`{"name": "X"`, // truncated
		``, // empty
	}

	for doc in docs {
		e := ritual.ritual_json_decode(transmute([]byte)doc, context.temp_allocator)
		testing.expectf(
			t,
			e.error == .JSON_Error,
			"ritual_json_decode(%q) error = %v, want Parse_Error",
			doc,
			e.error,
		)
	}
}

@(test)
test_ritual_json_decode_field_errors :: proc(t: ^testing.T) {
	context.allocator = context.temp_allocator
	defer free_all(context.temp_allocator)

	Case :: struct {
		name:       string,
		doc:        string,
		want_field: ritual.Ritual_Parse_Field,
		want_err:   ritual.Ritual_Field_Error,
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
		// name / description: empty strings are rejected.
		{
			"name empty",
			`{"name":"","description":"d","start":"06:30","end":"07:45","repeat":"daily","steps":["go"]}`,
			.Name,
			.Empty,
		},
		{
			"description empty",
			`{"name":"X","description":"","start":"06:30","end":"07:45","repeat":"daily","steps":["go"]}`,
			.Description,
			.Empty,
		},

		// start: time_parse rejects shape, non-numbers, and out-of-range values.
		{
			"start bad shape",
			`{"name":"X","description":"d","start":"6:30","end":"07:45","repeat":"daily","steps":["go"]}`,
			.Start,
			.Invalid_Format,
		},
		{
			"start not number",
			`{"name":"X","description":"d","start":"ab:30","end":"07:45","repeat":"daily","steps":["go"]}`,
			.Start,
			.Invalid_Number,
		},
		{
			"start out of range",
			`{"name":"X","description":"d","start":"24:00","end":"07:45","repeat":"daily","steps":["go"]}`,
			.Start,
			.Out_Of_Range,
		},

		// end: same time_parse path.
		{
			"end bad shape",
			`{"name":"X","description":"d","start":"06:30","end":"7:45","repeat":"daily","steps":["go"]}`,
			.End,
			.Invalid_Format,
		},
		{
			"end out of range",
			`{"name":"X","description":"d","start":"06:30","end":"07:60","repeat":"daily","steps":["go"]}`,
			.End,
			.Out_Of_Range,
		},

		// repeat: only "daily" or a non-empty array of valid weekday names.
		{
			"repeat bad string",
			`{"name":"X","description":"d","start":"06:30","end":"07:45","repeat":"weekly","steps":["go"]}`,
			.Repeat,
			.Invalid_Format,
		},
		{
			"repeat empty array",
			`{"name":"X","description":"d","start":"06:30","end":"07:45","repeat":[],"steps":["go"]}`,
			.Repeat,
			.Invalid_Format,
		},
		{
			"repeat bad weekday",
			`{"name":"X","description":"d","start":"06:30","end":"07:45","repeat":["funday"],"steps":["go"]}`,
			.Repeat,
			.Invalid_Format,
		},
		{
			"repeat empty weekday",
			`{"name":"X","description":"d","start":"06:30","end":"07:45","repeat":[""],"steps":["go"]}`,
			.Repeat,
			.Empty,
		},
		{
			"repeat non-string element",
			`{"name":"X","description":"d","start":"06:30","end":"07:45","repeat":[1],"steps":["go"]}`,
			.Repeat,
			.Invalid_Format,
		},
		{
			"repeat wrong type",
			`{"name":"X","description":"d","start":"06:30","end":"07:45","repeat":42,"steps":["go"]}`,
			.Repeat,
			.Invalid_Format,
		},
	}

	for c in cases {
		e := ritual.ritual_json_decode(transmute([]byte)c.doc, context.temp_allocator)
		testing.expectf(
			t,
			e.error == .Field_Error,
			"%s: ritual_json_decode error = %v, want Field_Error",
			c.name,
			e.error,
		)
		testing.expectf(
			t,
			e.validation[c.want_field] == c.want_err,
			"%s: validation[%v] = %v, want %v",
			c.name,
			c.want_field,
			e.validation[c.want_field],
			c.want_err,
		)
	}

	// Sanity check the baseline decodes cleanly, so the cases above really are
	// isolating one failure rather than tripping over a broken template.
	ok_entry := ritual.ritual_json_decode(transmute([]byte)ok, context.temp_allocator)
	testing.expect_value(t, ok_entry.error, ritual.Ritual_Parse_Error.None)
}
