#!/usr/bin/env bash
# Install this repo as a user-level Claude Code skill by symlinking it into
# ~/.claude/skills/repo-baseline. The symlink keeps the skill in sync with
# this clone: `git pull` here updates it, with nothing to copy.
#
# Usage:
#   scripts/install-skill.sh            # install (or confirm already installed)
#   scripts/install-skill.sh --uninstall
#
# Installs per user rather than into a project's .claude/skills, so no other
# repo ends up with this one nested inside it (see README).
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd -P)"
skills_dir="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/skills"
link="$skills_dir/repo-baseline"

if [ "${1:-}" = "--uninstall" ]; then
	if [ -L "$link" ]; then
		rm "$link"
		echo "Removed $link"
	elif [ -e "$link" ]; then
		echo "$link is not a symlink; leaving it alone" >&2
		exit 1
	else
		echo "Not installed ($link does not exist)"
	fi
	exit 0
fi

mkdir -p "$skills_dir"

if [ -L "$link" ]; then
	current="$(cd "$link" 2>/dev/null && pwd -P)" || current=
	if [ "$current" = "$root" ]; then
		echo "Already installed: $link -> $root"
		exit 0
	fi
	echo "$link already points to ${current:-a missing path}; run with --uninstall first" >&2
	exit 1
elif [ -e "$link" ]; then
	echo "$link already exists and is not a symlink; move it aside first" >&2
	exit 1
fi

ln -s "$root" "$link"
echo "Installed: $link -> $root"
echo "Start a new Claude Code session to pick it up."
