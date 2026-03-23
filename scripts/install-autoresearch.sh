#!/usr/bin/env bash
# skills.sh-style installer helper for Autoresearch Claude plugin
# Supports interactive (TUI-like) mode and non-interactive flags.

set -euo pipefail

PLUGIN_NAME="autoresearch"
PLUGIN_SOURCE_DEFAULT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ACTION=""
NON_INTERACTIVE=0
PLUGIN_SOURCE="$PLUGIN_SOURCE_DEFAULT"
YES=0

usage() {
  cat <<USAGE
Usage: scripts/install-autoresearch.sh [options]

Options:
  --action <install|update|uninstall>  Action to run
  --source <path-or-url>               Plugin source for install/update (default: repo root)
  --yes                                Auto-confirm prompts
  --non-interactive                    Require full flags, no prompts
  -h, --help                           Show this help

Examples:
  scripts/install-autoresearch.sh
  scripts/install-autoresearch.sh --action install --source . --yes --non-interactive
  scripts/install-autoresearch.sh --action uninstall --yes --non-interactive
USAGE
}

require_claude() {
  if ! command -v claude >/dev/null 2>&1; then
    echo "Error: 'claude' CLI not found in PATH." >&2
    echo "Install Claude Code CLI first, then run this installer." >&2
    exit 1
  fi
}

confirm() {
  local prompt="$1"
  if [[ "$YES" -eq 1 ]]; then
    return 0
  fi
  read -r -p "$prompt [y/N]: " answer
  [[ "$answer" == "y" || "$answer" == "Y" ]]
}

run_install() {
  echo "Installing plugin '$PLUGIN_NAME' from: $PLUGIN_SOURCE"
  claude plugin add "$PLUGIN_SOURCE"
  echo "Done: installed '$PLUGIN_NAME'."
}

run_update() {
  echo "Updating plugin '$PLUGIN_NAME' from: $PLUGIN_SOURCE"
  # add is used as idempotent update path for local plugin source.
  claude plugin add "$PLUGIN_SOURCE"
  echo "Done: updated '$PLUGIN_NAME'."
}

run_uninstall() {
  echo "Removing plugin '$PLUGIN_NAME'"
  claude plugin remove "$PLUGIN_NAME"
  echo "Done: removed '$PLUGIN_NAME'."
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --action)
        ACTION="${2:-}"
        shift 2
        ;;
      --source)
        PLUGIN_SOURCE="${2:-}"
        shift 2
        ;;
      --yes)
        YES=1
        shift
        ;;
      --non-interactive)
        NON_INTERACTIVE=1
        shift
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        echo "Unknown option: $1" >&2
        usage
        exit 1
        ;;
    esac
  done
}

select_action_interactive() {
  echo "Autoresearch Installer (skills.sh-style)"
  echo "Choose action:"
  PS3="Enter choice [1-3]: "
  select choice in "Install" "Update" "Uninstall"; do
    case "$REPLY" in
      1) ACTION="install"; break ;;
      2) ACTION="update"; break ;;
      3) ACTION="uninstall"; break ;;
      *) echo "Invalid choice" ;;
    esac
  done

  if [[ "$ACTION" != "uninstall" ]]; then
    read -r -p "Plugin source (default: $PLUGIN_SOURCE): " input_source
    if [[ -n "$input_source" ]]; then
      PLUGIN_SOURCE="$input_source"
    fi
  fi
}

main() {
  parse_args "$@"
  require_claude

  if [[ "$NON_INTERACTIVE" -eq 1 ]]; then
    if [[ -z "$ACTION" ]]; then
      echo "Error: --non-interactive requires --action." >&2
      exit 1
    fi
  elif [[ -z "$ACTION" ]]; then
    select_action_interactive
  fi

  case "$ACTION" in
    install)
      confirm "Proceed with install?" || exit 0
      run_install
      ;;
    update)
      confirm "Proceed with update?" || exit 0
      run_update
      ;;
    uninstall)
      confirm "Proceed with uninstall?" || exit 0
      run_uninstall
      ;;
    *)
      echo "Error: invalid --action '$ACTION'. Use install|update|uninstall." >&2
      exit 1
      ;;
  esac
}

main "$@"
