# RCM library script
#
# Note: POSIX has no local keyword so all functions should declare via
# comment what variable names they access to prevent collisions. Yay
# global state.
#
###

# variables: (r/w) needle, haystack
in_array() {
  needle="$1" haystack="$2"

  echo " $haystack " | grep -Fq " $needle "
}

# variables: (r) dotfiles
# variables: (r/w) directory_part, file_pattern
matches_pattern() {
  if echo "$2" | grep -Fq ':'; then
    directory_part="$(echo "$2" | sed 's|:.*$||')"
    file_pattern="$(echo "$2" | sed 's|^.*:||')"
  else
    directory_part='*'
    file_pattern="$2"
  fi

  case "$(basename "$dotfiles")" in
    $directory_part)
      case "$1" in
        $file_pattern) return 0 ;;
      esac
      ;;
  esac

  return 1
}

# variables: (r) exclusion_patterns
# variables: (r/w) pattern
is_excluded() {
  for pattern in "$exclusion_patterns"; do
    if matches_pattern "$1" "$pattern"; then
      return 0
    fi
  done

  return 1
}

# variables: (r) inclusion_patterns
# variables: (r/w) pattern
is_included() {
  for pattern in "$inclusion_patterns"; do
    if matches_pattern "$1" "$pattern"; then
      return 0
    fi
  done

  return 1
}

# variables: (r) excludes
# variables: (r/w) basename
skip() {
  basename="$(basename "$1")"

  case "$basename" in
    hooks|host-*|tag-*) return 0 ;;
  esac

  in_array "$basename" "$excludes" || {
    is_excluded "$basename" && ! is_included "$basename"
  }
}

# variables: (r) dotfiles
# variables: (r/w) dotfile
destination() {
  dotfile="$1"

  echo "$dotfile" | sed "
    s%$dotfiles/\?%%;
    s%\(host\|tag\)-[^/]*/%%;
    s%^%$HOME/.%;
  "
}

# variables: (r) copy_always
# variables: (r/w) basename
sigil() {
  basename="$(basename "$1")"

  if [ "$copy_all" -eq 1 ]; then
    echo 'X'
  else
    if in_array "$basename" "$copy_always"; then
      echo 'X'
    else
      echo '@'
    fi
  fi
}

# variables: (r) show_flags
# variables: (r/w) directory, file
dotfiles() {
  directory="$1"

  for file in "$directory"/*; do
    skip "$file" && continue

    if [ -d "$file" ]; then
      dotfiles "$file"
    else
      if [ "$show_flags" -eq 1 ]; then
        echo "$(destination "$file"):$file:$(sigil "$file")"
      else
        echo "$(destination "$file"):$file"
      fi
    fi
  done
}

# variables: (r) include_host, tags
# variables: (r/w) dotfiles, host_, tag_
process() {
  dotfiles="$1"

  dotfiles "$dotfiles"

  if [ "$include_host" -eq 1 ]; then
    host_dotfiles="$dotfiles/host-$(hostname)"

    if [ -d "$host_dotfiles" ]; then
      dotfiles "$host_dotfiles"
    fi
  fi

  if [ -n "$tags" ]; then
    for tag in "$tags"; do
      tag_dotfiles="$dotfiles/tag-$tag"

      if [ -d "$tag_dotfiles" ]; then
        dotfiles "$tag_dotfiles"
      fi
    done
  fi
}

set_defaults() {
  copy_all=0
  copy_always='msmtprc'
  dotfiles_dirs="$HOME/.dotfiles"
  excludes='README.md'
  exclusion_patterns='.dotfiles:*mail*'
  force=0
  hooks=1
  include_host=1
  inclusion_patterns='sys-email'
  prompt=1
  show_flags=1
  tags=''
}
