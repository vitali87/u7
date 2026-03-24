#!/usr/bin/env bash

_U7_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck disable=SC1090
for _u7_mod in core show make drop convert move set run completions; do
  source "$_U7_DIR/lib/${_u7_mod}.sh" || { echo "u7: failed to load lib/${_u7_mod}.sh" >&2; unset _u7_mod _U7_DIR; return 1; }
done
unset _u7_mod _U7_DIR

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

_u7_show() {
  local entity="$1"
  shift

  case "$entity" in
    ip)
      case "$1" in
        external) curl -s ifconfig.me && echo ;;
        internal)
          ifconfig | grep -oE 'inet (addr:)?[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' | grep -oE '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' | grep -v '^127\.' | head -1
          ;;
        connected) netstat -an | grep ESTABLISHED | awk '{print $5}' | awk -F: '{print $1}' | sort -u ;;
        *) echo "Usage: u7 sh ip <external|internal|connected>" ;;
      esac
      ;;

    csv)
      _u7_require qsv || return 1
      local file="$1"
      # $2 is "limit" keyword, $3 is the actual number
      local limit="${3:-25}"
      if [[ ! -f "$file" ]]; then
        echo "File not found: $file"
        return 1
      fi
      # If user didn't provide "limit" keyword, use default
      if [[ "$2" == "limit" && -n "$3" ]]; then
        limit="$3"
      fi
      qsv table "$file" | head -n "$((limit + 1))"
      ;;

    json)
      local file="$1"
      # $2 is "limit" keyword, $3 is the actual number
      local limit="10"
      if [[ ! -f "$file" ]]; then
        echo "File not found: $file"
        return 1
      fi
      # If user provided "limit" keyword, use their number
      if [[ "$2" == "limit" && -n "$3" ]]; then
        limit="$3"
      fi
      jq ".[:$limit]" "$file"
      ;;

    line)
      local num="$1"
      if [[ "$2" != "from" ]]; then
        echo "Usage: u7 sh line <number> from <file>"
        return 1
      fi
      local file="$3"
      sed -n "${num}p" "$file"
      ;;

    ssl)
      if [[ "$1" != "of" ]]; then
        echo "Usage: u7 sh ssl of <domain>"
        return 1
      fi
      local domain="$2"
      if [[ -z "$domain" ]]; then
        echo "Usage: u7 sh ssl of <domain>"
        return 1
      fi
      echo | openssl s_client -connect "$domain":443 2>/dev/null | openssl x509 -dates -noout
      ;;

    files)
      case "$1" in
        match)
          local pattern="$2"
          local path="."
          if [[ "$3" == "in" ]]; then
            path="${4:-.}"
          fi
          grep -RnisI "$pattern" "$path"
          ;;
        by)
          local limit="20"
          if [[ "$3" == "limit" && -n "$4" ]]; then
            if ! [[ "$4" =~ ^[0-9]+$ ]]; then
              echo "Error: limit must be a positive integer, got '$4'"
              return 1
            fi
            limit="$4"
          fi
          case "$2" in
            modified) find . -type f -exec stat -c "%Y %n" {} \; | sort -rn | head -"$limit" | cut -d' ' -f2- ;;
            size) find . -type f -exec stat -c "%s %n" {} \; | sort -rn | head -"$limit" ;;
            *) echo "Usage: u7 sh files by <modified|size> [limit N]" ;;
          esac
          ;;
        *) echo "Usage: u7 sh files <match <pattern> [in <path>]|by <modified|size> [limit N]>" ;;
      esac
      ;;

    diff)
      local file1="$1"
      if [[ "$2" != "to" ]]; then
        echo "Usage: u7 sh diff <file1> to <file2>"
        return 1
      fi
      local file2="$3"
      diff "$file1" "$file2"
      ;;

    # TODO: Revisit cpu/memory/disk entity structure for granular queries (e.g. u7 sh cpu temp)
    cpu)
      cat /proc/cpuinfo 2>/dev/null || sysctl -a 2>/dev/null | grep -E 'machdep.cpu|hw.ncpu'
      ;;

    memory)
      free -h 2>/dev/null || vm_stat 2>/dev/null
      ;;

    disk)
      df -h
      ;;

    processes)
      case "$1" in
        running)
          if [[ "$2" == "match" && -n "$3" ]]; then
            ps aux | { head -1; grep -i "$3" | grep -v "grep -i"; }
          else
            ps aux
          fi
          ;;
        by)
          local limit="10"
          if [[ "$3" == "limit" && -n "$4" ]]; then
            if ! [[ "$4" =~ ^[0-9]+$ ]]; then
              echo "Error: limit must be a positive integer, got '$4'"
              return 1
            fi
            limit="$4"
          fi
          case "$2" in
            cpu) ps aux | sort -k3 -rn | head -"$limit" ;;
            memory) ps aux | sort -k4 -rn | head -"$limit" ;;
            *) echo "Usage: u7 sh processes by <cpu|memory> [limit N]" ;;
          esac
          ;;
        *) echo "Usage: u7 sh processes <running [match <pattern>]|by <cpu|memory> [limit N]>" ;;
      esac
      ;;

    port)
      lsof -i tcp:"$1"
      ;;

    usage)
      case "$1" in
        disk) du -sh "${2:-.}" ;;
        directories) du -h --max-depth "${2:-1}" | sort -hr ;;
        *) echo "Usage: u7 sh usage <disk|directories> [path|depth]" ;;
      esac
      ;;

    network)
      ifconfig -a
      ;;

    git)
      case "$1" in
        authors) git log --format='%aN' | sort -u ;;
        branches)
          for k in $(git branch | sed 's/^..//'); do
            echo -e "$(git show --pretty=format:"%ci %cr" "$k" -- | head -n 1)\t$k"
          done | sort -r
          ;;
        tags) git tag -l --sort=-v:refname ;;
        log)
          local limit="${2:-10}"
          if ! [[ "$limit" =~ ^[0-9]+$ ]]; then
            echo "Error: limit must be a positive integer, got '$limit'"
            return 1
          fi
          git log --oneline -"$limit"
          ;;
        status) git status --short ;;
        diff) git diff ;;
        remotes) git remote -v ;;
        *) echo "Usage: u7 sh git <authors|branches|tags|log [N]|status|diff|remotes>" ;;
      esac
      ;;

    definition)
      if [[ "$1" != "of" ]]; then
        echo "Usage: u7 sh definition of <word>"
        return 1
      fi
      curl -s "dict://dict.org/d:$2"
      ;;

    env)
      case "$1" in
        match)
          if [[ -z "$2" ]]; then
            echo "Usage: u7 sh env match <pattern>"
            return 1
          fi
          env | grep -i "$2"
          ;;
        "") env | sort ;;
        *) echo "Usage: u7 sh env [match <pattern>]" ;;
      esac
      ;;

    docker)
      case "$1" in
        containers|images|volumes|networks|all)
          if ! command -v docker &>/dev/null; then
            echo "Error: docker is not installed or not in PATH"
            return 1
          fi
          ;;
        "")
          echo "Usage: u7 sh docker <containers|images|volumes|networks|all>"
          return 0
          ;;
        *)
          echo "Usage: u7 sh docker <containers|images|volumes|networks|all>"
          return 1
          ;;
      esac
      case "$1" in
        containers) docker ps --format "table {{.ID}}\t{{.Image}}\t{{.Status}}\t{{.Names}}" ;;
        images) docker images --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}" ;;
        volumes) docker volume ls ;;
        networks) docker network ls ;;
        all)
          echo "=== Containers ==="
          docker ps --format "table {{.ID}}\t{{.Image}}\t{{.Status}}\t{{.Names}}"
          echo ""
          echo "=== Images ==="
          docker images --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}"
          echo ""
          echo "=== Volumes ==="
          docker volume ls
          echo ""
          echo "=== Networks ==="
          docker network ls
          ;;
      esac
      ;;

    http)
      local method="$1"
      local url="$2"
      local usage="Usage: u7 sh http <get|head|headers> <url>"
      if [[ -z "$method" || -z "$url" ]]; then
        echo "$usage"
        return 1
      fi
      case "$method" in
        get) curl -sL --max-time 30 -- "$url" ;;
        head|headers) curl -sIL --max-time 30 -- "$url" ;;
        *) echo "$usage" ; return 1 ;;
      esac
      ;;

    functions)
      declare -F | awk '{print $3}' | grep -v "^_"
      ;;

    --help|-h)
      cat << 'EOF'
