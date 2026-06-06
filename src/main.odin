package ritual

import "core:fmt"
import "core:log"
import "core:mem/virtual"
import "core:os"
import "core:time"

APP_NAME :: "ritual"

main :: proc() {
	lowest := log.Level.Debug when ODIN_DEBUG else log.Level.Info
	context.logger = log.create_console_logger(lowest)
	defer log.destroy_console_logger(context.logger)

	// arena holds the rituals for the whole run.
	arena: virtual.Arena
	if err := virtual.arena_init_growing(&arena); err != nil {
		log.fatalf("failed to initialize memory: %v", err)
		os.exit(1)
	}
	defer virtual.arena_destroy(&arena)
	allocator := virtual.arena_allocator(&arena)

	// scratch holds the path strings, directory listing and raw file bytes
	// needed only while loading; it is thrown away once the rituals are parsed.
	scratch: virtual.Arena
	if err := virtual.arena_init_growing(&scratch); err != nil {
		log.fatalf("failed to initialize memory: %v", err)
		os.exit(1)
	}
	scratch_alloc := virtual.arena_allocator(&scratch)

	data_path, data_err := os.user_data_dir(scratch_alloc)
	if data_err != nil {
		log.fatalf("failed to get user data dir: %v", data_err)
		os.exit(1)
	}

	dir_path, join_err := os.join_path({data_path, APP_NAME}, scratch_alloc)
	if join_err != nil {
		log.fatalf("failed to join data path %s/%s: %v", data_path, APP_NAME, join_err)
		os.exit(1)
	}

	rituals, load_err := load_rituals_from_dir(dir_path, allocator, scratch_alloc)
	if load_err.cause != nil {
		log.fatalf(
			"failed to load rituals from %s: %s",
			dir_path,
			load_error_to_string(load_err, scratch_alloc),
		)
		os.exit(1)
	}

	today := local_date(time.now(), scratch_alloc)

	// The rituals and `today` are now independent of scratch; reclaim it.
	virtual.arena_destroy(&scratch)

	for r in rituals {
		if is_today(r, today) {
			fmt.printfln(ritual_to_string(r, allocator))
		} else {
			log.debugf("Skip ritual: %s", r.name)
		}
	}
}
