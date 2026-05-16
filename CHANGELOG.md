# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.1.0] — 2026-05-16

### Added
- **TMPL-001..005 · Template system for N domain apps** (2026-05-16) — `new-project.sh` now scaffolds 0..N domain apps in a single run, with optional pre-built templates selected from `templates.json`. New surface:
  - `templates.json` at the repo root — catalog of published domain templates (`{slug, repo, name, description, keywords[]}` per entry). Ships empty; entries are added via PR when a template repo is published.
  - `docs/TEMPLATE_CONTRACT.md` — contract for `template.json` (per-repo) and `templates.json` (catalog). Documents required/optional fields, the integration flow with `new-project.sh`, the matching contract for the `ci4-new-project` skill, and the pre-publish validation checklist.
  - `new-project.sh` prompt loop — `¿Agregar un domain app?` repeats until the user answers `N`. Each iteration asks for a name, a template (menu shows `0) vanilla` plus every catalog entry) and a port. Backwards compatible: `CI4_INCLUDE_DOMAIN=y` + `CI4_DOMAIN_APP_CODE` + `CI4_DOMAIN_PORT` still create a single vanilla domain.
  - `CI4_DOMAINS` env var — CSV of `name:template_slug:port` tuples for non-interactive runs (e.g. `CI4_DOMAINS="shop:vanilla:8090,blog:vanilla:8091"`).
  - `apply_template()` — after each domain clone, if the repo carries `template.json`, validates the contract (required fields, dot-separated permissions, `admin_modules[].service ∈ {hub, domain}`) and generates the declared `admin_modules[]` against `ci4-admin-starter/bin/make-module.sh`. Permissions are registered by the domain's own `domain:sync-permissions` during `init.sh`.
  - Auto-enable of the BFF — when any selected template declares `requires_bff: true`, `INCLUDE_BFF` is forced regardless of the prompt answer.
  - Summary section — lists every registered domain with its template, port and app code; numbers Terminal entries dynamically. Warns when more than one domain is registered that the BFF only wires the first one.
  - CLAUDE.md — new "Building a domain template" section covering anatomy, the publishing flow against `templates.json`, and the compatibility checklist before a catalog PR.
  - AI prompts (`AI_NEW_PROJECT_PROMPT.en.md` and `.es.md`) — updated with the new prompt loop, the template-matching guidance against `keywords[]`, and the multi-domain BFF wiring note.
- **BFF-006 · optional BFF starter** (2026-05-16) — `new-project.sh` offers to clone and configure `ci4-bff-starter` as a third/fourth repo (`{name}-bff/`) alongside the API hub, the admin and the optional domain. When the new prompt is answered `y`:
  - clones from `github.com/dcardenasl/ci4-bff-starter` (same pattern as the other starters),
  - exports `BFF_HUB_URL=http://localhost:8080` (the just-bootstrapped API), `BFF_DOMAIN_URL=http://localhost:{DOMAIN_PORT}` (if the domain was included; empty otherwise), `BFF_ALLOWED_ORIGINS` (default `http://localhost:5173,http://localhost:3000`; override with `CI4_BFF_ALLOWED_ORIGINS`) and `BFF_PORT` (default `8088`),
  - runs `bff-starter/init.sh --skip-server` non-TTY (env-var driven, no prompts) — **no DB, no hub bootstrap**, since the BFF is stateless and forwards the client's `Authorization` header upstream rather than validating it.
  Two new prompts (`Incluir BFF starter? (y/N)`, `BFF port [8088]`) with env-var overrides (`CI4_INCLUDE_BFF`, `CI4_BFF_PORT`, `CI4_BFF_ALLOWED_ORIGINS`). `cleanup_on_error` now also removes `{name}-bff/` on partial-run failures. The final summary includes a Terminal 5 entry when the BFF is included.
- **BFF-007 · documentation parity** (2026-05-16) — `CLAUDE.md`, `README.md`, `AI_NEW_PROJECT_PROMPT.en.md` and `AI_NEW_PROJECT_PROMPT.es.md` updated to document the BFF role (stateless gateway over hub + domain for SPA / mobile clients), its forward-only auth model and the orchestration delegated to its `init.sh`. The kit table now lists `ci4-bff-starter` on port `8088`.
- **KICK-001 · optional domain starter** (2026-05-07) — `new-project.sh` offers to clone and configure `ci4-domain-starter` as a third repo (`{name}-domain/`) alongside the API hub and the admin. When the new prompt is answered `y`:
  - clones from `github.com/dcardenasl/ci4-domain-starter` (same pattern as api/admin),
  - after the API's `init.sh`, runs `php spark apps:bootstrap <code> --create-api-key` (consuming API-007 in api-starter), captures `API_KEY=apk_...` and `APP_ID=N` from stdout,
  - boots the hub in background, logs in with the freshly-bootstrapped superadmin, captures the JWT,
  - exports `CI4_DOMAIN_HUB_URL`, `CI4_DOMAIN_API_KEY`, `CI4_DOMAIN_ADMIN_TOKEN`, `CI4_DOMAIN_DB_*`, `CI4_DOMAIN_APP_CODE`,
  - runs `domain-starter/init.sh --skip-server` (non-TTY: domain `init.sh` honours env vars when set),
  - stops the hub.
  `cleanup_on_error` kills `HUB_PID` before `rm -rf`-ing the dirs if any step fails. Three new prompts (`Incluir domain starter? (y/N)`, `Application code [{name}-domain]`, `Domain port [8090]`) with env-var overrides (`CI4_INCLUDE_DOMAIN`, `CI4_DOMAIN_APP_CODE`, `CI4_DOMAIN_PORT`). The final summary now includes Terminal 4.
