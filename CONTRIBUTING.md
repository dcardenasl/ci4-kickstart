# Contributing to ci4-starter-kit

## Overview

The kit consists of three independent repositories:

| Repo | Role |
|------|------|
| [ci4-starter-kit](https://github.com/dcardenasl/ci4-starter-kit) | Orchestrator (`new-project.sh`, docs, this file) |
| [ci4-api-starter](https://github.com/dcardenasl/ci4-api-starter) | REST API template |
| [ci4-admin-starter](https://github.com/dcardenasl/ci4-admin-starter) | Admin frontend template |

Contribute to whichever repo the change belongs to.

## Development Setup

```bash
# Clone the orchestrator (includes sub-projects as git-ignored local dirs)
git clone https://github.com/dcardenasl/ci4-starter-kit.git
cd ci4-starter-kit

# Clone the sub-projects for local development
git clone https://github.com/dcardenasl/ci4-api-starter.git
git clone https://github.com/dcardenasl/ci4-admin-starter.git

# Install dependencies
cd ci4-api-starter && composer install && cd ..
cd ci4-admin-starter && composer install && npm install && cd ..
```

## Making Changes

### Branching strategy

- `main` — stable, tagged releases only
- `dev` — integration branch for next release
- Feature branches: `feat/description`, `fix/description`, `docs/description`

Always branch off `dev`, not `main`.

### Commit conventions

Follow [Conventional Commits](https://www.conventionalcommits.org/):

```
feat: add retry logic to ApiClient
fix: correct PHP version in Admin composer.json
docs: update deployment checklist
chore: upgrade PHPUnit to v11
```

## Quality Gates

Before submitting a PR, all checks must pass:

**API:**
```bash
cd ci4-api-starter
composer quality   # PHPStan + CS-Fixer + tests + swagger validation
```

**Admin:**
```bash
cd ci4-admin-starter
composer ci        # PHPStan + CS-Fixer + tests
```

**Orchestrator (`new-project.sh`):**
```bash
bash -n new-project.sh   # Syntax check
```

## Versioning

This kit uses [Semantic Versioning](https://semver.org/):

- **MAJOR** — breaking changes to the generated project structure or scripts
- **MINOR** — new features, non-breaking additions to templates
- **PATCH** — bug fixes, documentation updates, dependency bumps

Update `CHANGELOG.md` with every meaningful change before releasing.

## Pull Request Checklist

- [ ] Branch is off `dev`
- [ ] All quality checks pass
- [ ] `CHANGELOG.md` updated under `[Unreleased]`
- [ ] No sensitive data (credentials, tokens) committed
- [ ] CLAUDE.md updated if architecture or commands changed

## Reporting Issues

Open an issue in the relevant repository. Include:
- PHP and CodeIgniter 4 version
- Steps to reproduce
- Expected vs actual behaviour
- Error messages or logs (redact any credentials)
