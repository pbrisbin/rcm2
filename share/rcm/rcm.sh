# RCM library script
#
# Portability notes:
#
# * The local keyword is OK.
#
# * We can use ${var%.*} style splitting. TODO: replace some
#   sed/dirname/basename uses for performance.
#
# * Assigning $@ doesn't work consistently. For now, all array-like
#   options are treated as space-separated strings which means the
#   elements cannot contain spaces either.
#
# source: http://apenwarr.ca/log/?m=201102#28.
#
###
_cp()    { echo "cp $*"; }    # TODO
_ln()    { echo "ln $*"; }    # TODO
_mkdir() { echo "mkdir $*"; } # TODO

# Print $* on STDERR if verbosity is high enough.
debug() {
  [ "$verbosity" -ge 2 ] || return

  printf "debug [%s]: %s\n" "$PWD" "$*" |\
    sed "s|$HOME|~|g" >&2;
}

# Return true if string $1 is present in the space-separated "array" $2.
in_array() {
  local needle="$1" haystack="$2"

  printf " $haystack " | grep -Fq " $needle "
}

# Return true if the current source and base filename $1 match pattern
# $2 where pattern is "(<source-glob>:)<filename-glob>"
matches_pattern() {
  local file="$1" pattern="$2"
  local directory_part file_pattern

  if printf "$pattern" | grep -Fq ':'; then
    directory_part="$(printf "$pattern" | sed 's|:.*$||')"
    file_pattern="$(printf "$pattern" | sed 's|^.*:||')"
  else
    directory_part='*'
    file_pattern="$2"
  fi

  case "$(basename "$dotfiles")" in
    $directory_part)
      case "$file" in
        $file_pattern) return 0 ;;
      esac
      ;;
  esac

  return 1
}

# Return true if base filename $1 matches any current exclusion
# patterns.
is_excluded() {
  local file="$1" pattern

  for pattern in $exclusion_patterns; do
    if matches_pattern "$file" "$pattern"; then
      debug "$file matches exclusion pattern $pattern"
      return 0
    fi
  done

  return 1
}

# Return true if base filename $1 matches any current inclusion
# patterns.
is_included() {
  local file="$1" pattern

  for pattern in $inclusion_patterns; do
    if matches_pattern "$file" "$pattern"; then
      debug "$file matches inclusion pattern $pattern"
      return 0
    fi
  done

  return 1
}

# Return true if the base filename $1 and $2 have the same contents.
same_file() {
  diff -q -s "$PWD/$1" "$2" > /dev/null
}

# Return true if base filename $1 should be skipped. This may be because
# it doesn't exist, is a meta directory, or should be excluded based on
# the known excludes list or (ex|in)clusion pattern checks.
skip() {
  local file="$1"

  if [ ! -e "$file" ]; then
    debug "skipping $file (non-existent)"
    return 0
  fi

  case "$file" in
    hooks|host-*|tag-*)
      debug "skipping $file (meta file)"
      return 0
      ;;
  esac

  if in_array "$file" "$excludes"; then
    debug "skipping $file (excludes)"
    return 0
  fi

  if is_excluded "$file" && ! is_included "$file"; then
    debug "skipping $file (exclusion pattern)"
    return 0
  fi

  return 1
}

# Print the installation location for base filename $1.
destination() {
  local dotfile="$PWD/$1"

  printf "$dotfile" | sed "
    s%$dotfiles/\?%%;
    s%\(host\|tag\)-[^/]*/%%;
    s%^%$HOME/.%;
  "
}

# Print 'X' or '@' if base filename $1 should be installed as a copy or
# symlink respectively.
sigil() {
  local file="$1"

  if [ "$copy_all" -eq 1 ]; then
    printf 'X'
  else
    if in_array "$file" "$copy_always"; then
      printf 'X'
    else
      printf '@'
    fi
  fi
}

# Installs $1 into $2.
install_dotfile() {
  local dotfile="$1" destination="$2"

  debug "installing $dotfile as $destination"

  [ -d "$directory" ] || _mkdir -p "$directory"

  case "$(sigil "$dotfile")" in
    '@') _ln -s "$dotfile" "$destination" ;;
    'X') _cp "$dotfile" "$destination" ;;
  esac
}

# Recursively enter directory $1 and call process_dotfile with each
# relative filename within. Note that process_dotfile is not currently
# defined and calls should do so before using this function. Also note
# that it will be run in a subshell, changes to variables will not
# persist and calls to exit will not terminate the script.
dotfiles() {
  local directory="$1" file

  debug "processing $directory"

  (
    cd "$directory"

    for file in ${files:-*}; do
      skip "$file" && continue

      if [ -d "$file" ]; then
        dotfiles "$file"
      else
        process_dotfile "$file"
      fi
    done

    cd - >/dev/null
  )
}

# For each source, call dotfiles on it, then any host-specific sub
# folder, then any tag-specific sub folders. TODO: run hooks.
process_dotfiles() {
  local hostname="${HOST:-$(hostname)}"
  local dotfile host_dotfile tag_dotfile

  for dotfiles in $dotfiles_dirs; do
    debug "for source $dotfiles"

    [ ! -d "$dotfiles" ] && continue

    dotfiles "$dotfiles"

    if [ "$include_host" -eq 1 ]; then
      host_dotfiles="$dotfiles/host-$hostname"

      if [ -d "$host_dotfiles" ]; then
        debug "for host $hostname"
        dotfiles "$host_dotfiles"
      fi
    fi

    for tag in $tags; do
      tag_dotfiles="$dotfiles/tag-$tag"

      if [ -d "$tag_dotfiles" ]; then
        debug "for tag $tag"
        dotfiles "$tag_dotfiles"
      fi
    done
  done
}

parse_options() {
  local opt file

  while getopts Cd:t:I:x:qvFfikK opt; do
    case "$opt" in
      C) copy_all=1 ;;
      d) dotfiles_dirs="$dotfiles_dirs $OPTARG" ;;
      t) tags="$tags $OPTARG" ;;
      I) inclusion_patterns="$inclusion_patterns $OPTARG" ;;
      x) exclusion_patterns="$exclusion_patterns $OPTARG" ;;
      q) verbosity=0 ;;
      v) verbosity=$(($verbosity+1)) ;;
      F) show_flags=1 ;;
      f) force=1 ;;
      i) prompt=1 ;;
      k) hooks=1 ;;
      K) hooks=0 ;;
    esac
  done
  shift $(($OPTIND-1))

  files="$*"

  debug "--- settings ---"
  debug "copy_all: $copy_all"
  debug "copy_always: $copy_always"
  debug "dotfiles_dirs: $dotfiles_dirs"
  debug "excludes: $excludes"
  debug "exclusion_patterns: $exclusion_patterns"
  debug "force: $force"
  debug "hooks: $hooks"
  debug "include_host: $include_host"
  debug "inclusion_patterns: $inclusion_patterns"
  debug "prompt: $prompt"
  debug "show_flags: $show_flags"
  debug "tags: $tags"
  debug "verbosity: $verbosity"
  debug "files: $files"
  debug "---"
}

copy_all=0
copy_always=''
dotfiles_dirs="$HOME/.dotfiles"
excludes=''
exclusion_patterns=''
files=''
force=0
hooks=1
include_host=1
inclusion_patterns=''
prompt=1
show_flags=0
tags=''
verbosity=1
