# Contributing to ci4-kickstart

## Overview

The kit consists of three independent repositories:

| Repo | Role |
|------|------|
| [ci4-kickstart](https://github.com/dcardenasl/ci4-kickstart) | Orchestrator (`new-project.sh`, docs, this file) |
| [ci4-api-starter](https://github.com/dcardenasl/ci4-api-starter) | REST API template |
| [ci4-admin-starter](https://github.com/dcardenasl/ci4-admin-starter) | Admin frontend template |
| [ci4-api-core](https://github.com/dcardenasl/ci4-api-core) | Runtime base classes — `dcardenasl/ci4-api-core` on Packagist (`require`) |
| [ci4-api-scaffolding](https://github.com/dcardenasl/ci4-api-scaffolding) | CRUD scaffolding engine — `dcardenasl/ci4-api-scaffolding` on Packagist (`require-dev`) |

Contribute to whichever repo the change belongs to. Changes to base classes (`ApiController`, `BaseCrudService`, etc.) go in `ci4-api-core`. Changes to scaffolding templates or generators go in `ci4-api-scaffolding`.

## Development Setup

```bash
# Clone the orchestrator
git clone https://github.com/dcardenasl/ci4-kickstart.git
cd ci4-kickstart

# Clone the sub-projects alongside (for local development)
cd ..
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

## Release Process

Releases are always cut from `main`. Since `main` only accepts merges via PR, the changelog update **must happen on `dev` as the last commit before opening the PR**.

### Step-by-step

1. **On `dev`, prepare the release commit:**

   a. In `CHANGELOG.md`, rename `[Unreleased]` to `[x.y.z] — YYYY-MM-DD` and add a fresh empty `[Unreleased]` section above it. Update the footer comparison links.

   b. Create `docs/releases/{repo}-release-vx.y.z.md` with a human-readable summary of what changed and an upgrade guide.

   c. Commit:
   ```bash
   git commit -m "chore: release vx.y.z"
   ```

2. **Open the PR `dev → main`.** The PR body can reference the release notes file.

3. **After the PR is merged, tag `main`:**
   ```bash
   git checkout main
   git pull origin main
   git tag vx.y.z
   git push origin vx.y.z
   ```

> **Never tag on `dev`** — tags mark stable releases and belong on `main` after the merge.

## Pull Request Checklist

- [ ] Branch is off `dev`
- [ ] All quality checks pass
- [ ] `CHANGELOG.md` updated under `[Unreleased]` (or promoted to a version if this is a release PR)
- [ ] No sensitive data (credentials, tokens) committed
- [ ] CLAUDE.md updated if architecture or commands changed

## Reporting Issues

Open an issue in the relevant repository. Include:
- PHP and CodeIgniter 4 version
- Steps to reproduce
- Expected vs actual behaviour
- Error messages or logs (redact any credentials)
