_u7_archive_output_file() {
  local archive="$1"
  local dest="$2"
  if [[ -d "$dest" ]]; then
    local basename
    basename=$(basename "$archive")
    echo "$dest/${basename%.*}"
  else
    echo "$dest"
  fi
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

      local lowercase
      lowercase=$(echo "$archive" | tr '[:upper:]' '[:lower:]')

      case "$lowercase" in
        *.tar.xz|*.tar.gz|*.tar.bz2|*.tar|*.tgz|*.tbz|*.tbz2|*.txz|*.tb2)
          _u7_exec tar -xvf "$archive" -C "$dest" ;;
        *.bz|*.bz2)
          _u7_exec bzip2 -d -k "$archive" ;;
        *.gz)
          local outfile
          outfile=$(_u7_archive_output_file "$archive" "$dest")
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
          local outfile
          outfile=$(_u7_archive_output_file "$archive" "$dest")
          if [[ "$_U7_DRY_RUN" == "1" ]]; then
            echo "[dry-run] unxz -c $archive > $outfile"
          else
            unxz -c "$archive" > "$outfile"
          fi
          ;;
        *.lzma)
          local outfile
          outfile=$(_u7_archive_output_file "$archive" "$dest")
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
            echo "[dry-run] yq -P < \"$input\" > \"$output\""
          else
            yq -P < "$input" > "$output"
          fi
          ;;
        *) echo "Unsupported conversion: json to $to_fmt" ; return 1 ;;
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

      # Requires yq-go (Mike Farah's yq), provided by Nix
      _u7_require yq || return 1

      case "$to_fmt" in
        json)
          if [[ "$_U7_DRY_RUN" == "1" ]]; then
            echo "[dry-run] yq -o=json < \"$input\" > \"$output\""
          else
            local tmpfile
            tmpfile=$(mktemp "${output}.XXXXXX") || { echo "Error: Failed to create temp file"; return 1; }
            yq -o=json < "$input" > "$tmpfile" && mv "$tmpfile" "$output" || { rm -f "$tmpfile"; return 1; }
          fi
          ;;
        *) echo "Unsupported conversion: yaml to $to_fmt" ; return 1 ;;
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
  yaml <input> to json [yield <output>]  Convert YAML to JSON
  csv <input> to json [yield <output>]   Convert CSV to JSON
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
