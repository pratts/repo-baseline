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

Re-running is safe. If the repo already has a ruleset of the same name, a
backup is saved to `backups/` (gitignored) and the ruleset is updated in place.
Run with no check names on a repo that already has "Required checks", and that
ruleset is left as it is (with a warning); delete it in the repo's settings if
it should no longer apply.

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
| Bypass (PRs only) | You (the `gh` user) can merge your own PRs without an approval, but can't push directly |

**Ruleset "Required checks"**: `rulesets/required-checks-ruleset.json`, on the
default branch, only when you list check names

| Rule | Effect |
| --- | --- |
| `required_status_checks` | The checks you list must pass, with the branch up to date |
| No bypass | Nobody, you included, can merge while a check is running or failing |

The checks live in their own ruleset because a bypass covers every rule in its
ruleset: with them in "Main branch protection", your bypass would also skip
them.

Who can do what:

| Who | Merge | Needs an approval | Waits for checks |
| --- | --- | --- | --- |
| You | Yes | No | Yes |
| Collaborators with write access | Yes | Yes, from you or another collaborator | Yes |
| Fork contributors | No, someone with write access merges | Yes | Yes |

GitHub won't let you approve your own PR, so merge yours with **"Merge
without waiting for requirements to be met"**. That skips only the approval;
the required checks still have to pass. Rulesets on private repos need GitHub Pro,
Team or Enterprise.

By default GitHub doesn't run workflows on a first-time contributor's fork PR
until someone with write access clicks **Approve and run**. Until then the
required checks stay pending and the PR can't merge.
