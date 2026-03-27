_u7_move() {
  local entity="$1"
  shift

  case "$entity" in
    file)
      local src="$1"
      if [[ "$2" == "to" ]]; then
        local dst="$3"
        _u7_exec mv "$src" "$dst"
      else
        echo "Usage: u7 mv file <source> to <destination>"
        return 1
      fi
      ;;
    sync)
      local src_dir="$1"
      if [[ "$2" == "to" ]]; then
        local dst_dir="$3"
        _u7_exec rsync -avz "$src_dir" "$dst_dir"
      else
        echo "Usage: u7 mv sync <source> to <destination>"
        return 1
      fi
      ;;
    --help|-h)
      cat << 'EOF'
u7 mv (move) - Relocate/Rename

Usage: u7 mv file <source> to <destination>
       u7 mv sync <source> to <destination>

Examples:
  u7 mv file notes.txt to /backup/
  u7 mv file old.txt to new.txt
  u7 mv sync local/ to remote/
EOF
      ;;
    *)
      echo "Usage: u7 mv file <source> to <destination>"
      return 1
      ;;
  esac
}
