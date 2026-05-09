<!--
ci4-kickstart is a bash orchestrator (no PHP code). The checklist below is
shaped around shell scripts and cross-repo coordination — not PHPStan / arch-drift.
Delete sections that don't apply.
-->

## Summary

<!-- One-paragraph "why this exists". State the user-visible change first.
     If this PR closes a tracked task, mention the ID (KICK-NNN) and link
     to ../TASKS.md so reviewers can see the cross-repo context. -->

## What changed

### `new-project.sh` / scripts
<!-- Bullet the script-level changes: new prompts, new flags, new env vars,
     new cleanup paths. Mention every CI4_* env var added. -->

### Docs synced
<!-- Updates required when new-project.sh changes (kit governance):
     - [ ] CHANGELOG.md ([Unreleased] section)
     - [ ] CLAUDE.md (orchestrator-level guidance)
     - [ ] README.md (public-facing description)
     - [ ] AI_NEW_PROJECT_PROMPT.en.md
     - [ ] AI_NEW_PROJECT_PROMPT.es.md (kept in sync with EN)
     - [ ] TASKS.md (move task between sections) -->

### Sub-repo coordination
<!-- If this PR depends on changes in ci4-api-starter, ci4-admin-starter or
     ci4-domain-starter (e.g. a new spark command, a new init.sh flag),
     link the upstream PR and gate this one's merge on it. -->

- [ ] Upstream PRs (must merge first):
  - `ci4-api-starter#NNN` — _description_
  - `ci4-admin-starter#NNN` — _description_
  - `ci4-domain-starter#NNN` — _description_

## Why

<!-- Motivation. What was painful before? What does this unlock?
     Link the originating audit / signal / milestone in ../TASKS.md if any. -->

## Validation

### Local script checks
- [ ] `bash -n new-project.sh` (no syntax errors)
- [ ] `bash new-project.sh --help` reflects new flags / env vars
- [ ] `shellcheck new-project.sh` (if installed; warnings reviewed)

### Smoke runs (cover both branches when introducing a prompt)
- [ ] **macOS**: full run completes, all generated repos boot (`composer install` + `php spark serve` for each)
- [ ] **Linux** (or WSL2): full run completes
- [ ] **Default-N path** (skip new prompts): identical to previous release — no regression on existing flow
- [ ] **Opt-in path** (answer Y to new prompt, if applicable): all generated repos work end-to-end

### CI
- [ ] `.github/workflows/e2e.yml` updated if a new code path needs coverage
- [ ] e2e workflow green on the PR branch

## Risks & rollback

| Risk | Mitigation |
|---|---|
| <!-- e.g. background process leaks --> | <!-- e.g. trap kills HUB_PID before rm -rf --> |
| <!-- e.g. response envelope drift --> | <!-- e.g. die with clear message if parse fails --> |

**Rollback:** <!-- usually `git revert` is safe; note any state that survives a revert (created repos, registered apps in a hub, DB rows, etc.) -->

## Backward compatibility

<!-- Default answer for orchestrator changes is "no breaking changes — opt-in".
     If breaking, list the env vars / prompts whose behavior changed, and how
     existing projects derived from older kit versions are affected (usually:
     not at all — generated projects are independent copies). -->

- [ ] No breaking changes (opt-in path)
- [ ] Breaking change — described above + noted in CHANGELOG

## Cross-platform sanity

<!-- This script must run on macOS (BSD coreutils), Linux (GNU coreutils)
     and Windows WSL2 / Git Bash. Flag anything platform-specific:
     - `sed -i` vs `sed -i ''` (BSD vs GNU)
     - `mktemp -d` vs `mktemp -d -t prefix` 
     - `readlink -f` (not on BSD by default)
     - dependencies on tools beyond git/php/composer/npm/mysql -->

- [ ] No GNU-only flags (script uses portable equivalents)
- [ ] No new external dependencies beyond `git`, `php`, `composer`, `npm`, `mysql`
- [ ] Exit codes propagate correctly through `cleanup_on_error`

## Notes for reviewers

- **Risks I'm aware of:**
- **Things I'd like a second opinion on:**
- **Out of scope (deferred to follow-up):**

## Closes

<!-- Reference KICK-NNN tasks here. The cross-repo tracker (../TASKS.md)
     is the source of truth — update it in the same PR if status changes. -->

- Closes KICK-NNN