- **CORE-007 · two-package model documented** (2026-05-10) — `CLAUDE.md`, `README.md`, `CONTRIBUTING.md` and both AI prompts updated to reflect that `ci4-api-starter` depends on two separate Packagist packages: `dcardenasl/ci4-api-core ^0.4` (`require` — runtime base classes) and `dcardenasl/ci4-api-scaffolding ^0.2` (`require-dev` — `make:crud` engine + `vendor/bin/make-crud.sh`). All references to the retired `ci4-api-crud-maker` removed. A scaffolding section was added to the AI prompts with instructions for `vendor/bin/make-crud.sh`.
- **`new-project.sh` prerequisite checks** — `php >= 8.2`, `composer >= 2`, `npm`, and a `mysql` client must be on `PATH` before any clone is attempted. Failing fast prevents the trap-cleanup-recover dance that used to happen when `init.sh` discovered a missing tool mid-bootstrap. Two new helpers: `require_php_version` and `require_composer_v2`.
- **`--reset-db` flag** — `new-project.sh --reset-db` drops and recreates the API and admin databases before setup. Lets developers recover cleanly from a partial run without manual `DROP DATABASE` surgery; the flag is documented in the script's `--help` output.
- **`--yes` / `-y` flag** — non-interactive mode for CI and scripted runs. Consumes env-var defaults (`CI4_PROJECT_NAME`, `CI4_OUTPUT_DIR`, `CI4_INCLUDE_DOMAIN`, `CI4_DOMAIN_APP_CODE`, `CI4_DOMAIN_PORT`) without prompting.
- **`.github/pull_request_template.md`** — PR template tailored for bash-script changes: checklist items for shellcheck, `--help` output accuracy, idempotency checks, and the prerequisite-validation path.
- **GitHub Actions workflows** — `.github/workflows/release.yml` (extracts the matching CHANGELOG section on `v*.*.*` tag push and creates a GitHub Release; soft-fails on re-tag) and `.github/workflows/e2e.yml` (runs `new-project.sh --yes --reset-db` against a real MySQL container on push + PR + weekly cron to validate the full bootstrap flow end-to-end).
- **README — Windows setup section** (WSL 2 / Git Bash) with the note about avoiding `/mnt/c` paths for performance.

### Changed
- **`new-project.sh` cleanup** (TMPL-003) — the failure trap now walks the `DOMAIN_DIRS` array instead of a single `DOMAIN_DIR`. Guarded against bash 3.2 `set -u` empty-array expansion.
- **`new-project.sh` hub bootstrap** (TMPL-003) — `apps:bootstrap --create-api-key` now runs once per registered domain (instead of zero or one) and the hub is brought up only once for the whole batch.
- **IAM schema reference in `CLAUDE.md` updated** to the consolidated `user_roles` shape (was: `app_user_memberships` + `membership_roles`). Generated projects now describe the correct schema out of the box, matching the migrations shipped by `ci4-api-starter` v2.0.0.

### Fixed
- **`new-project.sh`** — `API_DIR` and `ADMIN_DIR` resolved to absolute paths after cloning so subsequent `cd` operations work regardless of how the output directory was entered.
- **`new-project.sh`** — silenced `git add` output during the initial commit step.

## [1.0.0] — 2026-05-03

### Added
- `new-project.sh` — scaffolds a new API + Admin project pair by cloning from GitHub, initializing git repos, and delegating setup to `init.sh` (API) and `install.sh` (Admin)
- Rollback trap in `new-project.sh` — removes created directories automatically if setup fails mid-way
- `Makefile` with `help` and `new-project` convenience targets
- `LICENSE` (MIT)
- `CONTRIBUTING.md` — branching strategy, quality gates, PR checklist, and release process
- `AI_NEW_PROJECT_PROMPT.en.md` and `AI_NEW_PROJECT_PROMPT.es.md` — AI prompt templates for automated project setup
- `CLAUDE.md` — guidance for AI-assisted development in this repo

### Notes
- Project released under the name **ci4-kickstart** (renamed from the working name `ci4-starter-kit` during development)
- Sub-projects (`ci4-api-starter`, `ci4-admin-starter`) live in their own independent GitHub repositories and are not bundled here

[unreleased]: https://github.com/dcardenasl/ci4-kickstart/compare/v1.1.0...HEAD
[1.1.0]: https://github.com/dcardenasl/ci4-kickstart/compare/v1.0.0...v1.1.0
[1.0.0]: https://github.com/dcardenasl/ci4-kickstart/releases/tag/v1.0.0
