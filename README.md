<div align="center">
  <img src="u7.png" alt="u7 logo" width="480"><br>
  <a href="https://github.com/vitali87/u7/stargazers">
    <img src="https://img.shields.io/github/stars/vitali87/u7?style=social" alt="GitHub stars" />
  </a>
  <a href="https://github.com/vitali87/u7/network/members">
    <img src="https://img.shields.io/github/forks/vitali87/u7?style=social" alt="GitHub forks" />
  </a>
  <a href="https://github.com/vitali87/u7/blob/main/LICENSE">
    <img src="https://img.shields.io/github/license/vitali87/u7" alt="License" />
  </a>
</div>

# u7 - Universal 7 CLI

A unified command-line interface with 7 intuitive verbs for humans and AI agents.

## The Universal 7 Verbs

| Verb | Purpose | Example |
|------|---------|---------|
| `sh` | Observe/Search | `u7 sh ip external` |
| `mk` | Create/Clone | `u7 mk password length 16` |
| `dr` | Delete/Kill | `u7 dr file temp.txt` |
| `cv` | Transform/Extract | `u7 cv archive backup.tar.gz to files` |
| `mv` | Relocate/Rename | `u7 mv file old.txt to new.txt` |
| `st` | Modify/Config | `u7 st text "old" to "new" in file.txt` |
| `rn` | Execute/Control | `u7 rn job "echo done" in 5s` |

## Installation

