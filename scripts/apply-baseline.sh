#!/usr/bin/env bash
# Apply the repo baseline to a GitHub repo:
#   1. repo settings from settings/repo-settings.json (deletes a PR's branch
#      automatically once the PR merges), then
#   2. the "Main branch protection" ruleset from
#      rulesets/main-branch-ruleset.json on its default branch.
#
# Usage:
#   scripts/apply-baseline.sh <owner/repo> [check name]...
#
#   check name  each CI check that must pass before merging, e.g.
#               "Test (ubuntu-latest)". Only list checks that have already
#               run on the repo -- a required check that never reports
#               blocks every merge. With none, no checks are required.
#
# The bypass is set to the logged-in gh user, for PRs only: they can merge
# their own PRs but can't push directly. Safe to re-run: settings are
# re-applied and an existing ruleset of the same name is updated in place,
# after a backup is saved under backups/ (gitignored).
#
# Requires: gh (logged in), jq.
set -euo pipefail

if [ $# -lt 1 ] || [ -z "$1" ]; then
	echo "usage: $0 <owner/repo> [check name]..." >&2
	exit 2
fi
repo=$1
shift

root="$(cd "$(dirname "$0")/.." && pwd -P)"
settings="$root/settings/repo-settings.json"
ruleset="$root/rulesets/main-branch-ruleset.json"

echo "Applying repo settings on $repo"
gh api -X PATCH "repos/$repo" --input "$settings" |
	jq -c --slurpfile want "$settings" 'with_entries(select(.key as $k | $want[0] | has($k)))'

user_id=$(gh api user --jq .id)
checks=$(printf '%s\n' "$@" | jq -R 'select(length > 0) | {context: .}' | jq -s .)

body=$(jq --argjson uid "$user_id" --argjson checks "$checks" '
	.bypass_actors = [{actor_id: $uid, actor_type: "User", bypass_mode: "pull_request"}]
	| if ($checks | length) > 0
	  then .rules |= map(if .type == "required_status_checks"
	                     then .parameters.required_status_checks = $checks else . end)
	  else .rules |= map(select(.type != "required_status_checks"))
	  end' "$ruleset")

name=$(jq -r .name <<<"$body")
existing=$(gh api "repos/$repo/rulesets" --jq ".[] | select(.name == \"$name\") | .id" | head -n1)

if [ -n "$existing" ]; then
	mkdir -p "$root/backups"
	backup="$root/backups/ruleset-${repo//\//_}-$existing-$(date +%Y%m%d-%H%M%S).json"
	gh api "repos/$repo/rulesets/$existing" >"$backup"
	echo "Updating ruleset $existing on $repo (backup: $backup)"
	gh api -X PUT "repos/$repo/rulesets/$existing" --input - <<<"$body" >/dev/null
else
	echo "Creating ruleset on $repo"
	gh api -X POST "repos/$repo/rulesets" --input - <<<"$body" >/dev/null
fi

default_branch=$(gh repo view "$repo" --json defaultBranchRef --jq .defaultBranchRef.name)
echo "Rules now active on $default_branch:"
gh api "repos/$repo/rules/branches/$default_branch" --jq '.[].type'
