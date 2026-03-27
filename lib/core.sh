# Check if a command is available
_u7_require() {
  local cmd="$1"
  local msg="${2:-$cmd}"
  if ! command -v "$cmd" &> /dev/null; then
    echo "Error: Required command '$cmd' not found."
    echo "Install it or run in 'nix develop' shell for full functionality."
    return 1
  fi
  return 0
}

# Escape special regex characters for literal sed replacement
_u7_escape_sed() {
  local str="$1"
  # Escape sed special chars: \ first, then . * [ ] ^ $ /
  str="${str//\\/\\\\}"  # Escape backslash
  str="${str//\//\\/}"    # Escape forward slash
  str="${str//./\\.}"     # Escape dot
  str="${str//\*/\\*}"    # Escape asterisk
  str="${str//\[/\\[}"    # Escape [
  str="${str//\]/\\]}"    # Escape ]
  str="${str//\^/\\^}"    # Escape ^
  str="${str//\$/\\$}"    # Escape $
  printf '%s' "$str"
}

# Dry-run mode: show command without executing
_U7_DRY_RUN=0

_u7_exec() {
  if [[ "$_U7_DRY_RUN" == "1" ]]; then
    echo "[dry-run] $*"
  else
    "$@"
  fi
}
