# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

**ci4-starter-kit** is a complete, production-ready backend + frontend system for administrative applications. It consists of two independent CodeIgniter 4 projects:

1. **`ci4-api-starter`** — REST API backend (port 8080)
   - DTO-first, fully scaffoldable CRUD operations
   - JWT authentication, role-based access control
   - Advanced query filtering, audit trails, and metrics
   - Full OpenAPI documentation with auto-generation

2. **`ci4-admin-starter`** — Server-rendered administrative frontend (port 8082)
   - Consumes the REST API from ci4-api-starter
   - Server-side PHP views with Tailwind CSS + Alpine.js
   - Fully implemented modules: auth, users, files, audit, API keys, metrics
   - Session-based JWT token storage

**Architecture flow:**
```
Browser → CI4 Admin Starter (8082) → CI4 API Starter (8080) → Database
```

## Generating a New Project from This Kit

Use `new-project.sh` at the kit root to scaffold two independent repos for a new project:

```bash
bash new-project.sh
```

The script asks for a project name and output directory, then:
1. Copies `ci4-api-starter/` → `{name}-api/` and `ci4-admin-starter/` → `{name}-admin/` (excluding `.git`, `vendor`, `node_modules`)
2. Initializes a fresh git repo in each with an initial commit
3. Delegates to `{name}-api/init.sh` — installs deps, configures `.env`, creates DB, runs migrations, creates superadmin
4. Delegates to `{name}-admin/install.sh` — replaces template references, configures `.env`, installs Composer deps

After the script finishes, orient yourself in the generated project by reading:
- `{name}-api/CLAUDE.md` — API architecture and patterns
- `{name}-admin/CLAUDE.md` — Admin architecture and ApiClient

**Do not modify the kit sub-projects directly** to customize a new project — always work in the generated copies.

## Quick Start

### Setup Both Projects

1. **API Server** (Terminal 1 — start first)
   ```bash
   cd ci4-api-starter
   composer install
   cp .env.example .env
   # Edit .env: Set DB credentials, JWT_SECRET_KEY
   php spark migrate
   php spark serve                    # Runs on http://localhost:8080
   ```

2. **Admin Frontend** (Terminal 2)
   ```bash
   cd ci4-admin-starter
   bash install.sh                    # Interactive setup
   # OR manually:
   # composer install && npm install && cp env .env
   php spark serve --port 8082        # Runs on http://localhost:8082
   npm run dev:css                    # Terminal 3 (Tailwind watcher)
   ```

3. **Verify Setup**
   - API at http://localhost:8080 (check `GET /health`)
   - Admin at http://localhost:8082
   - Database migrations completed

### Essential Commands

**API Project** (`ci4-api-starter`):
```bash
php spark serve                                                         # Start API server (port 8080)
bash bin/make-crud.sh {Name} {Domain} '{field1:type,field2:type}' yes   # Scaffold new CRUD (recommended)
php spark make:crud {Name} --domain {Domain}                            # Alternative: interactive scaffold
php spark module:check {Name} --domain {Domain}                         # Validate scaffolded wiring
php spark migrate                                                       # Run database migrations
php spark swagger:generate                                              # Generate OpenAPI documentation
composer quality                                                        # Run all quality checks
vendor/bin/phpunit                                                      # Run tests
```

**Admin Project** (`ci4-admin-starter`):
```bash
php spark serve --port 8082         # Start admin server
npm run dev:css                     # Tailwind CSS watcher
composer quality                    # Run all quality checks
vendor/bin/phpunit                  # Run tests
```

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

### Key Files

**API Starter** — Architecture controlled by DTOs and the scaffolding engine:
- `app/DTO/Request/` — Request validation schemas
- `app/DTO/Response/` — Response contracts
- `app/Services/` — Business logic (DTO-in, DTO-out)
- `app/Controllers/Api/V1/` — HTTP layer (thin, uses `handleRequest()`)
- `app/Models/` — Eloquent models (data layer)
- `app/Database/Migrations/` — Schema definitions
- `docs/template/ARCHITECTURE_CONTRACT.md` — Authority on patterns