Requires [Nix](https://nixos.org/download.html) with flakes enabled.

```bash
git clone https://github.com/vitali87/u7.git
cd u7
nix develop
```

You're now in a reproducible shell with all dependencies and `u7` ready to use.

## Usage

```bash
# Get help
u7 --help
u7 sh --help

# Network
u7 sh ip external
u7 sh ip internal
u7 sh ssl of google.com

# Files
u7 sh files match "TODO" in ./src
u7 sh files by modified
u7 sh csv first 10 from data.csv

# System
u7 sh cpu
u7 sh disk
u7 sh processes by cpu

# Create
u7 mk dir myproject
u7 mk password length 32
u7 mk archive backup.tar.gz from ./src

# Transform
u7 cv archive backup.tar.gz to files
u7 cv image photo.png to jpg yield photo.jpg
u7 cv json config.json to yaml

# Modify
u7 st text "foo" to "bar" in file.txt
u7 st perms to 755 on script.sh

# Execute
u7 rn job "echo done" in 10s
u7 rn ./long-task.sh in background
u7 rn ./script.sh with priority 10
u7 rn check syntax in files "*.sh"
```

## The Grammar

Every command follows a strict formula:

```
u7 <VERB> <ENTITY> [MODIFIER] [OPERATOR ARG]...
```

| Component | Role | Question to Ask |
|-----------|------|-----------------|
| **Verb** | The action (1 of 7) | What am I doing? |
| **Entity** | The noun being acted on | What thing am I manipulating? |
| **Modifier** | Variant or filter | Which subset or type? |
| **Operator Arg** | Relationship + value | From where? To what? How? |

### Operators

| Operator | Relationship | Example |
|----------|--------------|---------|
| `from` | Source | `mk archive backup.tar.gz from files` |
| `to` | Target state | `st owner to root`, `cv image x.png to jpg` |
| `yield` | File output | `cv image x.png to jpg yield out.jpg` |
| `in` | Container/location | `st text ... in file`, `rn job ... in 5s` |
| `on` | Target | `st perms to 755 on script.sh` |
| `by` | Criteria | `sh files by size` |
| `with` | Options | `rn ./script.sh with priority 10` |
| `match` | Filter | `sh files match "TODO"` |
| `but` | Exclusion | `dr files but "*.txt"` |
| `limit` | Count | `sh csv data.csv limit 10` |
| `length` | Size | `mk password length 16` |
| `of` | Possession | `sh ssl of google.com` |
| `if` | Condition | `dr dirs if empty` |

**Modifiers** (not operators — they filter the entity):

| Modifier | Type | Example |
|----------|------|---------|
| `first N` | Position | `sh lines first 10 from file` |
| `last N` | Position | `sh lines last 5 from file` |
| `external/internal` | Property | `sh ip external` |
| `empty` | Condition | `dr dirs if empty` |
| `blank` | Condition | `dr lines if blank from file` |

### The English Litmus Test

Read the command aloud. It must sound like (slightly robotic) English:

- `u7 sh lines first 10 from file` → "Show lines, first 10, from file" ✓
- `u7 st perms to 755 on script.sh` → "Set perms to 755 on script" ✓
- `u7 cv image a.png to jpg yield b.jpg` → "Convert image a.png to jpg, yield b.jpg" ✓

## Entity Reference

### sh (show) - Observe/Search
| Entity | Usage |
|--------|-------|
| `ip` | `sh ip <external\|internal\|connected>` |
| `csv` | `sh csv <file> [limit N]` |
| `json` | `sh json <file> [limit N]` |
| `line` | `sh line <number> from <file>` |
| `ssl` | `sh ssl of <domain>` |
| `files` | `sh files <match\|by> [pattern\|sort_type] [in <path>]` |
| `diff` | `sh diff <file1> to <file2>` |
| `cpu` | `sh cpu` |
| `memory` | `sh memory` |
| `disk` | `sh disk` |
| `processes` | `sh processes <running\|by> [cpu\|memory]` |
| `port` | `sh port <number>` |
| `usage` | `sh usage <disk\|directories> [path\|depth]` |
| `network` | `sh network` |
| `git` | `sh git <authors\|branches>` |
| `definition` | `sh definition of <word>` |
| `functions` | `sh functions` |

### mk (make) - Create/Clone
| Entity | Usage |
|--------|-------|
| `dir` | `mk dir <path>` |
| `file` | `mk file <path>` |
| `password` | `mk password length <N>` |
| `user` | `mk user <username>` |
| `copy` | `mk copy <src> to <dst>` |
| `link` | `mk link <src> to <dst>` |
| `archive` | `mk archive <output> from <files...>` |
| `sequence` | `mk sequence with prefix <prefix> limit <N>` |

### dr (drop) - Delete/Kill
| Entity | Usage |
|--------|-------|
| `file` | `dr file <path>` |
| `dir` | `dr dir <path>` |
| `dirs` | `dr dirs if empty` |
| `files` | `dr files but <pattern>` |
| `line` | `dr line <number> from <file>` |
| `lines` | `dr lines if blank from <in> yield <out>` |
| `column` | `dr column <number> from <file.csv>` |
| `duplicates` | `dr duplicates in\|from <file>` |
| `process` | `dr process <pid>` |
| `user` | `dr user <username>` |

### cv (convert) - Transform/Extract
| Entity | Usage |
|--------|-------|
| `archive` | `cv archive <archive> to files [yield <dest>]` |
| `files` | `cv files <files...> to archive yield <output>` |
| `image` | `cv image <input> to <format> [yield <output>]` |
| `video` | `cv video <input> to <format> [yield <output>]` |
| `json` | `cv json <input> to yaml [yield <output>]` |
| `case` | `cv case <upper\|lower> to <lower\|upper> on <files...>` |
| `spaces` | `cv spaces to underscores on <file>` |

### mv (move) - Relocate/Rename
| Entity | Usage |
|--------|-------|
| `file` | `mv file <source> to <destination>` |
| `sync` | `mv sync <source> to <destination>` |

### st (set) - Modify/Config
| Entity | Usage |
|--------|-------|
| `text` | `st text <old> to <new> in <file>` |
| `slashes` | `st slashes to <back\|forward> in <file>` |
| `tabs` | `st tabs to spaces in <directory>` |
| `perms` | `st perms to <mode> on <file>` |
| `owner` | `st owner to <user> on <file>` |

### rn (run) - Execute/Control
| Entity | Usage |
|--------|-------|
| `job` | `rn job <cmd> in <time>` |
| `script` | `rn script <path>` |
| `<command>` | `rn <command> in background` |
| `<command>` | `rn <command> with priority <nice>` |
| `check` | `rn check syntax in file <path>` |
| `check` | `rn check syntax in files <pattern>` |
| `terminal` | `rn terminal [limit <N>]` |

## Why u7?

- **Minimal vocabulary**: 7 verbs cover all Unix operations
- **Strict grammar**: `u7 <VERB> <ENTITY> [MODIFIER] [OPERATOR ARG]`
- **Aliases**: Full verbs (`show`, `make`, `drop`, `convert`, `move`, `set`, `run`) also supported
- **AI-friendly**: Predictable structure for humans and AI agents
- **Reproducible**: Nix ensures identical environments everywhere
- **Cross-platform**: Works on Linux and macOS

## Author

Vitali Avagyan: [@vitali87](https://github.com/vitali87)

## License

[![MIT License](https://img.shields.io/apm/l/atomic-design-ui.svg?)](https://choosealicense.com/licenses/mit/)

## Support

If you find this project helpful:

<a href="https://www.buymeacoffee.com/vitali87" target="_blank"><img src="https://cdn.buymeacoffee.com/buttons/default-orange.png" alt="Buy Me A Coffee" height="41" width="174"></a>
