package ritual

import "core:fmt"
import "core:log"
import "core:mem/virtual"
import "core:os"
import "core:time"

APP_NAME :: "ritual"

main :: proc() {
	context.logger = log.create_console_logger()
	defer log.destroy_console_logger(context.logger)

	arena: virtual.Arena
	if err := virtual.arena_init_growing(&arena); err != nil {
		log.fatalf("failed to initialize memory: %v", err)
		os.exit(1)
	}

	defer virtual.arena_destroy(&arena)

	allocator := virtual.arena_allocator(&arena)

	data_path, data_err := os.user_data_dir(allocator)
	if data_err != nil {
		log.fatalf("failed to get user data dir: %v", data_err)
		os.exit(1)
	}

	dir_path, join_err := os.join_path({data_path, APP_NAME}, allocator)
	if join_err != nil {
		log.fatalf("failed to join data path %q/%s: %v", data_path, APP_NAME, join_err)
		os.exit(1)
	}

	rituals, load_err := load_rituals_from_dir(dir_path, allocator)
	if load_err != nil {
		log.fatalf("failed to load rituals from %q: %v", dir_path, load_err)
		os.exit(1)
	}

	today := local_date(time.now(), allocator)

	for r in rituals {
		if is_today(r, today) {
			fmt.printfln("%s - %s", r.name, r.description)
		} else {
			log.debugf("Skip ritual: %s", r.name)
		}
	}
}
