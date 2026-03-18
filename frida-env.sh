# =============================================================================
# frida-env.sh  -  Frida version manager  (bash + zsh / macOS + Linux)
#
# Source from your shell config:
#   export FRIDA_HOME="$HOME/.frida-envs"   # optional, this is the default
#   source "/path/to/frida-env.sh"
#
# Commands:
#   frida-16.6.3   activate (or auto-create) frida 16.6.3 environment
#   frida-X.Y.Z    any version - created on first use
#   frida-list     list all environments
#   deactivate     standard venv deactivate
# =============================================================================

# -- Configuration ------------------------------------------------------------
: "${FRIDA_HOME:=$HOME/.frida-envs}"
mkdir -p "$FRIDA_HOME"

# -- Core helper --------------------------------------------------------------
_frida_activate_version() {
  local version="$1"
  local env_dir="${FRIDA_HOME}/frida_${version}"
  local venv_dir="${env_dir}/.venv"
  local activate_script="${venv_dir}/bin/activate"

  # Create env if it doesn't exist
  if [ ! -f "$activate_script" ]; then
    echo "[frida-env] frida ${version} not found - creating environment..."
    mkdir -p "$env_dir"

    # Find Python (prefer python3.10, then python3, then python)
    local python_bin
    if command -v python3.10 >/dev/null 2>&1; then
      python_bin="python3.10"
    elif command -v python3 >/dev/null 2>&1; then
      python_bin="python3"
    elif command -v python >/dev/null 2>&1; then
      python_bin="python"
    else
      echo "[frida-env] ERROR: python3 not found. Install Python 3 and retry." >&2
      return 1
    fi

    echo "[frida-env] Creating venv with ${python_bin}..."
    "$python_bin" -m venv "$venv_dir" || {
      echo "[frida-env] ERROR: failed to create venv." >&2
      rm -rf "$env_dir"
      return 1
    }

    echo "[frida-env] Installing frida==${version}, frida-tools, objection..."
    "${venv_dir}/bin/pip" install --quiet --upgrade pip
    "${venv_dir}/bin/pip" install "frida==${version}" frida-tools objection || {
      echo "[frida-env] WARNING: some packages may have failed to install." >&2
    }
  fi

  # Activate
  # shellcheck source=/dev/null
  . "$activate_script"

  # Flush command hash cache so new binaries are found without reopening shell.
  # hash -r works unconditionally in both zsh and bash.
  hash -r 2>/dev/null

  echo "[frida-env] Activated  frida ${version}  ->  $(command -v frida)"
}

# -- Register frida-X.Y.Z as a shell function ---------------------------------
_frida_register_version() {
  local version="$1"
  eval "frida-${version}() { _frida_activate_version '${version}'; }"
}

# -- Pre-register all existing frida_* dirs at shell startup ------------------
for _frida_dir in "${FRIDA_HOME}"/frida_*/; do
  if [ -d "$_frida_dir" ]; then
    _frida_ver="${_frida_dir##*/frida_}"
    _frida_ver="${_frida_ver%/}"
    [ -n "$_frida_ver" ] && _frida_register_version "$_frida_ver"
  fi
done
unset _frida_dir _frida_ver

# -- command-not-found handlers -----------------------------------------------
# Intercepts frida-X.Y.Z for versions not yet registered; auto-creates them.
# Both handlers run in the CURRENT shell so `source` works correctly.

_frida_try_handle() {
  local cmd="$1"
  case "$cmd" in
    frida-[0-9]*.[0-9]*.[0-9]*)
      local version="${cmd#frida-}"
      _frida_register_version "$version"
      _frida_activate_version "$version"
      return $?
      ;;
  esac
  return 1
}

# zsh - runs in the current shell so PATH changes from `source` persist
if [ -n "${ZSH_VERSION:-}" ]; then
  command_not_found_handler() {
    _frida_try_handle "$1" && return 0
    echo "zsh: command not found: $1" >&2
    return 127
  }
fi

# bash
if [ -n "${BASH_VERSION:-}" ]; then
  command_not_found_handle() {
    _frida_try_handle "$1" && return 0
    echo "bash: $1: command not found" >&2
    return 127
  }
fi

# -- Convenience commands -----------------------------------------------------
frida-list() {
  echo "Frida environments in ${FRIDA_HOME}:"
  local found=0
  for _d in "${FRIDA_HOME}"/frida_*/; do
    if [ -d "${_d}/.venv" ]; then
      local ver="${_d##*/frida_}"; ver="${ver%/}"
      local marker=""
      [ "${VIRTUAL_ENV:-}" = "${_d%/}/.venv" ] && marker="  <- active"
      printf "  frida-%-16s%s\n" "$ver" "$marker"
      found=1
    fi
  done
  if [ "$found" -eq 0 ]; then
    echo "  (none yet - type frida-X.Y.Z to create one)"
  fi
}
