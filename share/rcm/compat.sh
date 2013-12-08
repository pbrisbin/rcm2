_dirstack="$HOME"

pushd() {
  cd "$1" || return $?

  _dirstack="$OLDPWD:$_dirstack"
}

popd() {
  local dir="${_dirstack%%:*}"

  if [ -n "$dir" ]; then
    cd "$dir" || return $?

    _dirstack="${_dirstack#*:}"
  fi
}
