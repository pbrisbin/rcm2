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
. "$RCM_LIB/compat.sh"

fs() {
  local cmd="$1"; shift

  [ "$verbosity" -ge 1 ] && printf "%s %s\n" "$cmd" "$*"

  "$cmd" "$@"
}

_cp()    { fs 'cp'    "$@"; }
_ln()    { fs 'ln'    "$@"; }
_mkdir() { fs 'mkdir' "$@"; }
_mv()    { fs 'mv'    "$@"; }
_rm()    { fs 'rm'    "$@"; }

# Print $* on STDERR if verbosity is high enough.
debug() {
  if [ "$verbosity" -ge 2 ]; then
    printf "debug [%s]: %s\n" "$PWD" "$*" | sed "s|$HOME|~|g" >&2;
  fi
}

# Print usage for subcommand $1 with option string $2.
generic_usage() {
  local subcommand="$(basename "$0")"
  local flags="${1:-[-FVqvh]}"
  local options="${2:-[-I EXCL_PAT] [-x EXCL_PAT] [-t TAG] [-d DOT_DIR]}"

  printf "Usage: %s %s %s\n" "$subcommand" "$flags" "$options"
  printf "see %s(1) and rcm(5) for more details\n" "$subcommand"
}

# Print version for subcommand $1.
generic_version() {
  local subcommand="$(basename "$0")"

  printf "%s (rcm) %s\n" "$subcommand" "$version"
  printf "Copyright ...\n"
  printf "License BSD: BSD 3-clause license\n\n"
  printf "Written by...\n"
}

# Return true if string $1 is present in the space-separated "array" $2.
in_array() { printf " $2 " | grep -Fq " $1 "; }

# Return true if the current source and base filename $1 match pattern
# $2 where pattern is "(<source-glob>:)<filename-glob>"
matches_pattern() {
  local file="$1" pattern="$2"
  local source_glob filename_glob

  if printf "$pattern" | grep -Fq ':'; then
    source_glob="$(printf "$pattern" | sed 's|:.*$||')"
    filename_glob="$(printf "$pattern" | sed 's|^.*:||')"
  else
    source_glob='*'
    filename_glob="$2"
  fi

  case "$(basename "$dotfiles")" in
    $source_glob)
      case "$file" in
        $filename_glob) return 0 ;;
      esac
      ;;
  esac

  return 1
}

# Returns true if matches_pattern returns true for the given file and
# any of the given patterns.
matches_patterns() {
  local file="$1" patterns="$2"

  for pattern in $patterns; do
    if matches_pattern "$file" "$pattern"; then
      debug "$file matches pattern $pattern"
      return 0
    fi
  done

  return 1
}

is_excluded() { matches_patterns "$1" "$exclusion_patterns"; }
is_included() { matches_patterns "$1" "$inclusion_patterns"; }

# Return true if the base filename $1 and $2 have the same contents.
same_file() { diff -q -s "$PWD/$1" "$2" >/dev/null; }

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

# Print the path to base filename $1 relative to the current dotfiles
# source.
dotfile_path() {
  local dotfile="$PWD/$1"

  printf "$dotfile" | sed "
    s%$dotfiles/\?%%;
    s%\(host\|tag\)-[^/]*/%%;
  "
}

# Print the installation location for base filename $1.
destination() { printf "%s/.%s" "$HOME" "$(dotfile_path "$1")"; }

# Return true if base filename $1 should be installed as a copy rather
# than symlink.
copy() {
  local path="$(dotfile_path "$1")"

  [ "$copy_all" -eq 1 ] || in_array "$path" "$copy_always"
}

# Prompts user to remove existing file $1
removable() {
  local destination="$1" overwrite

  [ "$force" -eq 1  ] && return 0
  [ "$prompt" -ne 1 ] && return 1

  printf "overwrite %s? [ynaq] " "$destination"
  read overwrite

  case "$overwrite" in
    y) return 0 ;;
    a) force=1; return 0 ;;
    q) exit 1 ;;
  esac

  return 1
}

# Removes destination $2 for dotfile $1 if possible. Returns false
# otherwise.
remove_dotfile() {
  local dotfile="$1" destination="$2"

  if same_file "$dotfile" "$destination"; then
    debug "skipping $dotfile (exists and contents match)"
    return 1
  fi

  if ! removable "$destination"; then
    debug "skipping $dotfile (prompt setting)"
    return 1
  fi

  _rm "$destination"
}

# Installs $1 into $2.
install_dotfile() {
  local dotfile="$1" destination="$2"
  local directory="$(dirname "$destination")"

  debug "installing $dotfile as $destination"

  [ -d "$directory" ] || _mkdir -p "$directory"

  if copy "$dotfile"; then
    _cp "$dotfile" "$destination"
  else
    _ln -s "$dotfile" "$destination"
  fi
}

# Runs hooks/$1 if applicable
run_hook() {
  local hook="hooks/$1"

  if [ "$hooks" -eq 1 -a -x "$hook" ]; then
    debug "running hook $hook"
    "$hook"
  fi
}

# Recursively enter directory $1 and call process_dotfile with each
# relative filename within. Note that process_dotfile is not currently
# defined and callers should do so before using this function.
dotfiles() {
  local directory="$1" direction="${2:-up}" file

  debug "processing $directory"

  pushd "$directory"

  run_hook "pre-$direction"

  for file in ${files:-*}; do
    skip "$file" && continue

    if [ -d "$file" ]; then
      dotfiles "$file" "$direction"
    else
      process_dotfile "$file"
    fi
  done

  run_hook "post-$direction"

  popd
}

# For each source, call dotfiles on it, then any host-specific sub
# folder, then any tag-specific sub folders.
process_dotfiles() {
  local direction="${1:-up}" hostname="${HOST:-$(hostname)}"
  local dotfile host_dotfile tag_dotfile

  for dotfiles in $dotfiles_dirs; do
    debug "for source $dotfiles"

    [ ! -d "$dotfiles" ] && continue

    dotfiles "$dotfiles" "$direction"

    host_dotfiles="$dotfiles/host-$hostname"

    if [ -d "$host_dotfiles" ]; then
      debug "for host $hostname"
      dotfiles "$host_dotfiles" "$direction"
    fi

    for tag in $tags; do
      tag_dotfiles="$dotfiles/tag-$tag"

      if [ -d "$tag_dotfiles" ]; then
        debug "for tag $tag"
        dotfiles "$tag_dotfiles" "$direction"
      fi
    done
  done
}

parse_options() {
  local opt file

  debug "options: $*"

  while getopts Cd:t:I:x:qvFfikKohV opt; do
    debug "option: $opt"

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
      o) host_specific=1 ;;
      h) usage; return 1 ;;
      V) version; return 1 ;;
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
  debug "host_specific: $host_specific"
  debug "inclusion_patterns: $inclusion_patterns"
  debug "prompt: $prompt"
  debug "show_flags: $show_flags"
  debug "tags: $tags"
  debug "verbosity: $verbosity"
  debug "version: $version"
  debug "files: $files"
  debug "---"

  return 0
}

copy_all=0
copy_always=''
dotfiles_dirs="$HOME/.dotfiles"
excludes=''
exclusion_patterns=''
files=''
force=0
hooks=1
host_specific=0
inclusion_patterns=''
prompt=1
show_flags=0
tags=''
verbosity=1
version="0.0.1"

. "${RCRC:-$HOME/.rcrc}"
