package tests

import "core:os"
import "core:strings"
import "core:testing"

import ritual "../src"

// command_today loads <user data dir>/ritual, filters to today's rituals, and
// prints them. We point the user data dir at the valid fixtures via
// XDG_DATA_HOME so the whole command runs end-to-end against known-good files.
//
// command_today logs per-file failures at error level, which the test runner
// counts as failures; the valid fixtures parse cleanly, so it stays silent and
// a nil return is the success signal.
@(test)
test_command_today :: proc(t: ^testing.T) {
	context.allocator = context.temp_allocator
	defer free_all(context.temp_allocator)

	dir, _ := os.join_path({#directory, "fixtures", "valid"}, context.temp_allocator)
	os.set_env("XDG_DATA_HOME", dir)
	defer os.unset_env("XDG_DATA_HOME")

	out, errw := strings.builder_make(), strings.builder_make()
	err := ritual.command_today(strings.to_writer(&out), strings.to_writer(&errw))
	testing.expect(t, err == nil, "command_today returned an error")
}
