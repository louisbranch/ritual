package ritual

import "base:runtime"
import "core:encoding/json"
import "core:log"
import "core:os"

Ritual_Parse :: struct {
	file:       string,
	ritual:     Ritual,
	error:      Ritual_Parse_Error,
	validation: Ritual_Field_Validation,
}

Ritual_Parse_Error :: enum {
	None,
	Read_Error, // unable to read file
	JSON_Error, // unable to unmarshal file from JSON
	Field_Error, // one or more fields failed parsing
}

Ritual_Parse_Field :: enum {
	Name,
	Description,
	Start,
	End,
	Repeat,
}

Ritual_Field_Validation :: [Ritual_Parse_Field]Ritual_Field_Error

// Ritual_Field_Error is the reason a single ritual field failed to parse or
// validate. It is shared by every field parser (time_parse, repeat_parse,
// weekday_parse) and recorded per field in a Ritual_Field_Validation.
Ritual_Field_Error :: enum {
	None,
	Empty, // input string was empty
	Invalid_Format, // missing unit, wrong shape, or trailing junk
	Invalid_Number, // a field was not a non-negative integer
	Out_Of_Range, // value outside its allowed bounds
	End_Before_Start, // ritual end is not after its start
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

// rituals_parse loads and decodes every ritual document in the given directory.
rituals_parse :: proc(
	path: string,
	allocator: runtime.Allocator,
) -> (
	[dynamic]Ritual_Parse,
	os.Error,
) {
	files, err := os.read_all_directory_by_path(path, allocator)
	if err != nil {
		log.debugf("failed to read dir %s: %v", path, err)
		return nil, err
	}

	entries := make([dynamic]Ritual_Parse, 0, len(files), allocator)

	for f in files {
		if f.type != os.File_Type.Regular {
			log.debugf("not a file %q", f.fullpath)
			continue
		}
		entry := ritual_json_decode(f.fullpath, allocator)
		append(&entries, entry)
	}
	return entries, nil
}

// ritual_json_decode decodes a single ritual JSON file. A read, JSON, or
// field-level failure is recorded in the result's error field rather than
// aborting, so one bad file never fails the whole load.
ritual_json_decode :: proc(path: string, allocator: runtime.Allocator) -> Ritual_Parse {
	data, read_err := os.read_entire_file_from_path(path, allocator)
	if read_err != nil {
		log.debugf("file read %v", read_err)
		return {file = path, error = .Read_Error}
	}

	raw: Ritual_Raw

	if err := json.unmarshal(data, &raw, allocator = allocator); err != nil {
		// Collapses json's richer Unmarshal_Error into the domain enum; parse
		// against ritual.schema.json first if you need precise JSON diagnostics.
		log.debugf("JSON unmarshal %v", err)
		return {file = path, error = .JSON_Error}
	}

	r: Ritual
	validation: Ritual_Field_Validation
	err: Ritual_Field_Error

	if r.start, err = time_parse(raw.start); err != nil {
		validation[.Start] = err
	}
	if r.end, err = time_parse(raw.end); err != nil {
		validation[.End] = err
	}
	if err == nil && r.end <= r.start {
		validation[.Start] = .End_Before_Start
		validation[.End] = .End_Before_Start
	}
	if r.repeat, err = repeat_parse(raw.repeat); err != nil {
		validation[.Repeat] = err
	}

	// The string fields were already populated into `allocator` by
	// json.unmarshal; adopt them as-is.
	r.name = raw.name
	if r.name == "" {
		validation[.Name] = .Empty
	}

	r.description = raw.description
	if r.description == "" {
		validation[.Description] = .Empty
	}

	r.steps = raw.steps

	return Ritual_Parse {
		file = path,
		ritual = r,
		validation = validation,
		error = .None if validation == {} else .Field_Error,
	}
}

// repeat_parse converts the schema's `repeat` oneOf — the literal string
// "daily" or a non-empty array of weekday names — into a Repeat bit_set.
repeat_parse :: proc(v: json.Value) -> (rep: Repeat, err: Ritual_Field_Error) {
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
weekday_parse :: proc(s: string) -> (wd: Weekday, err: Ritual_Field_Error) {
	max :: len("wednesday")

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
	case:
		return {}, .Invalid_Format
	}
}
