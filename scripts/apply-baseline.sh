#!/usr/bin/env bash
# Apply the repo baseline to a GitHub repo:
#   1. repo settings from settings/repo-settings.json (deletes a PR's branch
#      automatically once the PR merges), then
#   2. the "Main branch protection" ruleset from
#      rulesets/main-branch-ruleset.json on its default branch (PRs, 1
#      approval, signed commits, no force pushes), then
#   3. the "Required checks" ruleset from rulesets/required-checks-ruleset.json
#      with the check names given, if any.
#
# Usage:
#   scripts/apply-baseline.sh <owner/repo> [check name]...
#
#   check name  each CI check that must pass before merging, e.g.
#               "Test (ubuntu-latest)". Only list checks that have already
#               run on the repo -- a required check that never reports
#               blocks every merge. With none, no checks are required.
#
# "Main branch protection" can be bypassed by the logged-in gh user, for PRs
# only: they can merge their own PRs without an approval but can't push
# directly. "Required checks" has no bypass, so nobody -- that user included --
# can merge until the checks pass. Safe to re-run: settings are re-applied and
# an existing ruleset of the same name is updated in place, after a backup is
# saved under backups/ (gitignored).
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
main_ruleset="$root/rulesets/main-branch-ruleset.json"
checks_ruleset="$root/rulesets/required-checks-ruleset.json"

echo "Applying repo settings on $repo"
gh api -X PATCH "repos/$repo" --input "$settings" |
	jq -c --slurpfile want "$settings" 'with_entries(select(.key as $k | $want[0] | has($k)))'

# ruleset_id <name>: id of the repo's ruleset with that name, or empty.
ruleset_id() {
	gh api "repos/$repo/rulesets" --jq ".[] | select(.name == \"$1\") | .id" | head -n1
}

# apply_ruleset <body>: create the ruleset, or back up and update the one
# with the same name.
apply_ruleset() {
	local body=$1 name existing backup
	name=$(jq -r .name <<<"$body")
	existing=$(ruleset_id "$name")
	if [ -n "$existing" ]; then
		mkdir -p "$root/backups"
		backup="$root/backups/ruleset-${repo//\//_}-$existing-$(date +%Y%m%d-%H%M%S).json"
		gh api "repos/$repo/rulesets/$existing" >"$backup"
		echo "Updating ruleset \"$name\" ($existing) on $repo (backup: $backup)"
		gh api -X PUT "repos/$repo/rulesets/$existing" --input - <<<"$body" >/dev/null
	else
		echo "Creating ruleset \"$name\" on $repo"
		gh api -X POST "repos/$repo/rulesets" --input - <<<"$body" >/dev/null
	fi
}

user_id=$(gh api user --jq .id)
apply_ruleset "$(jq --argjson uid "$user_id" '
	.bypass_actors = [{actor_id: $uid, actor_type: "User", bypass_mode: "pull_request"}]
	' "$main_ruleset")"

checks=$(printf '%s\n' "$@" | jq -R 'select(length > 0) | {context: .}' | jq -s .)
if [ "$(jq length <<<"$checks")" -gt 0 ]; then
	apply_ruleset "$(jq --argjson checks "$checks" '
		.bypass_actors = []
		| .rules |= map(if .type == "required_status_checks"
		                then .parameters.required_status_checks = $checks else . end)
		' "$checks_ruleset")"
else
	checks_name=$(jq -r .name "$checks_ruleset")
	if [ -n "$(ruleset_id "$checks_name")" ]; then
		echo "warning: no check names given, so \"$checks_name\" was left as it is." >&2
		echo "         Delete it in the repo's settings if it should no longer apply." >&2
	fi
fi

default_branch=$(gh repo view "$repo" --json defaultBranchRef --jq .defaultBranchRef.name)
echo "Rules now active on $default_branch:"
gh api "repos/$repo/rules/branches/$default_branch" --jq '.[].type'
