#!/bin/bash
# Update checker and installer for autoresearch skill
# Usage: bash update.sh [check|install]
# - check: show current vs latest version (default)
# - install: perform the update
set -uo pipefail

REPO="inchan/autoresearch"
VERSION_PATH="skills/autoresearch/VERSION"
RAW_URL="https://raw.githubusercontent.com/$REPO/main/$VERSION_PATH"

# --- Locate installed version ---
find_local_version() {
  local script_dir
  script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  local skill_dir="$script_dir/.."

  if [ -f "$skill_dir/VERSION" ]; then
    tr -d '[:space:]' < "$skill_dir/VERSION"
    return
  fi

  # Fallback: check SKILL.md frontmatter
  if [ -f "$skill_dir/SKILL.md" ]; then
    grep -m1 '^version:' "$skill_dir/SKILL.md" 2>/dev/null | awk '{print $2}' | tr -d '[:space:]'
    return
  fi

  echo "unknown"
}

# --- Fetch latest version from GitHub ---
fetch_remote_version() {
  if command -v curl &>/dev/null; then
    curl -fsSL "$RAW_URL" 2>/dev/null | tr -d '[:space:]'
  elif command -v wget &>/dev/null; then
    wget -qO- "$RAW_URL" 2>/dev/null | tr -d '[:space:]'
  else
    echo "error"
  fi
}

# --- Detect installation method ---
detect_install_method() {
  local script_dir
  script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

  # Check if inside .agents/skills/ (npx skills install)
  if echo "$script_dir" | grep -q '\.agents/skills'; then
    echo "skills"
    return
  fi

  # Check if skills-lock.json exists in project root
  local project_root="$script_dir"
  while [ "$project_root" != "/" ]; do
    if [ -f "$project_root/skills-lock.json" ]; then
      echo "skills"
      return
    fi
    project_root="$(dirname "$project_root")"
  done

  # Check if in a git repo
  if git -C "$script_dir" rev-parse --is-inside-work-tree &>/dev/null; then
    echo "git"
    return
  fi

  echo "manual"
}

# --- Show changelog ---
show_changelog() {
  local from_version="$1"
  local to_version="$2"

  echo ""
  echo "Changelog ($from_version → $to_version):"
  echo "─────────────────────────────────────────"

  if command -v gh &>/dev/null; then
    gh api "repos/$REPO/compare/v${from_version}...main" \
      --jq '.commits[] | "  • " + (.commit.message | split("\n")[0])' 2>/dev/null \
      || echo "  (changelog unavailable — see https://github.com/$REPO/commits/main)"
  else
    echo "  See: https://github.com/$REPO/commits/main"
  fi
}

# --- Commands ---
cmd_check() {
  local local_ver remote_ver
  local_ver=$(find_local_version)
  remote_ver=$(fetch_remote_version)

  echo "autoresearch update check"
  echo "  installed: $local_ver"
  echo "  latest:    $remote_ver"

  if [ "$remote_ver" = "error" ]; then
    echo ""
    echo "Could not reach GitHub. Check your network."
    return 1
  fi

  if [ "$local_ver" = "$remote_ver" ]; then
    echo ""
    echo "Already up to date."
    return 0
  fi

  echo ""
  echo "Update available! Run: /autoresearch update install"
  echo "  or: bash $(dirname "${BASH_SOURCE[0]}")/update.sh install"
  return 0
}

cmd_install() {
  local local_ver remote_ver method
  local_ver=$(find_local_version)
  remote_ver=$(fetch_remote_version)

  if [ "$remote_ver" = "error" ]; then
    echo "Could not reach GitHub. Check your network."
    return 1
  fi

  if [ "$local_ver" = "$remote_ver" ]; then
    echo "Already up to date ($local_ver)."
    return 0
  fi

  method=$(detect_install_method)
  echo "Updating autoresearch $local_ver → $remote_ver (method: $method)"

  case "$method" in
    skills)
      if command -v npx &>/dev/null; then
        npx skills update 2>&1
      else
        echo "npx not found. Run manually: npx skills update"
        return 1
      fi
      ;;
    git)
      local repo_root
      repo_root=$(git -C "$(dirname "${BASH_SOURCE[0]}")" rev-parse --show-toplevel 2>/dev/null)
      if [ -n "$repo_root" ]; then
        git -C "$repo_root" pull --ff-only 2>&1
      else
        echo "Could not find git root."
        return 1
      fi
      ;;
    manual)
      echo "Manual installation detected."
      echo "Update manually: npx skills add $REPO"
      return 1
      ;;
  esac

  show_changelog "$local_ver" "$remote_ver"
  echo ""
  echo "Updated to $remote_ver."
}

# --- Main ---
case "${1:-check}" in
  check)   cmd_check ;;
  install) cmd_install ;;
  *)
    echo "Usage: update.sh [check|install]"
    exit 1
    ;;
esac
