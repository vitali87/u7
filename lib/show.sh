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
      jq "if type == \"array\" then .[:$limit] else . end" "$file"
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
