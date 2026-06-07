package tests

import "core:encoding/json"
import "core:testing"

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
