# ─────────────────────────────────────────────────────────────────────────────
# frida-env.sh  —  Frida version switcher
#
# Usage: source this file from ~/.zshrc
#   After that, activate any frida venv by typing:
#       frida-16.6.3
#       frida-17.8.0
#       frida-X.Y.Z   ← creates the env + installs frida==X.Y.Z, frida-tools,
#                        and objection if it doesn't exist yet
# ─────────────────────────────────────────────────────────────────────────────

FRIDA_BASE="$HOME/Desktop/tools/frida"

# ── Core helper ──────────────────────────────────────────────────────────────
# Called with a version string like "16.6.3"
_frida_activate_version() {
  local version="$1"
  local env_dir="${FRIDA_BASE}/frida_${version}"
  local venv_dir="${env_dir}/.venv"
  local activate_script="${venv_dir}/bin/activate"

  # ── Create env if it doesn't exist ────────────────────────────────────────
  if [[ ! -f "$activate_script" ]]; then
    echo "[frida-env] frida ${version} not found — creating environment…"
    mkdir -p "$env_dir"

    # Prefer python3.10 (matches existing envs); fall back to python3 / python
    local python_bin
    if command -v python3.10 &>/dev/null; then
      python_bin="python3.10"
    elif command -v python3 &>/dev/null; then
      python_bin="python3"
    else
      python_bin="python"
    fi

    echo "[frida-env] Creating venv with ${python_bin}…"
    "$python_bin" -m venv "$venv_dir" || {
      echo "[frida-env] ERROR: failed to create venv." >&2
      return 1
    }

    echo "[frida-env] Installing frida==${version}, frida-tools, objection…"
    "${venv_dir}/bin/pip" install --quiet --upgrade pip
    "${venv_dir}/bin/pip" install "frida==${version}" frida-tools objection || {
      echo "[frida-env] WARNING: some packages may have failed to install." >&2
    }
  fi

  # ── Activate ──────────────────────────────────────────────────────────────
  source "$activate_script"
  # Flush zsh's command hash cache so newly added binaries (frida, objection,
  # etc.) are immediately found without opening a new shell.
  rehash
  echo "[frida-env] Activated frida ${version}  ($(which frida))"
}

# ── Register a frida-X.Y.Z function for a known version ──────────────────────
_frida_register_version() {
  local version="$1"
  # eval is required here to dynamically create a named function in zsh
  eval "frida-${version}() { _frida_activate_version '${version}'; }"
}

# ── Pre-register all existing frida_* directories at shell startup ───────────
for _frida_dir in "${FRIDA_BASE}"/frida_*/; do
  if [[ -d "$_frida_dir" ]]; then
    _frida_ver="${_frida_dir##*/frida_}"   # strip leading path + "frida_"
    _frida_ver="${_frida_ver%/}"           # strip trailing slash
    _frida_register_version "$_frida_ver"
  fi
done
unset _frida_dir _frida_ver

# ── command_not_found_handler — catches frida-X.Y.Z for unknown versions ─────
# zsh calls this in the current shell (not a subshell), so `source` works fine.
_frida_prev_command_not_found_handler=""
if typeset -f command_not_found_handler &>/dev/null; then
  # Preserve any existing handler (e.g. from Homebrew or another tool)
  _frida_prev_command_not_found_handler="$(typeset -f command_not_found_handler)"
fi

command_not_found_handler() {
  local cmd="$1"

  # Match frida-X.Y.Z  (digits.digits.digits)
  if [[ "$cmd" =~ ^frida-[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    local version="${cmd#frida-}"
    # Register so it's available as a real function for the rest of the session
    _frida_register_version "$version"
    _frida_activate_version "$version"
    return $?
  fi

  # Fall through to the previously-existing handler (if any), or default message
  if [[ -n "$_frida_prev_command_not_found_handler" ]]; then
    # Re-invoke original handler
    command_not_found_handler_orig "$@"
  else
    echo "zsh: command not found: $cmd" >&2
    return 127
  fi
}

# ── Convenience: list available frida environments ───────────────────────────
frida-list() {
  echo "Available frida environments in ${FRIDA_BASE}:"
  local found=0
  for _d in "${FRIDA_BASE}"/frida_*/; do
    if [[ -d "$_d/.venv" ]]; then
      local ver="${_d##*/frida_}"; ver="${ver%/}"
      local active=""
      [[ "$VIRTUAL_ENV" == "${_d}.venv" || "$VIRTUAL_ENV" == "${_d%/}/.venv" ]] && active=" ← active"
      echo "  frida-${ver}${active}"
      found=1
    fi
  done
  [[ $found -eq 0 ]] && echo "  (none)"
}
