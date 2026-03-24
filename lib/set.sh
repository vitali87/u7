_u7_set() {
  local entity="$1"
  shift

  case "$entity" in
    text)
      local old="$1"
      if [[ "$2" != "to" ]]; then
        echo "Usage: u7 st text <old> to <new> in <file|directory>"
        return 1
      fi
      local new="$3"
      if [[ "$4" != "in" ]]; then
        echo "Usage: u7 st text <old> to <new> in <file|directory>"
        return 1
      fi
      local target="$5"

      # Escape special regex characters for literal matching
      local old_escaped=$(_u7_escape_sed "$old")
      local new_escaped=$(_u7_escape_sed "$new")

      if [[ "$_U7_DRY_RUN" == "1" ]]; then
        if [[ -d "$target" ]]; then
          echo "[dry-run] grep -rlF '$old' $target | xargs sed -i'' 's/$old_escaped/$new_escaped/g'"
        else
          echo "[dry-run] sed -i'' 's/$old_escaped/$new_escaped/g' $target"
        fi
      else
        if [[ -d "$target" ]]; then
          # Use grep with -F for literal string matching, then sed for replacement
          local -a matched_files=()
          mapfile -t matched_files < <(grep -rlF "$old" "$target" 2>/dev/null)

          if [[ ${#matched_files[@]} -eq 0 ]]; then
            echo "No files containing '$old' found in $target"
            return 0
          fi

          echo "Will replace '$old' with '$new' in ${#matched_files[@]} file(s) under $target. Continue? (y/n)"
          read -r confirm
          if [[ "${confirm,,}" != "y" ]]; then
            echo "Aborted."
            return 0
          fi

          for file in "${matched_files[@]}"; do
            sed -i'' "s/$old_escaped/$new_escaped/g" "$file"
          done
        else
          sed -i'' "s/$old_escaped/$new_escaped/g" "$target"
        fi
      fi
      ;;

    slashes)
      if [[ "$1" != "to" ]]; then
        echo "Usage: u7 st slashes to <back|forward> in <file>"
        return 1
      fi
      local direction="$2"
      if [[ "$3" != "in" ]]; then
        echo "Usage: u7 st slashes to <back|forward> in <file>"
        return 1
      fi
      local file="$4"
      if [[ "$direction" == "back" ]]; then
        if [[ "$_U7_DRY_RUN" == "1" ]]; then
          echo "[dry-run] sed -i'' 's|/|\\\\|g' $file"
        else
          sed -i'' 's|/|\\|g' "$file"
        fi
      elif [[ "$direction" == "forward" ]]; then
        if [[ "$_U7_DRY_RUN" == "1" ]]; then
          echo "[dry-run] sed -i'' 's|\\\\\\\\|/|g' $file"
        else
          sed -i'' 's|\\\\|/|g' "$file"
        fi
      else
        echo "Usage: u7 st slashes to <back|forward> in <file>"
        return 1
      fi
      ;;

    tabs)
      if [[ "$1" == "to" && "$2" == "spaces" ]]; then
        if [[ "$3" != "in" ]]; then
            echo "Usage: u7 st tabs to spaces in <directory>"
            return 1
        fi
        if [[ "$_U7_DRY_RUN" == "1" ]]; then
          echo "[dry-run] Replace tabs with spaces in text files under '${4:-.}'"
        else
          grep -rl $'\t' "${4:-.}" 2>/dev/null | while IFS= read -r file; do
            # grep -qI '' exits 0 for text files, 1 for binary files
            if grep -qI '' "$file" 2>/dev/null; then
              sed -i'' 's/\t/  /g' "$file"
            fi
          done
        fi
      else
        echo "Usage: u7 st tabs to spaces in <directory>"
      fi
      ;;

    perms)
      if [[ "$1" != "to" ]]; then
        echo "Usage: u7 st perms to <mode> on <file>"
        return 1
      fi
      local mode="$2"
      if [[ "$3" != "on" ]]; then
        echo "Usage: u7 st perms to <mode> on <file>"
        return 1
      fi
      local target="$4"
      _u7_exec chmod "$mode" "$target"
      ;;

    owner)
      if [[ "$1" != "to" ]]; then
        echo "Usage: u7 st owner to <user> on <file>"
        return 1
      fi
      local user="$2"
      if [[ "$3" != "on" ]]; then
        echo "Usage: u7 st owner to <user> on <file>"
        return 1
      fi
      local target="$4"
      _u7_exec chown "$user" "$target"
      ;;

    --help|-h)
      cat << 'EOF'
u7 st (set) - Modify/Config

Usage: u7 st <entity> [arguments]

Entities:
  text <old> to <new> in <file>           Replace text in file(s)
  slashes to <back|forward> in <file>     Convert slashes
  tabs to spaces in <directory>           Convert tabs to spaces
  perms to <mode> on <file>               Set file permissions
  owner to <user> on <file>               Set file owner
EOF
      ;;

    *)
      echo "Unknown entity: $entity"
      echo "Run 'u7 st --help' for usage"
      return 1
      ;;
  esac
}