u7 sh (show) - Observe/Search

Usage: u7 sh <entity> [arguments]

Entities:
  ip <external|internal|connected>
  csv <file> [limit N]
  json <file> [limit N]
  line <number> from <file>
  ssl of <domain>
  files match <pattern> [in <path>]
  files by <modified|size> [limit N]
  diff <file1> to <file2>
  cpu
  memory
  disk
  processes running [match <pattern>]
  processes by <cpu|memory> [limit N]
  port <number>
  usage <disk|directories> [path|depth]
  network
  git <authors|branches|tags|log [N]|status|diff|remotes>
  env [match <pattern>]
  http <get|head|headers> <url>
  docker <containers|images|volumes|networks|all>
  definition of <word>
  functions
EOF
      ;;

    *)
      echo "Unknown entity: $entity"
      echo "Run 'u7 sh --help' for usage"
      return 1
      ;;
  esac
}

_u7_make() {
  local entity="$1"
  shift

  case "$entity" in
    dir)
      _u7_exec mkdir -p "$1"
      ;;

    file)
      _u7_exec touch "$1"
      ;;

    password)
      if [[ "$1" == "length" ]]; then
        local length="${2:-16}"
      else
        local length="${1:-16}"
      fi
      LC_ALL=C tr -dc 'A-Za-z0-9!@#$%^&*' < /dev/urandom | head -c "$length"
      echo
      ;;

    user)
      if [[ -z "$1" ]]; then
        echo "Usage: u7 mk user <username>"
        return 1
      fi
      _u7_exec sudo useradd "$1"
      ;;

    copy)
      local src="$1"
      if [[ "$2" != "to" ]]; then
        echo "Usage: u7 mk copy <source> to <destination>"
        return 1
      fi
      local dst="$3"
      _u7_exec cp -r "$src" "$dst"
      ;;

    link)
      local src="$1"
      if [[ "$2" != "to" ]]; then
        echo "Usage: u7 mk link <source> to <destination>"
        return 1
      fi
      local dst="$3"
      _u7_exec ln -s "$src" "$dst"
      ;;

    archive)
      local output="$1"
      if [[ "$2" != "from" ]]; then
        echo "Usage: u7 mk archive <output> from <files...>"
        return 1
      fi
      shift 2
      local format="${output##*.}"
      case "$format" in
        gz)
          if [[ "$output" == *.tar.gz ]]; then
            _u7_exec tar -czvf "$output" "$@"
          else
            if [[ "$_U7_DRY_RUN" == "1" ]]; then
              echo "[dry-run] gzip -c $* > $output"
            else
              gzip -c "$@" > "$output"
            fi
          fi
          ;;
        bz2)
          if [[ "$output" == *.tar.bz2 ]]; then
            _u7_exec tar -cjvf "$output" "$@"
          else
            if [[ "$_U7_DRY_RUN" == "1" ]]; then
              echo "[dry-run] bzip2 -c $* > $output"
            else
              bzip2 -c "$@" > "$output"
            fi
          fi
          ;;
        xz)
          if [[ "$output" == *.tar.xz ]]; then
            _u7_exec tar -cJvf "$output" "$@"
          else
            if [[ "$_U7_DRY_RUN" == "1" ]]; then
              echo "[dry-run] xz -c $* > $output"
            else
              xz -c "$@" > "$output"
            fi
          fi
          ;;
        zip) _u7_exec zip -r "$output" "$@" ;;
        7z) _u7_exec 7z a "$output" "$@" ;;
        tar) _u7_exec tar -cvf "$output" "$@" ;;
        *) echo "Unsupported format: $format" ; return 1 ;;
      esac
      ;;

    clone)
      local repo="$1"
      if [[ -z "$repo" ]]; then
        echo "Usage: u7 mk clone <repo> [to <directory>]"
        return 1
      fi
      local dest=""
      if [[ "$2" == "to" && -n "$3" ]]; then
        dest="$3"
      fi
      if [[ -n "$dest" ]]; then
        _u7_exec git clone "$repo" "$dest"
      else
        _u7_exec git clone "$repo"
      fi
      ;;

    sequence)
      if [[ "$1" != "with" || "$2" != "prefix" ]]; then
        echo "Usage: u7 mk sequence with prefix <prefix> limit <N>"
        return 1
      fi
      local prefix="$3"
      if [[ "$4" != "limit" ]]; then
        echo "Usage: u7 mk sequence with prefix <prefix> limit <N>"
        return 1
      fi
      local count="$5"
      for i in $(seq 1 "$count"); do
        echo "${prefix}_${i}"
      done
      ;;

    --help|-h)
      cat << 'EOF'
