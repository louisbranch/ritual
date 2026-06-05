package ritual

import "base:runtime"
import "core:encoding/json"
import "core:os"
import "core:slice"
import "core:strings"

// Load_Error is anything that can go wrong while loading rituals from disk: an
// OS error reading the directory or a file, or a Parse_Error decoding one.
Load_Error :: union {
	os.Error,
	Parse_Error,
}

// load_rituals_from_dir reads every file in dir_path and decodes each as a
// ritual JSON document. The rituals are cloned into `allocator`; the directory
// listing and raw file bytes are read into `scratch`, which the caller may
// reclaim as soon as this returns.
load_rituals_from_dir :: proc(
	dir_path: string,
	allocator: runtime.Allocator,
	scratch: runtime.Allocator,
) -> (
	rituals: [dynamic]Ritual,
	err: Load_Error,
) {
	rituals = make([dynamic]Ritual, allocator)

	files := os.read_all_directory_by_path(dir_path, scratch) or_return
	for f in files {
		data := os.read_entire_file_from_path(f.fullpath, scratch) or_return
		r := unmarshal_ritual(data, allocator, scratch) or_return
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

// unmarshal_ritual decodes a ritual JSON document into a Ritual. The JSON is
// parsed into `scratch` (the raw strings, the duration fields and the repeat
// Value tree); only the keeper fields are cloned into `allocator`, so the
// caller may reclaim `scratch` as soon as this returns. The result does not
// alias `data`.
unmarshal_ritual :: proc(
	data: []byte,
	allocator: runtime.Allocator,
	scratch: runtime.Allocator,
) -> (
	r: Ritual,
	err: Parse_Error,
) {
	raw: Ritual_Raw
	if json.unmarshal(data, &raw, allocator = scratch) != nil {
		// Collapses json's richer Unmarshal_Error into the domain enum; parse
		// against ritual.schema.json first if you need precise JSON diagnostics.
		return {}, .Invalid_Format
	}

	// Validate before cloning so a rejected ritual touches `allocator` not at all.
	r.start = parse_time(raw.start) or_return
	r.end = parse_time(raw.end) or_return
	if r.end <= r.start do return {}, .End_Before_Start
	r.repeat = parse_repeat(raw.repeat) or_return

	// The remaining fields live in `scratch`; clone them into `allocator`.
	r.name = strings.clone(raw.name, allocator)
	r.description = strings.clone(raw.description, allocator)
	r.steps = make([dynamic]string, len(raw.steps), allocator)
	for s, i in raw.steps do r.steps[i] = strings.clone(s, allocator)
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

	case:
		return {}, .Invalid_Format
	}
}

// parse_weekday parses a weekday name in 2-letter, 3-letter, or full form
// (case-insensitive), matching ritual.schema.json's `weekday` definition.
parse_weekday :: proc(s: string) -> (wd: Weekday, err: Parse_Error) {
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
