# ci4-kickstart v1.0.0 — Release Notes

**Date:** 2026-05-03
**Type:** Initial public release

## Summary

First stable release of **ci4-kickstart**, an orchestrator that scaffolds a complete API + Admin project pair built on CodeIgniter 4.

Running `bash new-project.sh` (or `make new-project`) clones the two template repositories, initializes independent git repos for each, and walks through full configuration interactively — database, JWT keys, superadmin, admin port.

## What's included

### `new-project.sh`
The main script. Given a project name and output directory it:
1. Clones [`ci4-api-starter`](https://github.com/dcardenasl/ci4-api-starter) → `{name}-api/`
2. Clones [`ci4-admin-starter`](https://github.com/dcardenasl/ci4-admin-starter) → `{name}-admin/`
3. Initializes a fresh git repo in each with an initial commit
4. Delegates to `{name}-api/init.sh` — Composer install, `.env`, DB creation, migrations, RBAC seeder, superadmin
5. Delegates to `{name}-admin/install.sh` — template substitution, `.env`, Composer install
6. Prints the three commands to start the dev environment

Includes a **rollback trap**: if any step fails, directories created by the script are removed automatically.

### `Makefile`
- `make help` — lists available targets
- `make new-project` — runs `new-project.sh`

### `AI_NEW_PROJECT_PROMPT.en.md` / `AI_NEW_PROJECT_PROMPT.es.md`
Prompt templates to hand to an AI assistant (Claude Code or similar) for fully automated project creation, including parameter gathering and verification.

### `CONTRIBUTING.md`
Documents the branching strategy (`main` / `dev` / feature branches), commit conventions, quality gates per sub-project, and the release process.

## Quick start

```bash
git clone https://github.com/dcardenasl/ci4-kickstart.git
cd ci4-kickstart
bash new-project.sh
```

## Prerequisites

- `git`
- `php` 8.2+
- `composer`
- `node` + `npm`
- MySQL (local or Docker)
