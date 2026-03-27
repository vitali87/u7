_u7_complete_entities() {
  local verb="$1" cur="$2"
  case "$verb" in
    show|sh)
      COMPREPLY=($(compgen -W "ip csv json line ssl files diff cpu memory disk processes ports port usage network git env http docker system definition functions --help" -- "$cur"))
      ;;
    make|mk)
      COMPREPLY=($(compgen -W "dir file password user copy link archive clone template sequence env --help" -- "$cur"))
      ;;
    drop|dr)
      COMPREPLY=($(compgen -W "file dir dirs files line lines column duplicates process user docker --help" -- "$cur"))
      ;;
    convert|cv)
      COMPREPLY=($(compgen -W "archive files image video json yaml csv case spaces --help" -- "$cur"))
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
        http) COMPREPLY=($(compgen -W "get head headers" -- "$cur")) ;;
        docker) COMPREPLY=($(compgen -W "containers images volumes networks all" -- "$cur")) ;;
        ports) COMPREPLY=($(compgen -W "match" -- "$cur")) ;;
        *) _filedir ;;
      esac
      ;;
    make|mk)
      case "$entity" in
        copy|link) _filedir ;;
        env) COMPREPLY=($(compgen -W "from" -- "$cur")) ;;
        template) COMPREPLY=($(compgen -W "python node bash web" -- "$cur")) ;;
      esac
      ;;
    drop|dr)
      case "$entity" in
        dirs) COMPREPLY=($(compgen -W "if" -- "$cur")) ;;
        files) COMPREPLY=($(compgen -W "but" -- "$cur")) ;;
        lines) COMPREPLY=($(compgen -W "if" -- "$cur")) ;;
        docker) COMPREPLY=($(compgen -W "container image volume prune" -- "$cur")) ;;
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