u7 mk (make) - Create/Clone

Usage: u7 mk <entity> [arguments]

Entities:
  dir <path>                               Create directory at <path>
  file <path>                              Create empty file
  password length <N>                      Generate random password of length <N>
  user <username>                          Create system user
  copy <source> to <destination>           Copy file/directory
  link <source> to <destination>           Create symbolic link
  archive <output> from <files...>         Create archive from <files...> to <output>
  clone <repo> [to <directory>]            Git clone a repository
  sequence with prefix <prefix> limit <N>  Generate numbered sequence with prefix <prefix> and limit <N>
EOF
      ;;

    *)
      echo "Unknown entity: $entity"
      echo "Run 'u7 mk --help' for usage"
      return 1
      ;;
  esac
}

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

_u7_convert() {
  local entity="$1"
  shift

  case "$entity" in
    archive)
      local archive="$1"
      if [[ "$2" != "to" || "$3" != "files" ]]; then
        echo "Usage: u7 cv archive <archive> to files [yield <destination>]"
        return 1
      fi
      local dest="."
      if [[ "$4" == "yield" ]]; then
        dest="$5"
      fi

      if [[ ! -f "$archive" ]]; then
        echo "Archive not found: $archive"
        return 1
      fi

      local lowercase=$(echo "$archive" | tr '[:upper:]' '[:lower:]')

      # Helper function to get output filename for single-file archives
      _get_output_file() {
        local archive="$1"
        local dest="$2"
        if [[ -d "$dest" ]]; then
          # Dest is directory, derive filename from archive
          local basename=$(basename "$archive")
          # Remove compression extension
          echo "$dest/${basename%.*}"
        else
          # Dest is a file path
          echo "$dest"
        fi
      }

      case "$lowercase" in
        *.tar.xz|*.tar.gz|*.tar.bz2|*.tar|*.tgz|*.tbz|*.tbz2|*.txz|*.tb2)
          _u7_exec tar -xvf "$archive" -C "$dest" ;;
        *.bz|*.bz2)
          _u7_exec bzip2 -d -k "$archive" ;;
        *.gz)
          local outfile=$(_get_output_file "$archive" "$dest")
          if [[ "$_U7_DRY_RUN" == "1" ]]; then
            echo "[dry-run] gunzip -c $archive > $outfile"
          else
            gunzip -c "$archive" > "$outfile"
          fi
          ;;
        *.zip|*.jar)
          _u7_exec unzip "$archive" -d "$dest" ;;
        *.rar)
          _u7_exec unrar x "$archive" "$dest" ;;
        *.7z)
          _u7_exec 7z x "$archive" "-o$dest" ;;
        *.tar.lzma)
          _u7_exec tar -xf "$archive" -C "$dest" --lzma ;;
        *.xz)
          local outfile=$(_get_output_file "$archive" "$dest")
          if [[ "$_U7_DRY_RUN" == "1" ]]; then
            echo "[dry-run] unxz -c $archive > $outfile"
          else
            unxz -c "$archive" > "$outfile"
          fi
          ;;
        *.lzma)
          local outfile=$(_get_output_file "$archive" "$dest")
          if [[ "$_U7_DRY_RUN" == "1" ]]; then
            echo "[dry-run] unlzma -c $archive > $outfile"
          else
            unlzma -c "$archive" > "$outfile"
          fi
          ;;
        *.iso)
          _u7_exec sudo mount -o loop "$archive" "$dest" ;;
        *.img|*.dmg)
          _u7_exec hdiutil mount "$archive" -mountpoint "$dest" ;;
        *)
          echo "Unknown archive format: $archive"
          return 1
          ;;
      esac
      ;;

    files)
      # Collect files until we hit "to archive"
      local -a files=()
      while [[ $# -gt 0 && "$1" != "to" ]]; do
        files+=("$1")
        shift
      done
      if [[ "$1" != "to" || "$2" != "archive" ]]; then
        echo "Usage: u7 cv files <files...> to archive yield <output>"
        return 1
      fi
      shift 2
      if [[ "$1" != "yield" ]]; then
        echo "Usage: u7 cv files <files...> to archive yield <output>"
        return 1
      fi
      local output="$2"
      _u7_make archive "$output" from "${files[@]}"
      ;;

    image)
      local input="$1"
      if [[ "$2" != "to" ]]; then
        echo "Usage: u7 cv image <input> to <format> [yield <output>]"
        return 1
      fi
      local to_fmt="$3"
      local output="${input%.*}.$to_fmt"
      if [[ "$4" == "yield" ]]; then
        output="$5"
      fi

      case "$to_fmt" in
        webp)
          if ! _u7_require cwebp; then
            echo "Falling back to ImageMagick for WebP conversion"
            _u7_exec convert "$input" "$output"
          else
            _u7_exec cwebp -q 80 "$input" -o "$output"
          fi
          ;;
        *)
          _u7_exec convert "$input" "$output"
          ;;
      esac
      ;;

    video)
      local input="$1"
      if [[ "$2" != "to" ]]; then
        echo "Usage: u7 cv video <input> to <format> [yield <output>]"
        return 1
      fi
      local to_fmt="$3"
      local output="${input%.*}.$to_fmt"
      if [[ "$4" == "yield" ]]; then
          output="$5"
      fi

      case "$to_fmt" in
        gif)
          if ! _u7_require gifsicle; then
            echo "Falling back to ffmpeg-only conversion"
            _u7_exec ffmpeg -i "$input" "$output"
          else
            if [[ "$_U7_DRY_RUN" == "1" ]]; then
              echo "[dry-run] ffmpeg -i $input -pix_fmt rgb24 -r 10 -f gif - | gifsicle --optimize=3 --delay=5 > $output"
            else
              ffmpeg -i "$input" -pix_fmt rgb24 -r 10 -f gif - | gifsicle --optimize=3 --delay=5 > "$output"
            fi
          fi
          ;;
        *)
          _u7_exec ffmpeg -i "$input" "$output"
          ;;
      esac
      ;;

    json)
      local input="$1"
      if [[ "$2" != "to" ]]; then
        echo "Usage: u7 cv json <input> to yaml [yield <output>]"
        return 1
      fi
      local to_fmt="$3"
      local output="${input%.*}.$to_fmt"
      if [[ "$4" == "yield" ]]; then
        output="$5"
      fi

      case "$to_fmt" in
        yaml|yml)
          if [[ "$_U7_DRY_RUN" == "1" ]]; then
            echo "[dry-run] yq -P < $input > $output"
          else
            yq -P < "$input" > "$output"
          fi
          ;;
        *) echo "Unsupported conversion: json to $to_fmt" ; return 1 ;;
      esac
      ;;

    csv)
      local input="$1"
      if [[ "$2" != "to" ]]; then
        echo "Usage: u7 cv csv <input> to json [yield <output>]"
        return 1
      fi
      local to_fmt="$3"
      local output="${input%.*}.$to_fmt"
      if [[ "$4" == "yield" ]]; then
        if [[ -z "$5" ]]; then
          echo "Usage: u7 cv csv <input> to json [yield <output>]"
          return 1
        fi
        output="$5"
      fi

      if [[ ! -f "$input" ]]; then
        echo "File not found: $input"
        return 1
      fi

      case "$to_fmt" in
        json)
          _u7_require qsv || return 1
          if [[ "$_U7_DRY_RUN" == "1" ]]; then
            echo "[dry-run] qsv tojsonl $input > $output"
          else
            local tmpfile
            tmpfile=$(mktemp "${output}.XXXXXX") || { echo "Error: Failed to create temp file"; return 1; }
            qsv tojsonl "$input" > "$tmpfile" && mv "$tmpfile" "$output" || { rm -f "$tmpfile"; return 1; }
          fi
          ;;
        *) echo "Unsupported conversion: csv to $to_fmt" ; return 1 ;;
      esac
      ;;

    yaml)
      local input="$1"
      if [[ "$2" != "to" ]]; then
        echo "Usage: u7 cv yaml <input> to json [yield <output>]"
        return 1
      fi
      local to_fmt="$3"
      local output="${input%.*}.$to_fmt"
      if [[ "$4" == "yield" ]]; then
        if [[ -z "$5" ]]; then
          echo "Usage: u7 cv yaml <input> to json [yield <output>]"
          return 1
        fi
        output="$5"
      fi

      if [[ ! -f "$input" ]]; then
        echo "File not found: $input"
        return 1
      fi

      _u7_require yq || return 1

      case "$to_fmt" in
        json)
          if [[ "$_U7_DRY_RUN" == "1" ]]; then
            echo "[dry-run] yq -o=json < $input > $output"
          else
            local tmpfile
            tmpfile=$(mktemp "${output}.XXXXXX") || { echo "Error: Failed to create temp file"; return 1; }
            yq -o=json < "$input" > "$tmpfile" && mv "$tmpfile" "$output" || { rm -f "$tmpfile"; return 1; }
          fi
          ;;
        *) echo "Unsupported conversion: yaml to $to_fmt" ; return 1 ;;
      esac
      ;;

    case)
      if ! _u7_require rename "rename (perl-rename or prename)"; then
        echo "Hint: Install 'rename' package (perl-rename on Debian/Ubuntu, rename on others)"
        return 1
      fi
      if [[ "$1" == "upper" && "$2" == "to" && "$3" == "lower" ]]; then
        if [[ "$4" != "on" ]]; then
           echo "Usage: u7 cv case upper to lower on <files...>"
           return 1
        fi
        # Convert only basename to lowercase, preserve extension case
        _u7_exec rename 's/^(.*)(\.\w+)$/lc($1) . $2/e' "${@:5}"
      elif [[ "$1" == "lower" && "$2" == "to" && "$3" == "upper" ]]; then
        if [[ "$4" != "on" ]]; then
           echo "Usage: u7 cv case lower to upper on <files...>"
           return 1
        fi
        # Convert only basename to uppercase, preserve extension case
        _u7_exec rename 's/^(.*)(\.\w+)$/uc($1) . $2/e' "${@:5}"
      else
        echo "Usage: u7 cv case <upper|lower> to <lower|upper> on <files...>"
      fi
      ;;

    spaces)
      if ! _u7_require rename "rename (perl-rename or prename)"; then
        echo "Hint: Install 'rename' package (perl-rename on Debian/Ubuntu, rename on others)"
        return 1
      fi
      if [[ "$1" == "to" && "$2" == "underscores" ]]; then
        if [[ "$3" != "on" ]]; then
           echo "Usage: u7 cv spaces to underscores on <file>"
           return 1
        fi
        if [[ -n "$4" ]]; then
          _u7_exec rename 'y/ /_/' "$4"
        else
          _u7_exec rename 'y/ /_/' -- *
        fi
      else
        echo "Usage: u7 cv spaces to underscores on <file>"
      fi
      ;;

    --help|-h)
      cat << 'EOF'
