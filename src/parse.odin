package ritual

import "base:runtime"
import "core:encoding/json"
import "core:log"

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
	Field_Error, // one ore more fields failed parsing
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

// ritual_json_decode decodes a ritual JSON document into a Ritual. On failure
// it returns a Field_Error naming the offending field.
ritual_json_decode :: proc(data: []byte, allocator: runtime.Allocator) -> Ritual_Parse {
	r: Ritual
	raw: Ritual_Raw

	if err := json.unmarshal(data, &raw, allocator = allocator); err != nil {
		// Collapses json's richer Unmarshal_Error into the domain enum; parse
		// against ritual.schema.json first if you need precise JSON diagnostics.
		log.debugf("JSON unmarshal %v", err)
		return {error = .JSON_Error}
	}

	valid: Ritual_Field_Validation
	err: Ritual_Field_Error

	if r.start, err = time_parse(raw.start); err != nil {
		valid[.Start] = err
	}
	if r.end, err = time_parse(raw.end); err != nil {
		valid[.End] = err
	}
	if err == nil && r.end <= r.start {
		valid[.Start] = .End_Before_Start
		valid[.End] = .End_Before_Start
	}
	if r.repeat, err = repeat_parse(raw.repeat); err != nil {
		valid[.Repeat] = err
	}

	// The string fields were already populated into `allocator` by
	// json.unmarshal; adopt them as-is.
	r.name = raw.name
	if r.name == "" {
		valid[.Name] = .Empty
	}

	r.description = raw.description
	if r.description == "" {
		valid[.Description] = .Empty
	}

	r.steps = raw.steps

	return Ritual_Parse {
		ritual = r,
		validation = valid,
		error = .None if valid == {} else .Field_Error,
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
	case:
		return {}, .Invalid_Format
	}
}
