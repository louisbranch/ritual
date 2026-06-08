package ritual

import "base:runtime"
import "core:fmt"
import "core:io"
import "core:log"
import "core:os"

APP_NAME :: "ritual"
APP_VERSION :: "0.3.0"

HELP :: `Usage: %[0]s [COMMAND]

Track simple recurring rituals and list the ones scheduled for today.

Commands:
  today      List rituals for the current date (default)
  version    Print version information
  help       Show this help

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
		switch err in command_today(out, errw) {
		case Command_Error:
			log.debug(err)
			os.exit(1)
		case runtime.Allocator_Error, os.Error:
			log.fatal(err)
			os.exit(1)
		}
	case "version":
		fmt.wprintfln(out, "%s %s", APP_NAME, APP_VERSION)
	case "help":
		fmt.wprintfln(out, HELP, APP_NAME)
	case:
		fmt.wprintfln(errw, "%s: unknown command '%s'", APP_NAME, cmd)
		fmt.wprintfln(errw, "Try '%s help' for more information.", APP_NAME)
		os.exit(1)
	}
}
