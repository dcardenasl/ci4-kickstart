# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## ⚡ Workflow — read this first

**Before touching any code, read `TASKS.md` in this directory.**

1. Take the first task from `## 🔴 En progreso` (if any) or `## 🟡 Próximo`
2. If taking from Próximo: move it to `## 🔴 En progreso`
3. Work exclusively on that task — if anything is unclear, ask before implementing
4. When done: move it to `## ✅ Completadas` with one line of notes (what you did and why)
5. Never work on tasks not defined in TASKS.md without explicit confirmation

For cross-repo context (current milestone, blocked tasks), read `../TASKS.md`.

> **Note (audit B11.5, 2026-05-07):** This is the canonical orchestrator-level doc. A lighter `CLAUDE.md` sits at the workspace root (`../CLAUDE.md`) but it's a navigational stub that points readers here for the long-form. Sub-repo-specific `CLAUDE.md` files (`ci4-api-starter`, `ci4-admin-starter`, `ci4-api-core`, `ci4-api-scaffolding`) own their own architecture / patterns / commands.

## Repository Overview

**ci4-kickstart** is the orchestrator for a complete, production-ready backend + frontend system for administrative applications. It contains `new-project.sh` and documentation to scaffold up to three independent CodeIgniter 4 projects:

1. **[ci4-api-starter](https://github.com/dcardenasl/ci4-api-starter)** — REST API backend (port 8080) — the **hub**
   - DTO-first, fully scaffoldable CRUD operations
   - JWT authentication with **granular RBAC** (applications × permissions × roles × memberships)
   - Advanced query filtering, audit trails, and metrics
   - Full OpenAPI documentation with auto-generation
   - Powered by two Packagist packages: [`dcardenasl/ci4-api-core`](https://packagist.org/packages/dcardenasl/ci4-api-core) (runtime: base classes, `require`) and [`dcardenasl/ci4-api-scaffolding`](https://packagist.org/packages/dcardenasl/ci4-api-scaffolding) (dev: `make:crud` engine, `require-dev`)

2. **[ci4-admin-starter](https://github.com/dcardenasl/ci4-admin-starter)** — Server-rendered administrative frontend (port 8082)
   - Consumes the REST API from ci4-api-starter
   - Server-side PHP views with Tailwind CSS + Alpine.js
   - Fully implemented modules: auth, users, files, audit, API keys, metrics, **IAM (roles, permissions, memberships)**
   - Session-based JWT token storage; `session('user.permissions')` drives UI gating via `has_permission(string $code)`

3. **[ci4-domain-starter](https://github.com/dcardenasl/ci4-domain-starter)** *(optional, KICK-001)* — Domain app template (port 8090)
   - Owns its own business-logic tables; **delegates auth and IAM to the hub** via `POST /auth/introspect`
   - Includes `Hub` config, `HubClient`, `DomainAuthFilter`, `DomainPermissions` catalog, and the `domain:sync-permissions` command
   - When opted in via `Incluir domain starter? (y/N)` (or `CI4_INCLUDE_DOMAIN=y`), `new-project.sh` orchestrates end-to-end: registers the application in the hub via `apps:bootstrap --create-api-key`, captures the X-App-Key, logs in to capture a superadmin JWT, runs domain `init.sh --skip-server` non-TTY, and stops the hub

4. **[ci4-bff-starter](https://github.com/dcardenasl/ci4-bff-starter)** *(optional, BFF-006)* — Backend-for-Frontend template (port 8088)
   - **Stateless gateway** over the hub (and optionally a domain app) for decoupled clients (SPA, mobile)
   - No database, no JWT validation: it forwards the client's `Authorization` header upstream and lets the hub/domain validate it
   - Includes `Config\Bff` (`hubUrl`, `domainUrl`, `allowedOrigins` parsed from `BFF_ALLOWED_ORIGINS`), `HubClient` (service-token cache, optional), `Config\Cors` reading the BFF allow-list
   - When opted in via `Incluir BFF starter? (y/N)` (or `CI4_INCLUDE_BFF=y`), `new-project.sh` runs BFF `init.sh --skip-server` with `BFF_HUB_URL` (pointing at the API just created), `BFF_DOMAIN_URL` (the domain if included) and `BFF_ALLOWED_ORIGINS` pre-populated — no hub bootstrap, no DB

**Architecture flow:**
```
Browser/Admin → CI4 Admin Starter (8082) → CI4 API Starter (8080) → Database
                                                  ↑ JWT introspect
                                                  └─ CI4 Domain Starter (8090) → its own DB

SPA / mobile  → CI4 BFF Starter (8088) ──▶ CI4 API Starter (8080)  [forwards Authorization]
                                       └─▶ CI4 Domain Starter (8090) [forwards Authorization]
```

## What lives in this repo

This repo is the **orchestrator only**. It does not contain the API or admin source code — those live in their own repos.

```
ci4-kickstart/
├── new-project.sh                # Main script: clones + configures a new project pair
├── Makefile                      # Convenience target: make new-project
├── AI_NEW_PROJECT_PROMPT.en.md   # AI prompt template (English) for automated setup
├── AI_NEW_PROJECT_PROMPT.es.md   # AI prompt template (Spanish) for automated setup
├── CLAUDE.md                     # This file
├── CONTRIBUTING.md               # Branching, quality gates, release process
├── CHANGELOG.md                  # Release history
├── LICENSE                       # MIT
└── README.md                     # Public-facing documentation
```

## Generating a New Project from This Kit

Use `new-project.sh` at the repo root to scaffold two independent repos for a new project:

```bash
bash new-project.sh
```

The script asks for a project name, output directory, and whether to include a domain starter and/or a BFF starter, then:
1. Clones `ci4-api-starter` → `{name}-api/` from GitHub (shallow clone, no git history)
2. Clones `ci4-admin-starter` → `{name}-admin/` from GitHub (shallow clone, no git history)
3. Optionally clones `ci4-domain-starter` → `{name}-domain/` from GitHub
4. Optionally clones `ci4-bff-starter` → `{name}-bff/` from GitHub
5. Initializes a fresh git repo in each with an initial commit
6. Delegates to `{name}-api/init.sh` — installs deps, configures `.env`, creates DB, runs migrations, creates superadmin
7. **If domain included:** registers the application in the hub via `php spark apps:bootstrap <code> --create-api-key`, starts the hub in background, logs in with the freshly-created superadmin to capture a JWT, exports `CI4_DOMAIN_*` env vars, runs `{name}-domain/init.sh --skip-server`, then stops the hub
8. **If BFF included:** exports `BFF_HUB_URL=http://localhost:8080`, `BFF_DOMAIN_URL=http://localhost:{DOMAIN_PORT}` (if domain), `BFF_ALLOWED_ORIGINS` and `BFF_PORT`, then runs `{name}-bff/init.sh --skip-server` (no hub bootstrap — BFF is stateless and forward-only)
9. Delegates to `{name}-admin/install.sh` — replaces template references, configures `.env`, installs Composer deps

After the script finishes, orient yourself in the generated project by reading:
- `{name}-api/CLAUDE.md` — API architecture and patterns
- `{name}-admin/CLAUDE.md` — Admin architecture and ApiClient

**Do not modify the template repos directly** to customize a new project — always work in the generated copies.

## Essential Commands

```bash
# Scaffold a new project (interactive)
bash new-project.sh
# or
make new-project
```

For commands to run **inside the generated/cloned sub-projects**, see their own CLAUDE.md files:
- `ci4-api-starter/CLAUDE.md` — `php spark serve`, `make:crud`, `migrate`, `swagger:generate`, tests
- `ci4-admin-starter/CLAUDE.md` — `php spark serve --port 8082`, `npm run dev:css`, tests

## System Architecture

### Data Flow

```
1. User Action
   ↓
2. Admin UI (Blade view, Alpine.js interaction)
   ↓
3. AdminController receives request
   ↓
4. Service layer + ApiClient make HTTP call
   ↓
5. CI4 API (REST endpoint with JWT auth)
   ↓
6. API Service + Model layer
   ↓
7. Database query
```

### Authentication Flow

1. **Login** → Admin frontend `POST /login` → API returns `access_token` + `refresh_token` + `user` (including `permissions[]`)
2. **Token Storage** → PHP session only (server-side), never exposed to browser
3. **API Calls** → `ApiClient` injects `Authorization: Bearer {token}` header
4. **Token Refresh** → On 401, `ApiClient` automatically calls `POST /api/v1/auth/refresh` with `refresh_token`
5. **Session End** → Token destruction or `AuthFilter` redirect on invalid refresh

**Important:** Tokens must NEVER be stored in localStorage or exposed to JavaScript. All token handling is server-side PHP.

### Authorization (RBAC)

The kit ships a granular RBAC model: `applications × permissions (× role_permissions) × roles × user_roles × users`. Permissions belong to an application (cross-app scoping is preserved through `permissions.application_id`); roles are global. The single seeded application is `self` (`id=1`). Permission codes use a **dot separator** (`.`), not a colon (e.g. `iam.admin-access`, `users.write`). Reason: CI4's filter parser splits on `:` for arguments, so `permission:users:write` is silently truncated.

> **Schema note (2026-05-03 refactor):** the legacy pair `app_user_memberships` + `membership_roles` was collapsed into a single `user_roles` join table. Migrations `2026-05-03-100003` to `100007` perform the schema change; older planning docs under `docs/plans/` are historical.

- **API side**: routes gate via the `permission:<code>` filter (e.g. `permission:iam.admin-access`). The JWT carries a `scope` claim with the user's effective permission codes; `EffectivePermissionsResolver` derives them from `user_roles → roles → role_permissions → permissions`.
- **Admin side**: `session('user.permissions')` is populated at login from the API's `LoginResponse`. UI gating uses `has_permission(string $code)` (in `app/Helpers/auth_helper.php`).
- **First user**: `php spark users:bootstrap-superadmin` creates the user and attaches the `superadmin` role via a `user_roles` row. It requires `RbacBootstrapSeeder` to have run first.

## Configuration Essentials

**API Server** (`.env` in `{name}-api/`):
```dotenv
CI_ENVIRONMENT = development
database.default.hostname = localhost
database.default.database = ci4_api
database.default.username = root
database.default.password = password
JWT_SECRET_KEY = (generate with `openssl rand -base64 64`)
encryption.key = hex2bin:(generate with `openssl rand -hex 32`)
```

**Admin Server** (`.env` in `{name}-admin/`):
```dotenv
CI_ENVIRONMENT = development
app.baseURL = 'http://localhost:8082/'
apiClient.baseUrl = 'http://localhost:8080'
apiClient.apiPrefix = '/api/v1'
# Optional: App key for elevated rate limiting (600 vs 60 req/min)
# apiClient.appKey = apk_xxxxxxxxxxxxxxxxxxxxxxxxxxxx
```

### Ports and Services

| Service | Port | URL |
|---------|------|-----|
| API Server (hub) | 8080 | http://localhost:8080 |
| Admin Server | 8082 | http://localhost:8082 |
| BFF Server *(optional)* | 8088 | http://localhost:8088 |
| Domain Server *(optional)* | 8090 | http://localhost:8090 |
| Database | 3306 | localhost (MySQL) |
| Tailwind Watcher | — | Runs in Terminal 3 |

## Security Checklist

- ✅ **JWT Secret** in `.env`, never in code
- ✅ **Encryption Key** in `.env`, never in code
- ✅ **API Key** (`apiClient.appKey`) in `.env`, never in frontend code
- ✅ Tokens stored **only in PHP sessions**, never in localStorage
- ✅ **CSRF** protection enabled by default on both projects
- ✅ Admin routes use **both `auth` and `admin` filters**
- ✅ File uploads **validated by size** before API submission
- ✅ `.env` files **never committed** (use `.env.example`)

## Troubleshooting

### "Connection refused" on API calls
- Verify API server is running: `php spark serve`
- Check `.env` in admin: `apiClient.baseUrl = 'http://localhost:8080'`

### CSS not loading in admin
- Ensure Tailwind watcher is running: `npm run dev:css`
- Check `npm` dependencies installed: `npm install`

### API returns 401 on every request
- Check `apiClient.appKey` in `.env` — if wrong, omit it entirely
- Verify JWT secret matches between API and admin `.env`

### Database migration errors
- Ensure database exists and credentials are correct in `.env`
- Run: `php spark migrate`

### `bootstrap-superadmin` reports "Superadmin role not found"
- Run the RBAC seeder first: `php spark db:seed RbacBootstrapSeeder`
- The seeder is idempotent. `init.sh` chains `migrate → db:seed RbacBootstrapSeeder → bootstrap-superadmin` automatically when run via `new-project.sh`.

### Sidebar shows "Identity & Access" but routes 403
- The user lacks the `iam.admin-access` permission. Assign it by attaching a role that includes it (e.g. `admin` or `superadmin`) to the user's membership for the `self` application.

### Admin login succeeds but every admin route redirects to /dashboard
- The session is missing `permissions[]`. Confirm the API's `/auth/login` response includes `user.permissions: string[]` and that the admin's session-persisting code stores `$data['user']` as-is.

## Getting Help

- **API questions?** See [ci4-api-starter CLAUDE.md](https://github.com/dcardenasl/ci4-api-starter) and `vendor/dcardenasl/ci4-api-core/docs/ARCHITECTURE_CONTRACT.md` (authoritative architecture contract)
- **Admin questions?** See [ci4-admin-starter CLAUDE.md](https://github.com/dcardenasl/ci4-admin-starter) and its `docs/ARCHITECTURE.md`
- **General CodeIgniter?** Check [CodeIgniter 4 documentation](https://codeigniter.com/user_guide/)

---

**Last Updated:** 2026-05-03
**Status:** Production Ready ✅
