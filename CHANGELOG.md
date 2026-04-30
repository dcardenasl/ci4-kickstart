# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- `Makefile` with `help`, `new-project`, `test-*`, `quality-*`, `docker-*` convenience targets
- `LICENSE` (MIT)
- `CONTRIBUTING.md` with branching strategy, quality gates, and PR checklist
- Rollback trap in `new-project.sh` — automatically removes created directories if setup fails mid-way

## [1.0.0] — 2026-04-29

### Added
- Initial public release of ci4-starter-kit orchestrator
- `new-project.sh` to scaffold API + Admin project pairs from GitHub templates
- `AI_NEW_PROJECT_PROMPT.en.md` and `AI_NEW_PROJECT_PROMPT.es.md` for AI-assisted setup
- Bilingual `CLAUDE.md` (workspace-level orientation) and `README.md`

[unreleased]: https://github.com/dcardenasl/ci4-starter-kit/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/dcardenasl/ci4-starter-kit/releases/tag/v1.0.0
