package ritual

import "base:runtime"
import "core:fmt"
import "core:io"
import "core:log"
import "core:mem/virtual"
import "core:os"
import "core:time"

APP_NAME :: "ritual"
APP_VERSION :: "0.4.0"

HELP :: `Usage: %[0]s [COMMAND | WEEKDAY]

Track simple recurring rituals and list the ones scheduled for today.

Commands:
  today      List rituals for the current date (default)
  version    Print version information
  help       Show this help

Pass a weekday name to list that day's rituals instead of today's. Accepts
2-letter, 3-letter, or full names, case-insensitive (e.g. mo, mon, Monday).

With no command, %[0]s runs 'today'.`

Command_Error :: enum {
	None,
	No_Data_Directory,
	No_Files,
}

Error :: union #shared_nil {
	runtime.Allocator_Error,
	os.Error,
	Command_Error,
}

main :: proc() {
	lowest := log.Level.Debug when ODIN_DEBUG else log.Level.Info
	context.logger = log.create_console_logger(lowest)
	defer log.destroy_console_logger(context.logger)

	cmd := os.args[1] if len(os.args) > 1 else ""

	out := io.to_writer(os.to_stream(os.stdout))
	errw := io.to_writer(os.to_stream(os.stderr))

	switch cmd {
	case "", "today":
		run_weekday(out, errw)
	case "version":
		fmt.wprintfln(out, "%s %s", APP_NAME, APP_VERSION)
	case "help":
		fmt.wprintfln(out, HELP, APP_NAME)
	case:
		weekday, err := weekday_parse(cmd)
		if err != nil {
			fmt.wprintfln(errw, "%s: unknown command '%s'", APP_NAME, cmd)
			fmt.wprintfln(errw, "Try '%s help' for more information.", APP_NAME)
			os.exit(1)
		}

		run_weekday(out, errw, weekday)
	}
}

run_weekday :: proc(out, errw: io.Writer, day: Maybe(Weekday) = nil) -> Error {
	arena: virtual.Arena
	virtual.arena_init_growing(&arena) or_return
	defer virtual.arena_destroy(&arena)

	allocator := virtual.arena_allocator(&arena)

	weekday := day.? or_else local_weekday(time.now(), allocator)

	switch err in command_weekday(out, errw, allocator, weekday) {
	case Command_Error:
		log.debug(err)
		os.exit(1)
	case runtime.Allocator_Error, os.Error:
		log.fatal(err)
		os.exit(1)
	}

	return nil
}
