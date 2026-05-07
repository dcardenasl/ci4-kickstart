# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- **KICK-001 · domain starter opcional** (2026-05-07) — `new-project.sh` ofrece clonar y configurar `ci4-domain-starter` como tercer repo (`{name}-domain`) junto al API hub y al admin. Al responder `y` al prompt nuevo:
  - clona desde `github.com/dcardenasl/ci4-domain-starter` (mismo patrón que api/admin),
  - tras `init.sh` del API, corre `php spark apps:bootstrap <code> --create-api-key` (consume API-007 en api-starter), captura `API_KEY=apk_...` y `APP_ID=N` desde stdout,
  - levanta el hub en background, hace login con el superadmin recién creado, captura el JWT,
  - exporta `CI4_DOMAIN_HUB_URL`, `CI4_DOMAIN_API_KEY`, `CI4_DOMAIN_ADMIN_TOKEN`, `CI4_DOMAIN_DB_*`, `CI4_DOMAIN_APP_CODE`,
  - corre `domain-starter/init.sh --skip-server` (no-TTY: domain init.sh respeta env vars cuando están seteadas),
  - apaga el hub.
  `cleanup_on_error` mata `HUB_PID` antes de `rm -rf` los dirs si algo falla a mitad. Tres prompts nuevos (`Incluir domain starter? (y/N)`, `Application code [{name}-domain]`, `Domain port [8090]`) con env-var overrides (`CI4_INCLUDE_DOMAIN`, `CI4_DOMAIN_APP_CODE`, `CI4_DOMAIN_PORT`). Resumen final actualizado con Terminal 4.
- `new-project.sh` — pre-clone prerequisite checks: `php >= 8.2`, `composer >= 2`, `npm`, and `mysql` client must be on PATH before any clone is attempted. Failing fast prevents the trap-cleanup-recover dance that used to happen when `init.sh` discovered a missing tool mid-bootstrap. Two new helpers: `require_php_version` and `require_composer_v2`.

### Changed
- IAM schema reference in `CLAUDE.md` updated to the consolidated `user_roles` shape (was: `app_user_memberships` + `membership_roles`). Generated projects now describe the correct schema out of the box.

## [1.0.1] — 2026-05-03

### Added
- README — Windows setup section (WSL 2 / Git Bash) with note about avoiding `/mnt/c` paths for performance

### Fixed
- `new-project.sh` — resolve `API_DIR` and `ADMIN_DIR` to absolute paths after cloning so subsequent `cd` operations work regardless of how the output directory was entered
- `new-project.sh` — silence `git add` output during the initial commit step

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

[unreleased]: https://github.com/dcardenasl/ci4-kickstart/compare/v1.0.1...HEAD
[1.0.1]: https://github.com/dcardenasl/ci4-kickstart/compare/v1.0.0...v1.0.1
[1.0.0]: https://github.com/dcardenasl/ci4-kickstart/releases/tag/v1.0.0
