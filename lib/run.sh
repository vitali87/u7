_u7_run() {
  local entity="$1"
  shift

  case "$entity" in
    job)
      local cmd="$1"
      if [[ "$2" != "in" ]]; then
        echo "Usage: u7 rn job <command> in <time>"
        return 1
      fi
      local time="$3"
      local unit="${time//[0-9]/}"
      local value="${time//[^0-9]/}"

      if [[ "$_U7_DRY_RUN" == "1" ]]; then
        case "$unit" in
          s) echo "[dry-run] sleep $value && eval '$cmd' &" ;;
          m) echo "[dry-run] sleep $((value * 60)) && eval '$cmd' &" ;;
          h) echo "[dry-run] sleep $((value * 3600)) && eval '$cmd' &" ;;
          *) echo "Use: Ns, Nm, or Nh (e.g., 5s, 10m, 1h)" ; return 1 ;;
        esac
      else
        case "$unit" in
          s) sleep "$value" && eval "$cmd" & ;;
          m) sleep "$((value * 60))" && eval "$cmd" & ;;
          h) sleep "$((value * 3600))" && eval "$cmd" & ;;
          *) echo "Use: Ns, Nm, or Nh (e.g., 5s, 10m, 1h)" ; return 1 ;;
        esac
        echo "Scheduled: '$cmd' in $time"
      fi
      ;;

    script)
      local script="$1"
      if [[ ! -f "$script" ]]; then
        echo "Script not found: $script"
        return 1
      fi
      _u7_exec bash "$script"
      ;;

    check)
      if [[ "$1" != "syntax" ]]; then
        echo "Usage: u7 rn check syntax in <file|files> <path|pattern>"
        return 1
      fi
      if [[ "$2" != "in" ]]; then
        echo "Usage: u7 rn check syntax in <file|files> <path|pattern>"
        return 1
      fi
      case "$3" in
        file)
          bash -n "$4"
          ;;
        files)
          find . -name "$4" -exec bash -n {} \;
          echo "Syntax check complete"
          ;;
        *)
          echo "Usage: u7 rn check syntax in <file|files> <path|pattern>"
          return 1
          ;;
      esac
      ;;

    terminal)
      local count=1
      if [[ "$1" == "limit" ]]; then
        count="$2"
      fi
      local term_cmd
      term_cmd=$(ps -o comm= -p "$(($(ps -o ppid= -p "$(($(ps -o sid= -p "$$")))")))")
      if [[ "$_U7_DRY_RUN" == "1" ]]; then
        echo "[dry-run] $term_cmd & (x$count)"
      else
        for _ in $(seq 1 "$count"); do
          $term_cmd &
        done
      fi
      ;;

    watch)
      local file="$1"
      if [[ -z "$file" || "$2" != "run" ]]; then
        echo "Usage: u7 rn watch <file> run <command>"
        return 1
      fi
      if [[ ! -e "$file" ]]; then
        echo "File not found: $file"
        return 1
      fi
      shift 2
      local cmd="$*"
      if [[ -z "$cmd" ]]; then
        echo "Usage: u7 rn watch <file> run <command>"
        return 1
      fi
      if [[ "$_U7_DRY_RUN" == "1" ]]; then
        echo "[dry-run] watch $file and run $cmd on change"
        return 0
      fi
      echo "Watching $file for changes... (Ctrl+C to stop)"
      if command -v inotifywait &>/dev/null; then
        while true; do
          inotifywait -qq -e modify "$file"
          eval "$cmd"
        done
      else
        local last_mod
        last_mod=$(stat -c %Y "$file" 2>/dev/null || stat -f %m "$file" 2>/dev/null)
        while true; do
          sleep 1
          local cur_mod
          cur_mod=$(stat -c %Y "$file" 2>/dev/null || stat -f %m "$file" 2>/dev/null)
          if [[ "$cur_mod" != "$last_mod" ]]; then
            last_mod="$cur_mod"
            eval "$cmd"
          fi
        done
      fi
      ;;

    --help|-h)
      cat << 'EOF'
u7 rn (run) - Execute/Control

Usage: u7 rn <entity> [arguments]

Entities:
  job <cmd> in <time>                    Schedule command (5s, 10m, 1h)
  script <path>                          Execute shell script
  watch <file> run <command>             Watch file and run command on change
  <command> in background                Run command in background
  <command> with priority <nice>         Run with CPU priority
  check syntax in file <path>            Check single file syntax
  check syntax in files <pattern>        Check files matching pattern
  terminal [limit <N>]                   Open new terminal(s)
EOF
      ;;

    *)
      # Handle: u7 rn <command> in background
      # Handle: u7 rn <command> with priority <nice>
      local cmd="$entity"
      if [[ "$1" == "in" && "$2" == "background" ]]; then
        if [[ "$_U7_DRY_RUN" == "1" ]]; then
          echo "[dry-run] $cmd &"
        else
          eval "$cmd" &
          echo "PID: $!"
        fi
      elif [[ "$1" == "with" && "$2" == "priority" ]]; then
        local niceness="$3"
        if [[ "$_U7_DRY_RUN" == "1" ]]; then
          echo "[dry-run] nice -n $niceness $cmd"
        else
          nice -n "$niceness" bash -c "$cmd"
        fi
      else
        echo "Unknown entity: $entity"
        echo "Run 'u7 rn --help' for usage"
        return 1
      fi
      ;;
  esac
}