u7 cv (convert) - Transform/Extract

Usage: u7 cv <entity> <input> to <format> [yield <output>]

Entities:
  archive <archive> to files [yield <dest>]  Extract archive
  files <files...> to archive yield <output>   Create archive
  image <input> to <format> [yield <output>]   Convert image (png/jpg/webp/gif/etc)
  video <input> to <format> [yield <output>]   Convert video
  json <input> to yaml [yield <output>]  Convert JSON to YAML
  csv <input> to json [yield <output>]   Convert CSV to JSON
  yaml <input> to json [yield <output>]  Convert YAML to JSON
  case upper to lower on <files...>      Rename to lowercase
  case lower to upper on <files...>      Rename to uppercase
  spaces to underscores on <file>        Replace spaces in filenames
EOF
      ;;

    *)
      echo "Unknown entity: $entity"
      echo "Run 'u7 cv --help' for usage"
      return 1
      ;;
  esac
}

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

    --help|-h)
      cat << 'EOF'
u7 rn (run) - Execute/Control

Usage: u7 rn <entity> [arguments]

Entities:
  job <cmd> in <time>                    Schedule command (5s, 10m, 1h)
  script <path>                          Execute shell script
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

_u7_complete_entities() {
  local verb="$1" cur="$2"
  case "$verb" in
    show|sh)
      COMPREPLY=($(compgen -W "ip csv json line ssl files diff cpu memory disk processes port usage network git env definition functions --help" -- "$cur"))
      ;;
    make|mk)
      COMPREPLY=($(compgen -W "dir file password user copy link archive sequence --help" -- "$cur"))
      ;;
    drop|dr)
      COMPREPLY=($(compgen -W "file dir dirs files line lines column duplicates process user --help" -- "$cur"))
      ;;
    convert|cv)
      COMPREPLY=($(compgen -W "archive files image video json csv case spaces --help" -- "$cur"))
      ;;
    move|mv)
      COMPREPLY=($(compgen -W "file sync --help" -- "$cur"))
      ;;
    set|st)
      COMPREPLY=($(compgen -W "text slashes tabs perms owner --help" -- "$cur"))
      ;;
    run|rn)
      COMPREPLY=($(compgen -W "job script check terminal --help" -- "$cur"))
      ;;
  esac
}

