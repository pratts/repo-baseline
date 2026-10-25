# repo-baseline

Standard settings for my GitHub repositories, applied with one script.

## Usage

Requires [`gh`](https://cli.github.com/) (logged in) and `jq`.

```sh
scripts/apply-baseline.sh <owner/repo> [check name]...
```

```sh
# with required CI checks
scripts/apply-baseline.sh pratts/tocli "Test (ubuntu-latest)" "govulncheck"

# a repo with no CI
scripts/apply-baseline.sh pratts/other-repo
```

Only list checks that have already run on the repo; a required check that
never reports blocks every merge. To see a repo's check names:

```sh
gh api repos/<owner>/<repo>/commits/main/check-runs --jq '.check_runs[].name'
```

Re-running is safe. If the repo already has the ruleset, a backup is saved
to `backups/` (gitignored) and the ruleset is updated in place.

## What it sets

**Repo settings**: `settings/repo-settings.json`

| Setting | Effect |
| --- | --- |
| `delete_branch_on_merge` | A PR's branch is deleted automatically once the PR merges |

**Ruleset "Main branch protection"**: `rulesets/main-branch-ruleset.json`,
on the default branch

| Rule | Effect |
| --- | --- |
| `pull_request` | Changes land only through PRs, with 1 approving review |
| `required_signatures` | Every commit must be signed |
| `non_fast_forward` | No force pushes |
| `required_status_checks` | The checks you list must pass, with the branch up to date |
| Bypass (PRs only) | You (the `gh` user) can merge your own PRs, but can't push directly |

GitHub won't let you approve your own PR, so merge yours with **"Merge
without waiting for requirements to be met"**. Rulesets on private repos need
GitHub Pro, Team or Enterprise.
