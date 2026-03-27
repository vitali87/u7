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
      local length
      if [[ "$1" == "length" ]]; then
        length="${2:-16}"
      else
        length="${1:-16}"
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
