# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.3.1] - 2026-06-10

### Fixed

- `time_parse` now rejects `+` signs and `_` digit separators in `HH:MM`
  fields, which `strconv.parse_uint` silently accepted.
- A start-time parse error no longer leaks into the end-before-start check:
  each field validation now uses its own error, so an invalid start with a
  `00:00` end reports the parse error instead of a spurious range error.

### Changed

- `weekday_parse` matches names by case-folded prefix against a weekday table
  instead of a hand-lowered switch.
- Ritual steps and parse results are returned as slices rather than dynamic
  arrays.
- `ritual_to_string` formats times with `fmt.aprintf` instead of trimming
  `duration_to_string_hms` output.

## [0.3.0] - 2026-06-08

### Added

- `today` now reports a clear error and exits when the user data directory does
  not exist, instead of failing opaquely.
- `today` prints `no rituals found` when the data directory contains no ritual
  documents.

### Changed

- Extracted directory loading into `rituals_parse`, which decodes every ritual
  document in a given directory; `command_today` now resolves the user data dir
  and delegates to it.
- `command_today` owns its own growing arena for a run instead of taking an
  allocator from the caller.
- `rituals_parse` skips non-regular directory entries instead of attempting to
  parse them.

## [0.2.2] - 2026-06-07

### Fixed

- JSON parse failures now report the offending file name instead of an empty
  path, matching the other `today` load errors.

## [0.2.1] - 2026-06-07

### Changed

- `ritual_json_decode` now reads a ritual file by path directly, consolidating
  the file IO that was previously duplicated in `command_today`.
- Documented the available commands and the `build/` binary path in the README.

### Fixed

- `today` no longer prints rituals that failed to parse or validate; only
  successfully parsed rituals are scheduled and printed.

## [0.2.0] - 2026-06-07

### Added

- `today` command, which lists the rituals scheduled for the current day.

### Changed

- Restructured load errors and renamed types and procedures for `noun_verb`
  consistency.
- Help, version, and unknown-command output now follow Unix conventions.
- Binaries are now written to the `build/` directory.

## [0.1.0] - 2026-06-06

### Added

- Initial release of the `ritual` CLI: schedule parsing and local-timezone day
  matching.
- File parser error reporting.
- Split memory into separate scratch and data arenas.
- Release build target.

[0.3.1]: https://github.com/louisbranch/ritual/compare/v0.3.0...v0.3.1
[0.3.0]: https://github.com/louisbranch/ritual/compare/v0.2.2...v0.3.0
[0.2.2]: https://github.com/louisbranch/ritual/compare/v0.2.1...v0.2.2
[0.2.1]: https://github.com/louisbranch/ritual/compare/v0.2.0...v0.2.1
[0.2.0]: https://github.com/louisbranch/ritual/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/louisbranch/ritual/releases/tag/v0.1.0
