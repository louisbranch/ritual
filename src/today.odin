package ritual

import "base:runtime"
import "core:fmt"
import "core:log"
import "core:os"
import "core:slice"
import "core:strings"
import "core:time"

Command_Today :: struct {
	path:    string,
	entries: #soa[dynamic]Ritual_Parse,
}

// command_today loads every ritual document under the user data dir, reports
// any per-file errors, and prints the rituals scheduled for today. Everything
// it returns is allocated in `allocator`, so the caller owns the lifetime.
command_today :: proc(allocator: runtime.Allocator) -> (cmd: Command_Today, err: os.Error) {
	data_path := os.user_data_dir(allocator) or_return

	dir_path := os.join_path({data_path, APP_NAME}, allocator) or_return
	cmd.path = dir_path

	files := os.read_all_directory_by_path(dir_path, allocator) or_return

	entries := make(#soa[dynamic]Ritual_Parse, len(files), allocator)

	for f, i in files {
		data, read_err := os.read_entire_file_from_path(f.fullpath, allocator)
		if read_err != nil {
			entries[i] = {
				file  = f.name,
				error = .Read_Error,
			}

			continue
		}

		entry := ritual_json_decode(data, allocator)
		entry.file = f.name
		entries[i] = entry
	}
	cmd.entries = entries

	for e in entries {
		switch e.error {
		case .None:
			log.debugf("ok - %s", e.file)
		case .Read_Error:
			log.errorf("failed to read %s %v", e.file, e.error)
		case .JSON_Error:
			log.errorf("failed to parse JSON %s %v", e.file, e.error)
		case .Field_Error:
			b := strings.builder_make(allocator)
			for field_err, field in e.validation {
				if field_err == .None do continue
				fmt.sbprintfln(&b, "  %v: %v", field, field_err)
			}
			log.errorf("failed to validate fields in %s:\n%s", e.file, strings.to_string(b))
		}
	}

	// Clone the ritual column before sorting: soa_unzip aliases the entries'
	// backing store, so sorting in place would desync the returned entries.
	_, ritual_col, _, _ := soa_unzip(entries[:])
	rituals := slice.clone(ritual_col, allocator)
	slice.sort_by(rituals, proc(a, b: Ritual) -> bool {return a.start < b.start})

	today := local_date(time.now(), allocator)

	for r in rituals {
		if is_today(r, today) {
			fmt.printfln(ritual_to_string(r, allocator))
		} else {
			log.debugf("Skip ritual: %s", r.name)
		}
	}

	return cmd, nil
}
