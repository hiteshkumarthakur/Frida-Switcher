#!/usr/bin/env bash
# =============================================================================
# install.sh  -  Frida version manager installer  (macOS + Linux)
# =============================================================================
set -e

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_PATH="${REPO_DIR}/frida-env.sh"

# -- Determine FRIDA_HOME -----------------------------------------------------
DEFAULT_HOME="${HOME}/.frida-envs"
if [ -z "${FRIDA_HOME:-}" ]; then
  printf "Where should frida envs be stored? [%s]: " "$DEFAULT_HOME"
  read -r _input
  FRIDA_HOME="${_input:-$DEFAULT_HOME}"
fi
mkdir -p "$FRIDA_HOME"

# -- Detect shell config file -------------------------------------------------
detect_rc() {
  case "${SHELL##*/}" in
    zsh)
      echo "${ZDOTDIR:-$HOME}/.zshrc"
      ;;
    bash)
      if [ "$(uname -s)" = "Darwin" ]; then
        echo "$HOME/.bash_profile"
      else
        echo "$HOME/.bashrc"
      fi
      ;;
    *)
      echo "$HOME/.profile"
      ;;
  esac
}
SHELL_RC="$(detect_rc)"

# -- Bail if already installed ------------------------------------------------
if grep -qF "frida-env.sh" "$SHELL_RC" 2>/dev/null; then
  echo "Already installed in ${SHELL_RC}"
  echo "To update FRIDA_HOME, edit the export line in that file."
  exit 0
fi

# -- Append to shell config ---------------------------------------------------
cat >> "$SHELL_RC" << RCEOF

# -- Frida version manager ----------------------------------------------------
export FRIDA_HOME="${FRIDA_HOME}"
source "${SCRIPT_PATH}"
RCEOF

echo ""
echo "Installed!  Added to ${SHELL_RC}:"
echo "  export FRIDA_HOME=\"${FRIDA_HOME}\""
echo "  source \"${SCRIPT_PATH}\""
echo ""
echo "Reload your shell:"
echo "  source ${SHELL_RC}"
echo ""
echo "Then try:"
echo "  frida-16.6.3    # activate or auto-create frida 16.6.3"
echo "  frida-list      # list all available environments"
