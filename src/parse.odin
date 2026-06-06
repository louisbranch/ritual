package ritual

import "base:runtime"
import "core:encoding/json"
import "core:fmt"
import "core:os"
import "core:slice"
import "core:strings"

// Ritual_Field names the document field an error is about, so a failed load can
// report which field of which file was rejected and why.
Ritual_Field :: enum {
	None,
	Format, // the document as a whole failed to decode
	Start,
	End,
	Repeat,
}

// Field_Error pairs a Parse_Error with the document field it concerns; `field`
// is meaningful only for parse failures, so it lives here rather than alongside
// the OS errors in Load_Error.
Field_Error :: struct {
	field: Ritual_Field,
	cause: Parse_Error,
}

// Load_Error locates a failure while loading rituals: `cause` is the underlying
// OS or field error, and `file` the document it came from (empty for the
// directory read itself). A zero Load_Error — in particular a nil `cause` —
// means success.
Load_Error :: struct {
	file:  string,
	cause: union {
		os.Error,
		Field_Error,
	},
}

// load_error_to_string renders a Load_Error as a single human-readable line,
// e.g. `rituals/work.json: End field: Out_Of_Range`. Allocates into `allocator`.
load_error_to_string :: proc(e: Load_Error, allocator: runtime.Allocator) -> string {
	switch c in e.cause {
	case Field_Error:
		return fmt.aprintf("%s: %v field: %v", e.file, c.field, c.cause, allocator = allocator)
	case os.Error:
		if e.file != "" do return fmt.aprintf("%s: %v", e.file, c, allocator = allocator)
		return fmt.aprintf("%v", c, allocator = allocator)
	}
	return strings.clone("no error", allocator)
}

// rituals_load_from_dir reads every file in dir_path and decodes each as a
// ritual JSON document, sorted by start time.
rituals_load_from_dir :: proc(
	dir_path: string,
	allocator: runtime.Allocator,
) -> (
	rituals: [dynamic]Ritual,
	err: Load_Error,
) {
	rituals = make([dynamic]Ritual, allocator)

	files, dir_err := os.read_all_directory_by_path(dir_path, allocator)
	if dir_err != nil do return rituals, Load_Error{cause = dir_err}

	for f in files {
		data, read_err := os.read_entire_file_from_path(f.fullpath, allocator)
		if read_err != nil do return rituals, Load_Error{file = f.name, cause = read_err}

		r, field_err := ritual_json_decode(data, allocator)
		if field_err.cause != nil {
			return rituals, Load_Error{file = f.name, cause = field_err}
		}

		append(&rituals, r)
	}
	slice.sort_by(rituals[:], proc(a, b: Ritual) -> bool {return a.start < b.start})
	return
}

// Ritual_Raw mirrors ritual.schema.json field-for-field, using only types that
// json.unmarshal populates natively. The duration strings and the `repeat`
// oneOf are converted into their real types by unmarshal_ritual.
Ritual_Raw :: struct {
	name:        string,
	description: string,
	start:       string, // "HH:MM" time-of-day, see time_parse
	end:         string, // "HH:MM" time-of-day, see time_parse
	repeat:      json.Value, // "daily" OR ["Mon","Tue",...]
	steps:       [dynamic]string,
}

// ritual_json_decode decodes a ritual JSON document into a Ritual. On failure
// it returns a Field_Error naming the offending field.
ritual_json_decode :: proc(data: []byte, allocator: runtime.Allocator) -> (Ritual, Field_Error) {
	r: Ritual
	raw: Ritual_Raw

	if json.unmarshal(data, &raw, allocator = allocator) != nil {
		// Collapses json's richer Unmarshal_Error into the domain enum; parse
		// against ritual.schema.json first if you need precise JSON diagnostics.
		return {}, {.Format, .Invalid_Format}
	}

	err: Parse_Error
	if r.start, err = time_parse(raw.start); err != nil {
		return {}, {.Start, err}
	}
	if r.end, err = time_parse(raw.end); err != nil {
		return {}, {.End, err}
	}
	if r.end <= r.start do return {}, {.End, .End_Before_Start}
	if r.repeat, err = repeat_parse(raw.repeat); err != nil {
		return {}, {.Repeat, err}
	}

	// The string fields were already populated into `allocator` by
	// json.unmarshal; adopt them as-is.
	r.name = raw.name
	r.description = raw.description
	r.steps = raw.steps

	return r, {}
}

// repeat_parse converts the schema's `repeat` oneOf — the literal string
// "daily" or a non-empty array of weekday names — into a Repeat bit_set.
repeat_parse :: proc(v: json.Value) -> (rep: Repeat, err: Parse_Error) {
	#partial switch t in v {
	case json.String:
		if t == "daily" do return EVERY_DAY, .None
		return {}, .Invalid_Format

	case json.Array:
		if len(t) == 0 do return {}, .Invalid_Format // schema: minItems 1
		for elem in t {
			name, ok := elem.(json.String)
			if !ok do return {}, .Invalid_Format
			wd := weekday_parse(name) or_return
			rep += {wd}
		}
		return rep, .None

	case:
		return {}, .Invalid_Format
	}
}

// weekday_parse parses a weekday name in 2-letter, 3-letter, or full form
// (case-insensitive), matching ritual.schema.json's `weekday` definition.
weekday_parse :: proc(s: string) -> (wd: Weekday, err: Parse_Error) {
	max :: 9 // len("wednesday")

	if len(s) == 0 do return {}, .Empty
	if len(s) > max do return {}, .Invalid_Format

	// ASCII-lowercase into a stack buffer: the result is pure scratch for the
	// match below, so there's no reason to touch any allocator.
	buf: [max]byte
	for i in 0 ..< len(s) {
		c := s[i]
		if 'A' <= c && c <= 'Z' do c += 'a' - 'A'
		buf[i] = c
	}

	switch string(buf[:len(s)]) {
	case "su", "sun", "sunday":
		return .Sunday, .None
	case "mo", "mon", "monday":
		return .Monday, .None
	case "tu", "tue", "tuesday":
		return .Tuesday, .None
	case "we", "wed", "wednesday":
		return .Wednesday, .None
	case "th", "thu", "thursday":
		return .Thursday, .None
	case "fr", "fri", "friday":
		return .Friday, .None
	case "sa", "sat", "saturday":
		return .Saturday, .None
	}

	return {}, .Invalid_Format
}
