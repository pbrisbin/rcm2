# RCM library script
#
# Portability notes, based on http://apenwarr.ca/log/?m=201102#28.
#
# * local is OK, thank god
# * we can use ${var%.*} style splitting, should replace some
#   sed/dirname/basename uses for performance.
# * Assigning $@ doesn't work consistently, which means handling file
#   arguments is difficult. For now, all array-like options are stored
#   as space-separated strings which means the elements cannot contain
#   spaces either.
#
###
debug() {
  [ "$verbosity" -ge 2 ] || return

  printf "debug [%s]: %s\n" "$PWD" "$*" |\
    sed "s|$HOME|~|g" >&2;
}

# TODO: call programs. add -v if verbosity -ge 1
_mkdir() { echo "mkdir $*"; }
_ln()    { echo "ln $*"; }
_cp()    { echo "cp $*"; }

in_array() {
  local needle="$1" haystack="$2"

  printf " $haystack " | grep -Fq " $needle "
}

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

destination() {
  local dotfile="$PWD/$1"

  printf "$dotfile" | sed "
    s%$dotfiles/\?%%;
    s%\(host\|tag\)-[^/]*/%%;
    s%^%$HOME/.%;
  "
}

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

  dump_settings
}

process() {
  local hostname="${HOSTNAME:-$(hostname)}"
  local dotfile host_dotfile tag_dotfile

  for dotfiles in $dotfiles_dirs; do
    debug "for source $dotfiles"

    if [ ! -d "$dotfiles" ]; then
      debug "not found"
      continue
    fi

    dotfiles "$dotfiles"

    if [ "$include_host" -eq 1 ]; then
      debug "for host $hostname"

      host_dotfiles="$dotfiles/host-$hostname"

      if [ -d "$host_dotfiles" ]; then
        dotfiles "$host_dotfiles"
      else
        debug "not found"
      fi
    fi

    if [ -n "$tags" ]; then
      for tag in $tags; do
        debug "for tag $tag"

        tag_dotfiles="$dotfiles/tag-$tag"

        if [ -d "$tag_dotfiles" ]; then
          dotfiles "$tag_dotfiles"
        else
          debug "not found"
        fi
      done
    fi
  done
}

dump_settings() {
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
