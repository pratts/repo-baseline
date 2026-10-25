---
name: repo-baseline
description: Apply the owner's standard GitHub repository baseline — currently the "Main branch protection" ruleset (PR-only changes to the default branch, 1 approving review, signed commits, no force pushes, required CI checks, owner bypass via PRs only). Use when the user asks to protect a repo's main/default branch, set up branch protection or rulesets, apply their repo baseline/standard settings to a repo, or check whether a repo matches that baseline.
---

# Repo baseline

The baseline lives in this skill's directory:

- `rulesets/main-branch-ruleset.json` — the ruleset payload (source of truth).
- `scripts/apply-branch-ruleset.sh` — creates or updates it on a repo.

Never hand-edit the ruleset on GitHub to apply the baseline; run the script,
so every repo gets the same payload. If the user wants the baseline itself
changed, edit the JSON here and say so — it affects future repos.

## Applying it

1. **Identify the repo.** `gh repo view --json nameWithOwner,visibility,isEmpty,defaultBranchRef`
   in the target directory, or the `owner/repo` the user named.
   - Private repo: rulesets need GitHub Pro, Team or Enterprise. If the API
     refuses, report that rather than working around it.
   - Empty repo (no commits): tell the user the ruleset blocks direct pushes to
     the default branch, so their first commit may not be pushable once it is
     active. Ask whether to apply now or after the initial push.

2. **See what's there.** Before changing anything:
   ```sh
   gh api repos/<o>/<r>/branches/<default>/protection   # classic protection (404 = none)
   gh api repos/<o>/<r>/rulesets
   gh api repos/<o>/<r>/rules/branches/<default>        # effective rules
   ```
   If classic branch protection exists, tell the user before proceeding — it
   would stack with the ruleset. The script updates a ruleset with the same
   name in place (backing it up under `backups/`); any other rulesets are left
   alone, but mention them.

3. **Pick the required checks.** This is the step that needs judgement.
   - List checks that have actually run:
     `gh api repos/<o>/<r>/commits/<default>/check-runs --jq '.check_runs[].name'`
     and cross-check against job `name:` fields in `.github/workflows/*.yml`
     (matrix jobs report one check per combination, e.g. `Test (ubuntu-latest)`).
   - Include build, test, lint/format, vet and vulnerability-scan jobs.
     Exclude Dependabot, release, deploy and other jobs that don't run on PRs.
   - Only require checks that have reported on this repo. A required check
     that never reports blocks every merge.
   - No CI: pass no checks (the script drops the rule) and tell the user.

4. **Run it.**
   ```sh
   <this skill's dir>/scripts/apply-branch-ruleset.sh <owner/repo> "<check 1>" "<check 2>" ...
   ```
   Use the skill directory path, not the target repo's. The bypass actor is
   set to the authenticated `gh` user automatically.

5. **Report.** Whether the repo was protected before and how, what changed,
   the final required checks, the backup path if one was written, and any jobs
   deliberately left out of the required checks.

## Things to tell the user when relevant

- GitHub won't let them approve their own PRs; they merge their own via the
  bypass ("Merge without waiting for requirements to be met"). That override
  skips all rules for that merge, including failing checks.
- `require_code_owner_review` is off in the baseline, so no `CODEOWNERS` file
  is needed. Turning it on without one does nothing.
- Don't commit, push or open PRs as part of applying the baseline — it only
  changes repository settings.
