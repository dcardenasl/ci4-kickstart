# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Changed
- Project renamed from `ci4-starter-kit` to `ci4-kickstart` — GitHub repo, remote URL, all docs, and banner updated
- Sub-projects (`ci4-api-starter`, `ci4-admin-starter`) removed from this repo's directory; they live in their own repos as independent clones
- `Makefile` simplified: removed `test-*`, `quality-*`, and `docker-*` targets that required sub-projects to be cloned locally
- `.gitignore` cleaned up: removed now-irrelevant `ci4-api-starter/` and `ci4-admin-starter/` entries
- `CLAUDE.md` updated to reflect the orchestrator-only role of this repo

## [1.1.0] — 2026-04-30

### Added
- `Makefile` with `help`, `new-project`, `test-*`, `quality-*`, and `docker-*` convenience targets
- `LICENSE` (MIT)
- `CONTRIBUTING.md` with branching strategy, quality gates, PR checklist, and release process
- Rollback trap in `new-project.sh` — automatically removes created directories if setup fails mid-way

### Changed
- `new-project.sh` updated to reference the external GitHub repositories instead of local copies
- Kit-level documentation aligned on `bin/make-crud.sh` as the canonical scaffolding command
- `docs/plans` and `.claude` directories added to `.gitignore`

## [1.0.0] — 2026-04-29

### Added
- Initial public release of the ci4-starter-kit orchestrator
- `new-project.sh` to scaffold a fresh API + Admin project pair from the GitHub templates
- `AI_NEW_PROJECT_PROMPT.en.md` and `AI_NEW_PROJECT_PROMPT.es.md` for AI-assisted project setup
- Bilingual `CLAUDE.md` (workspace-level orientation) and `README.md`

[unreleased]: https://github.com/dcardenasl/ci4-kickstart/compare/v1.1.0...HEAD
[1.1.0]: https://github.com/dcardenasl/ci4-kickstart/compare/v1.0.0...v1.1.0
[1.0.0]: https://github.com/dcardenasl/ci4-kickstart/releases/tag/v1.0.0
