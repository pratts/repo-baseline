# repo-baseline

Standard settings for my GitHub repositories, kept in one place so every repo
gets the same rules and changes to the standard have history.

## What's in the baseline

`rulesets/main-branch-ruleset.json` — a repository ruleset named
"Main branch protection", targeting the default branch:

| Rule | Effect |
| --- | --- |
| `pull_request` | Changes land only through PRs, with 1 approving review |
| `required_signatures` | Every commit must be signed |
| `non_fast_forward` | No force pushes |
| `required_status_checks` | Listed CI checks must pass, branch up to date with the default branch |
| Bypass (`pull_request` mode) | The repo owner can merge their own PRs without approval, but can't push directly |

Required check names differ per repo, so they're passed to the script rather
than stored in the JSON.

## Applying it

Requires [`gh`](https://cli.github.com/) (authenticated) and `jq`.

```sh
# repo for the current directory, with required checks
scripts/apply-branch-ruleset.sh "" "Test (ubuntu-latest)" "govulncheck"

# a specific repo
scripts/apply-branch-ruleset.sh pratts/other-repo "build" "lint"

# a repo with no CI (the status-check rule is left out)
scripts/apply-branch-ruleset.sh pratts/other-repo
```

- The bypass actor is set to whoever `gh` is logged in as.
- If the repo already has a ruleset with the same name, it is backed up to
  `backups/` (gitignored) and updated in place; otherwise a new one is created.
- Only list checks that have actually run on the repo — a required check that
  never reports blocks every merge. Find them with
  `gh api repos/<owner>/<repo>/commits/<branch>/check-runs --jq '.check_runs[].name'`.
- Rulesets on private repos need GitHub Pro, Team or Enterprise.

Without the script, the JSON can be imported on GitHub under
**Settings → Rules → Rulesets → New ruleset → Import a ruleset** (fill in the
check names afterwards).

## Using it from Claude Code

`SKILL.md` makes this repo a Claude Code skill: it tells Claude how to pick the
right check names for a repo and run the script.

### Install (once per machine)

```sh
git clone git@github.com:pratts/repo-baseline.git ~/work/github/repo-baseline
~/work/github/repo-baseline/scripts/install-skill.sh
```

This symlinks the clone to `~/.claude/skills/repo-baseline` (or
`$CLAUDE_CONFIG_DIR/skills/` if set), making the skill available in every
Claude Code session. Start a new session after installing, then ask Claude to
"apply my repo baseline" in any repo.

- **Update:** `git pull` in the clone. The symlink means there's nothing to
  reinstall.
- **Uninstall:** `scripts/install-skill.sh --uninstall` removes the symlink
  only; the clone stays.
- Re-running the installer is safe. It won't overwrite an existing
  `repo-baseline` skill that points somewhere else.

### Why not clone it into a project's `.claude/skills/`?

Claude Code also loads skills from a project's `.claude/skills/`, but cloning
a git repo there nests one repository inside another, which causes problems:

- `git status` in the outer repo shows `.claude/skills/` as untracked
  forever.
- `git add .` (or `git add .claude`) records the clone as an *embedded
  repository*: a pointer to a commit, not the files. Other clones of the outer
  repo get an empty, broken folder, and git prints an `adding embedded git
  repository` warning.
- Git commands run inside that folder act on the inner repo, which is easy to
  mix up.

This skill applies to every repo, so install it per user as above. If a
project genuinely needs a shared skill in its own `.claude/skills/`, either
commit the skill's files directly, add it as a submodule
(`git submodule add <url> .claude/skills/<name>`) so clones can fetch it, or,
for a personal-only copy, keep it out of the outer repo with
`.git/info/exclude`.