**Admin Starter** — Server-rendered frontend with modular controllers:
- `app/Modules/{ModuleName}/Controllers/` — HTTP handlers (extend BaseWebController)
- `app/Modules/{ModuleName}/Services/` — API communication (extend BaseApiService)
- `app/Libraries/ApiClient.php` — Central HTTP client with automatic token refresh
- `app/Views/{module_name}/` — Server-rendered Blade views
- `app/Filters/` — AuthFilter, AdminFilter, LocaleFilter
- `app/Config/Services.php` — Shared service factory

### Authentication Flow

1. **Login** → Admin frontend `POST /login` → API returns `access_token` + `refresh_token`
2. **Token Storage** → PHP session only (server-side), never exposed to browser
3. **API Calls** → `ApiClient` injects `Authorization: Bearer {token}` header
4. **Token Refresh** → On 401, `ApiClient` automatically calls `POST /api/v1/auth/refresh` with `refresh_token`
5. **Session End** → Token destruction or `AuthFilter` redirect on invalid refresh

**Important:** Tokens must NEVER be stored in localStorage or exposed to JavaScript. All token handling is server-side PHP.

## Project-Specific Guidance

### Working on the API (`ci4-api-starter`)

Read `ci4-api-starter/CLAUDE.md` for:
- Detailed command reference
- DTO-first implementation guidelines
- Service layer pattern
- Testing strategy
- CRUD scaffolding examples

**Authority documents:**
- `docs/template/ARCHITECTURE_CONTRACT.md` — Mandatory design patterns
- `docs/template/CRUD_FROM_ZERO.md` — Step-by-step scaffolding
- `docs/tech/openapi.md` — Auto-generated documentation

**Don't do:**
- ❌ Manual validation with `InputValidationService` (legacy)
- ❌ Return `ApiResponse` from services (use DTOs instead)
- ❌ Pass raw arrays to services (use Request DTOs)
- ❌ Manually create DTO files (use `make:crud` scaffolding)

### Working on the Admin (`ci4-admin-starter`)

Read `ci4-admin-starter/CLAUDE.md` for:
- Detailed command reference
- Service layer architecture
- Form validation patterns
- View organization
- Testing patterns

**Authority documents:**
- `docs/ARCHITECTURE.md` — ApiClient and security patterns
- `docs/SERVICES.md` — Service layer and FormRequest validation
- `docs/FRONTEND.md` — UI/UX design system

**Don't do:**
- ❌ Store tokens in localStorage (use PHP sessions)
- ❌ Hardcode API URLs in frontend code
- ❌ Bypass CSRF protection (`csrf` filter enabled by default)
- ❌ Configure invalid `apiClient.appKey` (omit rather than use wrong value)

## Configuration Essentials

### Environment Setup

**API Server** (`.env` in `ci4-api-starter/`):
```dotenv
CI_ENVIRONMENT = development
database.default.hostname = localhost
database.default.database = ci4_api
database.default.username = root
database.default.password = password
JWT_SECRET_KEY = (generate with `openssl rand -base64 64`)
encryption.key = hex2bin:(generate with `openssl rand -hex 32`)
```

**Admin Server** (`.env` in `ci4-admin-starter/`):
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
| API Server | 8080 | http://localhost:8080 |
| Admin Server | 8082 | http://localhost:8082 |
| Database | 3306 | localhost (MySQL) |
| Tailwind Watcher | — | Runs in Terminal 3 |

All ports are configurable. See individual project `.env` files.

## Development Workflow

### Adding a New Feature to the API

**Always use the scaffolding engine — it generates 100% of the boilerplate correctly:**

