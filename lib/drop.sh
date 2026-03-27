_u7_drop() {
  local entity="$1"
  shift

  case "$entity" in
    file)
      if [[ -z "$1" ]]; then
        echo "Usage: u7 dr file <path>"
        return 1
      fi
      _u7_exec rm -i "$1"
      ;;

    dir)
      if [[ -z "$1" ]]; then
        echo "Usage: u7 dr dir <path>"
        return 1
      fi
      _u7_exec rm -ri "$1"
      ;;

    dirs)
      if [[ "$1" == "if" && "$2" == "empty" ]]; then
        _u7_exec find . -type d -empty -delete
        [[ "$_U7_DRY_RUN" != "1" ]] && echo "Deleted empty directories"
      else
        echo "Usage: u7 dr dirs if empty"
      fi
      ;;

    files)
      if [[ "$1" == "but" ]]; then
        local pattern="$2"
        if [[ "$_U7_DRY_RUN" == "1" ]]; then
          echo "[dry-run] find . -type f ! -name $pattern -delete"
        else
          echo "This will delete all files but '$pattern'. Continue? (y/n)"
          read -r confirm
          if [[ "$confirm" == "y" ]]; then
            find . -type f ! -name "$pattern" -delete
          else
            echo "Aborted."
          fi
        fi
      else
        echo "Usage: u7 dr files but <pattern>"
      fi
      ;;

    line)
      local num="$1"
      if [[ "$2" != "from" ]]; then
        echo "Usage: u7 dr line <number> from <file>"
        return 1
      fi
      local file="$3"
      if [[ -z "$num" || -z "$file" ]]; then
        echo "Usage: u7 dr line <number> from <file>"
        return 1
      fi
      if [[ "$_U7_DRY_RUN" == "1" ]]; then
        echo "[dry-run] sed -i'' ${num}d $file"
      else
        sed -i'' "${num}d" "$file"
      fi
      ;;

    lines)
      if [[ "$1" == "if" && "$2" == "blank" && "$3" == "from" && "$5" == "yield" ]]; then
        local src="$4"
        local dst="$6"
        if [[ "$_U7_DRY_RUN" == "1" ]]; then
          echo "[dry-run] grep . $src > $dst"
        else
          grep . "$src" > "$dst"
        fi
      else
        echo "Usage: u7 dr lines if blank from <input> yield <output>"
      fi
      ;;

    column)
      local num="$1"
      if [[ "$2" != "from" ]]; then
        echo "Usage: u7 dr column <number> from <file.csv>"
        return 1
      fi
      local file="$3"
      if [[ -z "$num" || -z "$file" ]]; then
        echo "Usage: u7 dr column <number> from <file.csv>"
        return 1
      fi
      if [[ "$_U7_DRY_RUN" == "1" ]]; then
        echo "[dry-run] cut -d',' -f$num --complement $file"
      else
        local tmpfile
        tmpfile=$(mktemp "${file}.XXXXXX") || { echo "Error: Failed to create temp file"; return 1; }
        cut -d',' -f"$num" --complement "$file" > "$tmpfile" && mv "$tmpfile" "$file" || { rm -f "$tmpfile"; return 1; }
      fi
      ;;

    duplicates)
      if [[ "$1" != "in" && "$1" != "from" ]]; then
        echo "Usage: u7 dr duplicates in|from <file>"
        return 1
      fi
      local file="$2"
      if [[ -z "$file" ]]; then
        echo "Usage: u7 dr duplicates in|from <file>"
        return 1
      fi
      if [[ "$_U7_DRY_RUN" == "1" ]]; then
        echo "[dry-run] awk '!x[\$0]++' $file"
      else
        local tmpfile
        tmpfile=$(mktemp "${file}.XXXXXX") || { echo "Error: Failed to create temp file"; return 1; }
        awk '!x[$0]++' "$file" > "$tmpfile" && mv "$tmpfile" "$file" || { rm -f "$tmpfile"; return 1; }
      fi
      ;;

    process)
      local pid="$1"
      if [[ -z "$pid" ]]; then
        echo "Usage: u7 dr process <pid>"
        return 1
      fi
      _u7_exec kill "$pid"
      ;;

    user)
      if [[ -z "$1" ]]; then
        echo "Usage: u7 dr user <username>"
        return 1
      fi
      _u7_exec sudo deluser "$1"
      ;;

    --help|-h)
      cat << 'EOF'
u7 dr (drop) - Delete/Kill

Usage: u7 dr <entity> [arguments]

Entities:
  file <path>                   Delete file (with confirmation)
  dir <path>                    Delete directory (with confirmation)
  dirs if empty                 Delete all empty directories
  files but <pattern>           Delete all files but <pattern>
  line <number> from <file>     Delete line from file
  lines if blank from <in> yield <out>  Remove blank lines
  column <number> from <file>  Delete column from CSV
  duplicates in|from <file>     Remove duplicate lines
  process <pid>                 Kill process
  user <username>               Delete system user
EOF
      ;;

    *)
      echo "Unknown entity: $entity"
      echo "Run 'u7 dr --help' for usage"
      return 1
      ;;
  esac
}