_u7_complete_args() {
  local verb="$1" entity="$2" cur="$3"
  case "$verb" in
    show|sh)
      case "$entity" in
        ip) COMPREPLY=($(compgen -W "external internal connected" -- "$cur")) ;;
        processes) COMPREPLY=($(compgen -W "running by" -- "$cur")) ;;
        files) COMPREPLY=($(compgen -W "match by" -- "$cur")) ;;
        usage) COMPREPLY=($(compgen -W "disk directories" -- "$cur")) ;;
        git) COMPREPLY=($(compgen -W "authors branches tags log status diff remotes" -- "$cur")) ;;
        env) COMPREPLY=($(compgen -W "match" -- "$cur")) ;;
        *) _filedir ;;
      esac
      ;;
    make|mk)
      case "$entity" in
        copy|link) _filedir ;;
      esac
      ;;
    drop|dr)
      case "$entity" in
        dirs) COMPREPLY=($(compgen -W "if" -- "$cur")) ;;
        files) COMPREPLY=($(compgen -W "but" -- "$cur")) ;;
        lines) COMPREPLY=($(compgen -W "if" -- "$cur")) ;;
        *) _filedir ;;
      esac
      ;;
    convert|cv)
      case "$entity" in
        archive|files) COMPREPLY=($(compgen -W "to" -- "$cur")) ;;
        png|jpg|jpeg|gif) COMPREPLY=($(compgen -W "to" -- "$cur")) ;;
        case) COMPREPLY=($(compgen -W "upper lower" -- "$cur")) ;;
        spaces) COMPREPLY=($(compgen -W "to" -- "$cur")) ;;
        *) _filedir ;;
      esac
      ;;
    set|st)
      case "$entity" in
        slashes) COMPREPLY=($(compgen -W "back forward" -- "$cur")) ;;
        tabs) COMPREPLY=($(compgen -W "to" -- "$cur")) ;;
        perms|owner) COMPREPLY=($(compgen -W "to" -- "$cur")) ;;
        *) _filedir ;;
      esac
      ;;
    run|rn)
      case "$entity" in
        check) COMPREPLY=($(compgen -W "syntax" -- "$cur")) ; _filedir ;;
        script) _filedir ;;
      esac
      ;;
  esac
}