```bash
cd ci4-api-starter

# Scaffold a new CRUD module (recommended: the shell-safe wrapper)
# Generates DTOs, Services, Controllers, Migrations, OpenAPI docs, routes, i18n, tests.
bash bin/make-crud.sh Product Catalog \
  'name:string:required|searchable,price:decimal:required|filterable' \
  yes

# Alternative (interactive / TTY-only): php spark make:crud Product --domain Catalog

# Validate wiring
php spark module:check Product --domain Catalog

# Review the generated migration
cat app/Database/Migrations/[timestamp]_CreateProductsTable.php

# Apply the migration
php spark migrate

# Restart the server so new route files are detected
pkill -f 'spark serve'; php spark serve --port 8080 &

# Generate OpenAPI documentation
php spark swagger:generate
```

The scaffold is complete and production-ready. Modify only if domain logic requires custom behavior beyond standard CRUD.

**Never manually create DTO files** — the scaffolding engine ensures consistency and completeness.

**Never invoke `php spark make:crud` directly from non-TTY contexts (CI, Claude Code, scripts)** — shell expansion can drop pipes in `--fields`, and the engine silently falls back to interactive mode that never responds. Use `bin/make-crud.sh` instead.

### Adding a New Feature to the Admin

1. **API already exists** — Use the API first; admin is always a consumer

2. **Create a new module** in `ci4-admin-starter/app/Modules/{ModuleName}/`:
   ```
   Controllers/
   Services/
   Requests/
   Language/
   ```

3. **Update routes** in `app/Modules/{ModuleName}/Config/Routes.php`

4. **Create views** in `app/Views/{module_name}/`

5. **Test the flow** — Both controllers and integration paths

## Quality & Testing

### Running Tests

**API Tests:**
```bash
cd ci4-api-starter
vendor/bin/phpunit tests/Unit              # Fast, no DB
vendor/bin/phpunit tests/Feature           # HTTP tests
vendor/bin/phpunit                         # All tests
```

**Admin Tests:**
```bash
cd ci4-admin-starter
vendor/bin/phpunit tests/Unit              # Libraries, helpers, services
vendor/bin/phpunit tests/Feature           # Controllers, workflows
vendor/bin/phpunit                         # All tests
```

### Code Quality

**API:**
```bash
cd ci4-api-starter
composer quality                # PHPStan + PHPUnit + PHP CS Fixer check
composer cs-fix                 # Auto-fix style
```

**Admin:**
```bash
cd ci4-admin-starter
composer quality                # PHPStan + PHPUnit + PHP CS Fixer check
composer format                 # Auto-fix style
```

## Security Checklist

- ✅ **JWT Secret** in `.env`, never in code
- ✅ **Encryption Key** in `.env`, never in code
- ✅ **API Key** (`apiClient.appKey`) in `.env`, never in frontend code
- ✅ Tokens stored **only in PHP sessions**, never in localStorage
- ✅ **CSRF** protection enabled by default on both projects
- ✅ Admin routes use **both `auth` and `admin` filters**
- ✅ File uploads **validated by size** before API submission
- ✅ `.env` files **never committed** (use `.env.example`)

For production, see deployment guides in each project:
- `ci4-api-starter/DEPLOYMENT.md`
- `ci4-admin-starter/docs/DEPLOYMENT.md`

## Troubleshooting

### "Connection refused" on API calls
- Verify API server is running: `cd ci4-api-starter && php spark serve`
- Check `.env` in admin: `apiClient.baseUrl = 'http://localhost:8080'`
- Check firewall/port 8080 availability

### CSS not loading in admin
- Ensure Tailwind watcher is running: `npm run dev:css` (Terminal 3)
- Check `npm` dependencies installed: `npm install`

### API returns 401 on every request
- Check `apiClient.appKey` in `.env` — if wrong, omit it entirely
- Verify JWT secret matches between API and admin `.env`

### Database migration errors
- Ensure database exists and credentials are correct in `.env`
- API: `php spark migrate`
- Admin: Not needed (reads from API)

## Repository Structure

