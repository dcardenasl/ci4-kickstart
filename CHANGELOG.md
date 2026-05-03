# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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
