# dev — developer fuzzy-cd and toolbox
# Source this in ~/.zshrc:  source ~/work/settings/dev.zsh

dev() {
  local cmd="${1:-}"

  case "$cmd" in
    cd)
      _dev_cd "${2:-}"
      ;;
    ""|--help|-h)
      echo "dev — developer tools"
      echo ""
      echo "  dev cd <query>    Fuzzy-jump to a work directory"
      echo ""
      echo "  Set DEV_WORK_DIR to change the search root (default: ~/work)"
      ;;
    *)
      echo "dev: unknown command '$cmd'" >&2
      echo "Run 'dev --help' for usage" >&2
      return 1
      ;;
  esac
}

_dev_cd() {
  local query="$1"
  local search_root="${DEV_WORK_DIR:-$HOME/work}"

  if [[ -z "$query" ]]; then
    builtin cd "$search_root"
    return
  fi

  # Collect top-level project directories only (depth 1 under work root)
  local -a candidates
  while IFS= read -r line; do
    candidates+=("$line")
  done < <(find "$search_root" -maxdepth 1 -mindepth 1 -type d \
             -not -name '.*' \
             2>/dev/null \
             | sort)

  if (( ${#candidates[@]} == 0 )); then
    echo "dev: no directories found in $search_root" >&2
    return 1
  fi

  # Score each candidate against the query
  local ql="${query:l}"   # lowercase query
  local -a matches scores

  for dir in "${candidates[@]}"; do
    local base="${dir##*/}"
    local bl="${base:l}"
    local score=0

    if [[ "$bl" == "$ql" ]]; then
      score=1000                          # exact basename match
    elif [[ "$bl" == ${ql}* ]]; then
      score=500                           # prefix match
    elif [[ "$bl" == *${ql}* ]]; then
      score=200                           # substring match
    else
      # Subsequence match: all query chars appear in order
      local qi=0
      local q_len=${#ql}
      for (( i=1; i<=${#bl}; i++ )); do
        [[ "${bl[$i]}" == "${ql[$((qi+1))]}" ]] && (( qi++ ))
        (( qi >= q_len )) && break
      done
      if (( qi >= q_len )); then
        score=$(( 50 - ${#bl} ))          # shorter = better
        (( score < 1 )) && score=1
      fi
    fi

    if (( score > 0 )); then
      matches+=("$dir")
      scores+=("$score")
    fi
  done

  if (( ${#matches[@]} == 0 )); then
    echo "dev: no match found for '$query'" >&2
    return 1
  fi

  # Sort matches by score descending (insertion sort — list is small)
  local n=${#matches[@]}
  for (( i=2; i<=n; i++ )); do
    local key_dir="${matches[$i]}"
    local key_score="${scores[$i]}"
    local j=$(( i - 1 ))
    while (( j >= 1 && scores[j] < key_score )); do
      matches[$(( j+1 ))]="${matches[$j]}"
      scores[$(( j+1 ))]="${scores[$j]}"
      (( j-- ))
    done
    matches[$(( j+1 ))]="$key_dir"
    scores[$(( j+1 ))]="$key_score"
  done

  local target

  if (( ${#matches[@]} == 1 )); then
    target="${matches[1]}"
  else
    # Multiple matches — show a picker
    echo "dev: multiple matches for '$query':"
    for (( i=1; i<=${#matches[@]}; i++ )); do
      printf "  %2d) %s\n" "$i" "${matches[$i]}"
    done
    printf "Pick [1]: "
    local choice
    read -r choice </dev/tty
    choice="${choice:-1}"
    if ! [[ "$choice" =~ ^[0-9]+$ ]] || (( choice < 1 || choice > ${#matches[@]} )); then
      echo "dev: invalid choice" >&2
      return 1
    fi
    target="${matches[$choice]}"
  fi

  echo "  $target"
  builtin cd "$target"
}