```
ci4-starter-kit/
├── ci4-api-starter/              # REST API backend (port 8080)
│   ├── app/
│   │   ├── DTO/                  # Request/Response contracts (DTO-first)
│   │   ├── Services/             # Business logic layer
│   │   ├── Controllers/          # HTTP endpoints
│   │   ├── Models/               # Data models (Eloquent-based)
│   │   ├── Documentation/        # OpenAPI endpoint docs
│   │   └── ...
│   ├── CLAUDE.md                 # API-specific guidance
│   ├── GETTING_STARTED.md        # Detailed setup guide
│   ├── ARCHITECTURE.md           # System design
│   ├── DEPLOYMENT.md             # Production checklist
│   └── README.md
│
├── ci4-admin-starter/            # Server-rendered admin frontend (port 8082)
│   ├── app/
│   │   ├── Modules/              # Feature modules (Auth, Users, Files, etc)
│   │   ├── Libraries/            # ApiClient, HTTP layer
│   │   ├── Filters/              # Auth, Admin, Locale
│   │   ├── Views/                # Blade templates
│   │   ├── Helpers/              # UI/form helpers
│   │   └── ...
│   ├── CLAUDE.md                 # Admin-specific guidance
│   ├── docs/
│   │   ├── QUICK-START.md        # Setup guide
│   │   ├── ARCHITECTURE.md       # System design
│   │   ├── SERVICES.md           # Service patterns
│   │   ├── FRONTEND.md           # UI/UX guide
│   │   └── ...
│   ├── README.md
│   └── install.sh                # Interactive setup script
│
└── CLAUDE.md                     # This file (system-wide overview)
```

## Resources

**Project-specific:**
- `ci4-api-starter/CLAUDE.md` — API architecture & commands
- `ci4-admin-starter/CLAUDE.md` — Admin architecture & commands

**CodeIgniter 4:**
- [CodeIgniter 4 User Guide](https://codeigniter.com/user_guide/)
- [CI4 Modules](https://github.com/dcardenasl/ci4-admin-starter/docs/) (this project's extended patterns)

**Frontend Technologies:**
- [Tailwind CSS](https://tailwindcss.com/) — Utility-first CSS
- [Alpine.js](https://alpinejs.dev/) — Lightweight JS framework
- [Lucide Icons](https://lucide.dev/) — Icon library

**API Design:**
- [OpenAPI 3.0](https://spec.openapis.org/oas/v3.0.3)
- [JSON API Spec](https://jsonapi.org/) (reference, not strict requirement)

## Common Tasks

### Deploy Both Projects to Production

1. **API Deployment** — See `ci4-api-starter/DEPLOYMENT.md`
   - Build with `composer install --no-dev --optimize-autoloader`
   - Set `CI_ENVIRONMENT = production`
   - Enable `app.forceGlobalSecureRequests = true`
   - Rotate JWT secret immediately after provisioning

2. **Admin Deployment** — See `ci4-admin-starter/docs/DEPLOYMENT.md`
   - Build CSS: `npm ci && npm run build:css`
   - Install with `composer install --no-dev --optimize-autoloader`
   - Set `CI_ENVIRONMENT = production`
   - Point `apiClient.baseUrl` to production API

### Create a Backup of Both Projects

```bash
# Full backup of both projects
tar -czf ci4-starter-kit-backup-$(date +%Y%m%d).tar.gz ci4-api-starter/ ci4-admin-starter/

# Backup only source code (exclude vendor/, node_modules/, .git)
tar --exclude='vendor' --exclude='node_modules' --exclude='.git' \
  -czf ci4-starter-kit-src-$(date +%Y%m%d).tar.gz ci4-api-starter/ ci4-admin-starter/
```

## Getting Help

- **API questions?** See `ci4-api-starter/CLAUDE.md` and `docs/template/ARCHITECTURE_CONTRACT.md`
- **Admin questions?** See `ci4-admin-starter/CLAUDE.md` and `docs/ARCHITECTURE.md`
- **General CodeIgniter?** Check [CodeIgniter 4 documentation](https://codeigniter.com/user_guide/)
- **Bug or feature request?** Check each project's GitHub issues

---

**Last Updated:** 2026-04-16  
**Status:** Production Ready ✅
