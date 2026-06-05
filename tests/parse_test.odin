package tests

import "core:fmt"
import "core:os"
import "core:testing"
import "core:time"

import ritual "../src"

@(test)
test_unmarshal_ritual_weekdays :: proc(t: ^testing.T) {
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

	r, err := ritual.unmarshal_ritual(transmute([]byte)doc)
	testing.expect_value(t, err, nil)
	testing.expect_value(t, r.name, "Morning")
	testing.expect_value(t, r.start, ritual.Time_Of_Day(6 * time.Hour + 30 * time.Minute))
	testing.expect_value(t, r.end, ritual.Time_Of_Day(7 * time.Hour + 45 * time.Minute))
	testing.expect_value(t, r.repeat, ritual.Repeat{.Monday, .Wednesday, .Friday})
	testing.expect_value(t, len(r.steps), 2)
}

@(test)
test_unmarshal_ritual_daily :: proc(t: ^testing.T) {
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

	r, err := ritual.unmarshal_ritual(transmute([]byte)doc)
	testing.expect_value(t, err, nil)
	testing.expect_value(t, r.repeat, ritual.EVERY_DAY)
}

@(test)
test_unmarshal_ritual_end_before_start :: proc(t: ^testing.T) {
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

		_, err := ritual.unmarshal_ritual(transmute([]byte)doc)
		testing.expect_value(t, err, ritual.Parse_Error.End_Before_Start)
	}
}

@(test)
test_load_rituals_from_dir :: proc(t: ^testing.T) {
	context.allocator = context.temp_allocator
	defer free_all(context.temp_allocator)

	// Anchor to this file's directory so the test works regardless of cwd.
	dir, join_err := os.join_path({#directory, "fixtures"}, context.temp_allocator)
	testing.expect_value(t, join_err, nil)

	rituals, err := ritual.load_rituals_from_dir(dir)
	testing.expect_value(t, err, nil)
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
