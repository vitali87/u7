#!/usr/bin/env bash

_U7_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "$_U7_DIR/lib/core.sh"
source "$_U7_DIR/lib/show.sh"
source "$_U7_DIR/lib/make.sh"
source "$_U7_DIR/lib/drop.sh"
source "$_U7_DIR/lib/convert.sh"
source "$_U7_DIR/lib/move.sh"
source "$_U7_DIR/lib/set.sh"
source "$_U7_DIR/lib/run.sh"
source "$_U7_DIR/lib/completions.sh"

u7() {
  _U7_DRY_RUN=0

  if [[ "$1" == "--dry-run" || "$1" == "-n" ]]; then
    _U7_DRY_RUN=1
    shift
  fi

  local verb="$1"
  shift

  case "$verb" in
    show|sh)       _u7_show "$@" ;;
    make|mk)       _u7_make "$@" ;;
    drop|dr)       _u7_drop "$@" ;;
    convert|cv)    _u7_convert "$@" ;;
    move|mv)       _u7_move "$@" ;;
    set|st)        _u7_set "$@" ;;
    run|rn)        _u7_run "$@" ;;
    --help|-h|"")  _u7_help ;;
    *)
      echo "Unknown verb: $verb"
      _u7_help
      return 1
      ;;
  esac
}

_u7_help() {
  cat << 'EOF'
Universal 7 (u7) - Human+AI CLI Standard

Usage: u7 [-n|--dry-run] <verb> <entity> [operator] [arguments]

Options:
  -n, --dry-run   Show command without executing

Verbs:
  sh (show)     Observe/Search
  mk (make)     Create/Clone
  dr (drop)     Delete/Kill
  cv (convert)  Transform/Extract
  mv (move)     Relocate/Rename
  st (set)      Modify/Config
  rn (run)      Execute/Control

Examples:
  u7 sh ip external
  u7 sh csv data.csv limit 10
  u7 mk dir myproject
  u7 mk password length 16
  u7 dr file temp.txt
  u7 cv archive backup.tar.gz to files yield ./
  u7 cv image photo.png to jpg yield photo.jpg
  u7 mv file old.txt to new.txt
  u7 st text "old" to "new" in file.txt
  u7 rn job "echo done" in 5s

Run 'u7 <verb> --help' for verb-specific help.
EOF
}
