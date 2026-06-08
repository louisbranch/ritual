package ritual

import "base:runtime"
import "core:fmt"
import "core:io"
import "core:log"
import "core:mem/virtual"
import "core:os"
import "core:slice"
import "core:strings"
import "core:time"

// command_today loads every ritual document under the user data dir, reports
// any per-file errors, and prints the rituals scheduled for today, sorted by
// start time.
command_today :: proc(out, errw: io.Writer) -> Error {
	arena: virtual.Arena
	virtual.arena_init_growing(&arena) or_return
	defer virtual.arena_destroy(&arena)

	allocator := virtual.arena_allocator(&arena)

	data_path := os.user_data_dir(allocator) or_return
	dir_path := os.join_path({data_path, APP_NAME}, allocator) or_return

	entries, err := rituals_parse(dir_path, allocator)
	if err == os.General_Error.Not_Exist {
		fmt.wprintfln(errw, "directory doesn't exist: %s", dir_path)
		return .No_Data_Directory
	}
	if err != nil do return err

	if len(entries) == 0 {
		fmt.wprintfln(errw, "no rituals found in %s", dir_path)
		return .No_Files
	}

	rituals := make([dynamic]Ritual, 0, len(entries), allocator)

	weekday := local_weekday(time.now(), allocator)

	for e in entries {
		switch e.error {
		case .None:
			if weekday in e.ritual.repeat {
				append(&rituals, e.ritual)
			} else {
				log.debugf("skip - %s: %w", e.ritual.name, e.ritual.repeat)
			}
		case .Read_Error:
			log.errorf("failed to read %s %v", e.file, e.error)
		case .JSON_Error:
			log.errorf("failed to parse %s %v", e.file, e.error)
		case .Field_Error:
			b := strings.builder_make(allocator)
			for err, field in e.validation {
				if err == .None do continue
				fmt.sbprintfln(&b, "  %v: %v", field, err)
			}
			log.errorf("failed to validate fields in %s:\n%s", e.file, strings.to_string(b))
		}
	}

	if len(rituals) == 0 {
		fmt.wprintfln(out, "no rituals scheduled for today (%v)", weekday)
		return nil
	}

	slice.sort_by(rituals[:], proc(a, b: Ritual) -> bool {return a.start < b.start})

	for r in rituals do fmt.wprintln(out, ritual_to_string(r, allocator))

	return nil
}