_u7_completions() {
  local cur prev words cword
  _init_completion 2>/dev/null || {
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"
    words=("${COMP_WORDS[@]}")
    cword=$COMP_CWORD
  }

  local verbs="show sh make mk drop dr convert cv move mv set st run rn --help"
  local opts="-n --dry-run"

  # Adjust for dry-run flag
  local verb_idx=1
  if [[ "${words[1]}" == "-n" || "${words[1]}" == "--dry-run" ]]; then
    verb_idx=2
  fi
  local entity_idx=$((verb_idx + 1))

  # Completing verb position
  if [[ "$cword" -le "$verb_idx" ]]; then
    if [[ "$cword" -eq 1 ]]; then
      COMPREPLY=($(compgen -W "$verbs $opts" -- "$cur"))
    else
      COMPREPLY=($(compgen -W "$verbs" -- "$cur"))
    fi
    return
  fi

  # Completing entity position
  if [[ "$cword" -eq "$entity_idx" ]]; then
    _u7_complete_entities "${words[$verb_idx]}" "$cur"
    return
  fi

  # Completing arguments
  _u7_complete_args "${words[$verb_idx]}" "${words[$entity_idx]}" "$cur"
}

if [[ $- == *i* ]]; then
  complete -F _u7_completions u7
fi
