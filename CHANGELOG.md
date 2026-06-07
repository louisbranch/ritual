# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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

[0.2.2]: https://github.com/louisbranch/ritual/compare/v0.2.1...v0.2.2
[0.2.1]: https://github.com/louisbranch/ritual/compare/v0.2.0...v0.2.1
[0.2.0]: https://github.com/louisbranch/ritual/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/louisbranch/ritual/releases/tag/v0.1.0
