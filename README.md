# ritual

A tiny command-line tool that tracks simple recurring rituals and lists the
ones scheduled for a given day — today by default — sorted by start time.

> This is a learning project for exploring [Odin](https://odin-lang.org) — its
> type system, manual memory management with arenas, and `core:` library. It is
> intentionally small and favours clarity over features.

```sh
$ ritual
[06:30 - 06:45] Mindfulness: Sit down meditation.
[21:00 - 21:25] Nightly Yoga: Wind-down activity before bed.
```

## What it does

A *ritual* is a recurring activity with a name, an optional description, a start
time, an end time, a repeat rule, and an optional list of steps. Each ritual
lives in its own JSON file. When you run it, the tool:

1. Reads all ritual files from the data directory.
2. Keeps only the rituals that repeat on the target day — today by default, or
   a weekday you name (a specific weekday, or daily).
3. Sorts them by start time and prints a one-line summary of each.

## Commands

```sh
ritual today      # list rituals for the current date (default)
ritual version    # print version information
ritual help       # show usage and available commands
```

With no command, `ritual` runs `today`.

You can also pass a weekday name to list that day's rituals instead of today's.
Names accept 2-letter, 3-letter, and full forms, case-insensitively:

```sh
ritual mo         # list Monday's rituals
ritual mon
ritual Monday
```

## Ritual format

Each ritual is a single JSON file. Its shape is described by
[`ritual.schema.json`](ritual.schema.json), a reference you can validate against:

```json
{
  "name": "Morning Run",
  "description": "Easy 5k around the neighborhood.",
  "start": "06:30",
  "end": "07:15",
  "repeat": ["Mo", "Wed", "Fri"],
  "steps": []
}
```

- **`description`** — an optional one-line summary. A ritual without one is
  listed by name alone, without a trailing `: description`.
- **`start`** / **`end`** — wall-clock times of day as `"HH:MM"` in 24-hour
  form, such as `"06:30"` or `"21:00"`. `end` must be after `start`.
- **`repeat`** — either the literal `"daily"`, or an array of weekdays. Weekday
  names accept 2-letter, 3-letter, and full forms, case-insensitively
  (`"mo"`, `"mon"`, `"Monday"` all mean Monday).
- **`steps`** — an optional list of sub-steps (currently not shown in the
  daily listing).

## Where rituals are stored

The tool reads files from the user data directory — on Linux that is
`$XDG_DATA_HOME/ritual`, falling back to `~/.local/share/ritual` when
`XDG_DATA_HOME` is unset.

```sh
mkdir -p ~/.local/share/ritual
cp my-ritual.json ~/.local/share/ritual/
```

## License

Released under the [MIT License](LICENSE).
