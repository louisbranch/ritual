package ritual

import "core:encoding/json"
import "core:os"
import "core:slice"

// Load_Error is anything that can go wrong while loading rituals from disk: an
// OS error reading the directory or a file, or a Parse_Error decoding one.
Load_Error :: union {
	os.Error,
	Parse_Error,
}

// load_rituals_from_dir reads every file in dir_path and decodes each as a
// ritual JSON document. The returned slice and all ritual memory are owned by
// `allocator`.
load_rituals_from_dir :: proc(
	dir_path: string,
	allocator := context.allocator,
) -> (
	rituals: [dynamic]Ritual,
	err: Load_Error,
) {
	rituals = make([dynamic]Ritual, allocator)

	files := os.read_all_directory_by_path(dir_path, allocator) or_return
	for f in files {
		data := os.read_entire_file_from_path(f.fullpath, allocator) or_return
		r := unmarshal_ritual(data, allocator) or_return
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
	start:       string, // "HH:MM" time-of-day, see parse_time
	end:         string, // "HH:MM" time-of-day, see parse_time
	repeat:      json.Value, // "daily" OR ["Mon","Tue",...]
	steps:       [dynamic]string,
}

// unmarshal_ritual decodes a ritual JSON document into a Ritual. The decoded
// strings, slices and map memory are owned by `allocator`.
unmarshal_ritual :: proc(
	data: []byte,
	allocator := context.allocator,
) -> (
	r: Ritual,
	err: Parse_Error,
) {
	raw: Ritual_Raw
	if json.unmarshal(data, &raw, allocator = allocator) != nil {
		// Collapses json's richer Unmarshal_Error into the domain enum; parse
		// against ritual.schema.json first if you need precise JSON diagnostics.
		return {}, .Invalid_Format
	}

	r.name = raw.name
	r.description = raw.description
	r.steps = raw.steps
	r.start = parse_time(raw.start) or_return
	r.end = parse_time(raw.end) or_return
	if r.end <= r.start do return {}, .End_Before_Start
	r.repeat = parse_repeat(raw.repeat) or_return
	return
}

// parse_repeat converts the schema's `repeat` oneOf — the literal string
// "daily" or a non-empty array of weekday names — into a Repeat bit_set.
parse_repeat :: proc(v: json.Value) -> (rep: Repeat, err: Parse_Error) {
	#partial switch t in v {
	case json.String:
		if t == "daily" do return EVERY_DAY, .None
		return {}, .Invalid_Format

	case json.Array:
		if len(t) == 0 do return {}, .Invalid_Format // schema: minItems 1
		for elem in t {
			name, ok := elem.(json.String)
			if !ok do return {}, .Invalid_Format
			wd := parse_weekday(name) or_return
			rep += {wd}
		}
		return rep, .None
	}

	return {}, .Invalid_Format
}

// parse_weekday parses a weekday name in 2-letter, 3-letter, or full form
// (case-insensitive), matching ritual.schema.json's `weekday` definition.
parse_weekday :: proc(s: string) -> (wd: Weekday, err: Parse_Error) {
	if len(s) == 0 do return {}, .Empty
	if len(s) > 9 do return {}, .Invalid_Format // longest accepted form is "wednesday"

	// ASCII-lowercase into a stack buffer: the result is pure scratch for the
	// match below, so there's no reason to touch any allocator.
	buf: [9]u8
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
