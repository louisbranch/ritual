package ritual

import "base:runtime"
import "core:strconv"
import "core:time"
import "core:time/datetime"
import "core:time/timezone"

Parse_Error :: enum {
	None,
	Empty, // input string was empty
	Invalid_Format, // missing unit, wrong shape, or trailing junk
	Invalid_Number, // a field was not a non-negative integer
	Out_Of_Range, // value outside its allowed bounds
	End_Before_Start, // ritual end is not after its start
}

// Parses a "HH:MM" time-of-day into a Time_Of_Day offset since midnight
// (0..<24h).
//
// Requires exactly two digits for each field. Rejects negatives, missing
// fields, and out-of-range values (hour > 23 or minute > 59).
time_parse :: proc(s: string) -> (d: Time_Of_Day, err: Parse_Error) {
	if len(s) != 5 || s[2] != ':' do return 0, .Invalid_Format

	hour, hour_ok := strconv.parse_uint(s[0:2])
	if !hour_ok do return 0, .Invalid_Number
	minute, minute_ok := strconv.parse_uint(s[3:5])
	if !minute_ok do return 0, .Invalid_Number

	if hour > 23 || minute > 59 do return 0, .Out_Of_Range

	return Time_Of_Day(time.Duration(hour) * time.Hour + time.Duration(minute) * time.Minute),
		.None
}

// local_date returns the calendar date at instant `t` in the system's local
// timezone. Pass time.now() to get today.
//
// The returned date is a plain value; `scratch` is used only to load the tz
// region during the call and may be reclaimed as soon as this returns.
//
// `ok` is false when the local zone can't be resolved (e.g. no tzdata); the
// returned date then falls back to UTC, which is also what you get when the
// machine's local zone simply is UTC.
local_date :: proc(
	t: time.Time,
	scratch: runtime.Allocator,
) -> (date: datetime.Date, ok: bool) #optional_ok {
	dt := time.time_to_datetime(t) or_return

	// "local" resolves to /etc/localtime; a nil region means UTC, which
	// datetime_to_tz passes through unchanged.
	region := timezone.region_load("local", scratch) or_return
	defer timezone.region_destroy(region, scratch)

	local := timezone.datetime_to_tz(dt, region) or_return
	return local.date, true
}

// is_today reports whether ritual `r` is scheduled on `date`, i.e. whether the
// weekday of `date` is in the ritual's repeat set. Pass a local date (see
// local_date) so the weekday matches the user's wall calendar.
is_today :: proc(r: Ritual, date: datetime.Date) -> bool {
	wd := Weekday(datetime.day_of_week(datetime.unsafe_date_to_ordinal(date)))
	return wd in r.repeat
}
