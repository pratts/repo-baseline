#!/usr/bin/env bash
# Apply the repo baseline to a GitHub repo:
#   - repository settings from settings/repo-settings.json (e.g. deleting
#     head branches automatically once their PR merges), and
#   - the "Main branch protection" ruleset (rulesets/main-branch-ruleset.json)
#     on its default branch.
#
# Usage:
#   scripts/apply-baseline.sh [owner/repo] [check name]...
#
#   owner/repo  defaults to the repo for the current directory.
#   check name  each required status check, e.g. "Test (ubuntu-latest)".
#               Only list checks that have actually run on the repo -- a
#               required check that never reports blocks every merge. With
#               none given, the required_status_checks rule is dropped.
#
# The bypass actor is replaced with the authenticated gh user (bypass mode
# "pull_request": can merge own PRs, can't push directly). If a ruleset with
# the same name already exists it is updated in place, after saving a
# backup of it under backups/ in this repo (gitignored).
#
# Requires: gh (authenticated), jq.
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd -P)"
payload="$root/rulesets/main-branch-ruleset.json"
settings="$root/settings/repo-settings.json"

repo="${1:-}"
[ $# -gt 0 ] && shift
if [ -z "$repo" ]; then
	repo=$(gh repo view --json nameWithOwner --jq .nameWithOwner)
fi

# Repo settings are a plain PATCH: only the keys in the file change, and
# re-running is a no-op. Echo back just those keys as GitHub now has them.
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
	  end' "$payload")

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
