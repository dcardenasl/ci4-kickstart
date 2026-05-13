# Release procedure — ci4-kickstart

This document describes how to publish a new release of `ci4-kickstart`. The repo is a shell-script orchestrator (no `composer.json`, no `package.json`) versioned **only by git tags**. A tag push on `main` triggers `.github/workflows/release.yml`, which extracts the matching `## [VERSION]` block from `CHANGELOG.md` and creates the corresponding GitHub Release.

## Pre-flight checklist

Before tagging, every item below must be true. Treat any "no" as a blocker.

1. **`dev` is green on CI.**
   - `.github/workflows/e2e.yml` is passing on the latest `dev` commit — it runs `new-project.sh --yes --reset-db` against a real MySQL 8.0 container and verifies that the generated API + Admin (+ optional Domain) bootstrap cleanly.
   - `.github/workflows/release.yml` exists and is wired to `v*.*.*` tag pushes.
2. **Working tree is clean.** `git status --porcelain` returns nothing on `dev`.
3. **Local syntax check passes.**
   ```bash
   bash -n new-project.sh                  # syntax-only parse
   shellcheck new-project.sh               # if installed; CI runs it
   bash new-project.sh --help              # confirm usage text is current
   ```
4. **`CHANGELOG.md` has a dated `## [X.Y.Z]` section** at the top (under `## [Unreleased]`, which should be empty). The version string in the heading must match the tag you will push (without the `v` prefix — `1.1.0`, not `v1.1.0`).
5. **`CLAUDE.md` footer is current.** `**Last Updated:** YYYY-MM-DD` matches the release date.
6. **Documented assumptions about the sub-starters still hold.** `new-project.sh` clones `main` of `ci4-api-starter`, `ci4-admin-starter`, and `ci4-domain-starter` (shallow). Before tagging, confirm that the latest release of each sub-starter has already been merged into its `main` — otherwise `new-project.sh` will pick up unreleased work. Sanity check:
   ```bash
   for repo in ci4-api-starter ci4-admin-starter ci4-domain-starter; do
     gh api "repos/dcardenasl/${repo}/releases/latest" --jq '"\(.tag_name) (\(.published_at))"'
     gh api "repos/dcardenasl/${repo}/commits/main" --jq '.commit.message' | head -1
   done
   ```
7. **End-to-end smoke** (optional but recommended for major bumps):
   ```bash
   cd /tmp && rm -rf kit-smoke && mkdir kit-smoke && cd kit-smoke
   CI4_PROJECT_NAME=smoke CI4_OUTPUT_DIR=. CI4_INCLUDE_DOMAIN=n bash /path/to/ci4-kickstart/new-project.sh --yes --reset-db
   ```
   Verifies the non-interactive path end-to-end against your local MySQL.

For a major release (`X.0.0`), also confirm:

- Any `### ⚠️ Breaking Changes` and `### Migration Guide` blocks in the `[X.0.0]` section accurately describe how previously-generated projects (or invocation patterns) are affected. A break here is almost always one of: removing a prompt, renaming an env var (`CI4_*`), or changing the default sub-starter set.
- The `[X.0.0]: …compare/vX-1.Y.Z...vX.0.0` link at the bottom of `CHANGELOG.md` resolves on GitHub.

## Release steps

The branching model is `dev → main → tag`. Tags are always cut from `main`.

1. **On `dev`, land the release-marker commit.** This commit only finalises `CHANGELOG.md` (rename `[Unreleased]` → `[X.Y.Z] — YYYY-MM-DD`, add a fresh empty `[Unreleased]` on top) and the `Last Updated:` footer in `CLAUDE.md`.
   ```bash
   git checkout dev
   git pull --ff-only
   # Edit CHANGELOG.md + CLAUDE.md footer
   git add CHANGELOG.md CLAUDE.md
   git commit -m "chore: release vX.Y.Z"
   git push origin dev
   ```
2. **Merge `dev` into `main`.** Open a PR and merge fast-forward (or via a merge commit, depending on repo policy). Do not squash — the release marker commit should survive.
   ```bash
   # Via the GitHub UI (preferred) or:
   git checkout main && git pull --ff-only
   git merge --ff-only dev
   git push origin main
   ```
3. **Tag and push.** The tag must be created **from `main`**, not from `dev`. The workflow checks out the tag at the matching commit.
   ```bash
   git checkout main
   git tag vX.Y.Z
   git push origin vX.Y.Z
   ```
4. **Watch the workflow.** `.github/workflows/release.yml` will:
   - Check out the tag.
   - Run an inline `awk` over `CHANGELOG.md` to extract the body between `## [X.Y.Z]` and the next `## [` heading.
   - Create the GitHub Release with that body as the release notes. If the release already exists (re-tag scenario), it edits the existing one instead of failing.
5. **Verify the release page.** Open `https://github.com/dcardenasl/ci4-kickstart/releases/tag/vX.Y.Z` and confirm the notes match the `[X.Y.Z]` block of `CHANGELOG.md`. An empty body almost always means a heading mismatch (stray whitespace, wrong version-string casing).

## Post-release

- Confirm `[Unreleased]` exists on `dev` and is empty so the next cycle has a clean target.
- Update `TASKS.md` to close any KICK-* items the release shipped. Archive entries in `TASKS_ARCHIVE.md`.
- If the workspace-level `../TASKS.md` carries a milestone tracker, update it.

## Rollback

A tag push triggers the release workflow exactly once. If the release notes are wrong, **prefer editing the GitHub Release directly** (the workflow is idempotent on re-tag and will overwrite the notes from `CHANGELOG.md`).

A bad tag can be retracted with:
```bash
git tag -d vX.Y.Z
git push --delete origin vX.Y.Z
```
This is only safe if **no downstream has pulled the tag yet**. Since this repo is an orchestrator (not a Composer dependency), the "downstream consumer" surface is essentially humans who ran `git clone` — limited blast radius. Still, prefer a follow-up `vX.Y.(Z+1)` patch release for anything beyond a release-notes typo.

## Notes specific to this repo

- **No `composer.json`, no `composer quality`.** The only first-class quality gate is `e2e.yml`, which spawns a real MySQL and runs `new-project.sh` end-to-end. Local pre-tag checks reduce to `bash -n`, `shellcheck`, and an optional manual `--yes --reset-db` run.
- **`new-project.sh` clones `main` of the sub-starters.** It does **not** pin specific tags. A release of this kit therefore implicitly depends on the current state of `main` in `ci4-api-starter`, `ci4-admin-starter`, and `ci4-domain-starter`. If you ever need to ship a kit version against a frozen sub-starter version, add a `--ref` flag (tracked as a future KICK-* task) before the release — do not work around it by tagging when sub-starter `main` is mid-flight.
- **Backward compatibility surface.** The user-visible contract is: the set of CLI flags (`--yes`, `--reset-db`, `--help`), the prompt sequence, the `CI4_*` environment-variable names, and the generated directory layout (`{name}-api/`, `{name}-admin/`, optional `{name}-domain/`). Renaming any of those is a major bump.
- **Coverage gate.** N/A — there's no unit test suite in this repo.
