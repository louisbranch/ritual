package ritual

import "core:fmt"
import "core:log"
import "core:mem/virtual"
import "core:os"

APP_NAME :: "ritual"

main :: proc() {
	lowest := log.Level.Debug when ODIN_DEBUG else log.Level.Info
	context.logger = log.create_console_logger(lowest)
	defer log.destroy_console_logger(context.logger)

	switch {
	case len(os.args) < 2 || os.args[1] == "today":
		// arena holds everything the command loads and prints for one run.
		arena: virtual.Arena
		if err := virtual.arena_init_growing(&arena); err != nil {
			log.fatalf("failed to initialize memory: %v", err)
			os.exit(1)
		}
		defer virtual.arena_destroy(&arena)

		if _, err := command_today(virtual.arena_allocator(&arena)); err != nil {
			log.fatal(err)
			os.exit(1)
		}
	case os.args[1] == "help":
		fmt.printfln(
			"%s - available commands:\n\ttoday - lists rituals for the current date",
			APP_NAME,
		)
	case:
		fmt.println("Unknown command. See help.")
		os.exit(1)
	}
}
