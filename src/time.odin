package ritual

import "base:runtime"
import "core:time"
import "core:time/datetime"
import "core:time/timezone"

// time_parse parses a "HH:MM" time-of-day into a Time_Of_Day offset since
// midnight (0..<24h).
//
// Requires exactly two digits for each field. Rejects negatives, missing
// fields, and out-of-range values (hour > 23 or minute > 59).
time_parse :: proc(s: string) -> (d: Time_Of_Day, err: Ritual_Field_Error) {
	// Digits are scanned by hand, like core's rfc3339 parser: strconv.parse_uint
	// also accepts '+', '_' separators, and base prefixes, none of which are
	// valid in a "HH:MM" field.
	two_digits :: proc(s: string) -> (n: int, err: Ritual_Field_Error) {
		for c in s {
			if c < '0' || c > '9' do return 0, .Invalid_Number
			n = n * 10 + int(c - '0')
		}
		return n, .None
	}

	if len(s) != 5 || s[2] != ':' do return 0, .Invalid_Format

	hour := two_digits(s[0:2]) or_return
	minute := two_digits(s[3:5]) or_return

	if hour > 23 || minute > 59 do return 0, .Out_Of_Range

	d = Time_Of_Day(time.Duration(hour) * time.Hour + time.Duration(minute) * time.Minute)

	return d, .None
}

// local_date returns the calendar date of the given instant in the system's
// local timezone. Pass time.now() to get today.
//
// The returned date is a plain value; the allocator is used only to load the
// tz region during the call and may be reclaimed as soon as this returns.
//
// `ok` is false when the local zone can't be resolved (e.g. no tzdata); the
// returned date then falls back to UTC, which is also what you get when the
// machine's local zone simply is UTC.
local_date :: proc(
	t: time.Time,
	allocator: runtime.Allocator,
) -> (
	date: datetime.Date,
	ok: bool,
) #optional_ok {
	dt := time.time_to_datetime(t) or_return

	// "local" resolves to /etc/localtime; a nil region means UTC, which
	// datetime_to_tz passes through unchanged.
	region := timezone.region_load("local", allocator) or_return
	defer timezone.region_destroy(region, allocator)

	local := timezone.datetime_to_tz(dt, region) or_return
	return local.date, true
}

// local_weekday returns the weekday of the given instant in the system's local
// timezone. Pass time.now() to get today's weekday, which is what `today`
// matches against each ritual's repeat set. Like local_date, the allocator is
// only used to load the tz region during the call.
local_weekday :: proc(t: time.Time, allocator: runtime.Allocator) -> Weekday {
	date := local_date(t, allocator)
	return Weekday(datetime.day_of_week(datetime.unsafe_date_to_ordinal(date)))
}
