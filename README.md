# CI4 Starter Kit

A complete, production-ready starting point for administrative applications built with CodeIgniter 4. Includes a REST API backend and a server-rendered admin frontend — both fully implemented and ready to customize.

## What's Inside

| Project | Description | Port |
|---------|-------------|------|
| [`ci4-api-starter`](ci4-api-starter/) | REST API backend — JWT auth, RBAC, CRUD scaffolding, OpenAPI docs | 8080 |
| [`ci4-admin-starter`](ci4-admin-starter/) | Admin frontend — Tailwind CSS, Alpine.js, all modules wired | 8082 |

**Architecture:**
```
Browser → CI4 Admin (8082) → CI4 API (8080) → MySQL
```

## Quick Start

### Prerequisites

- PHP 8.2+
- Composer
- Node.js + npm
- MySQL (local or Docker)
- Git

### Create a new project

```bash
git clone https://github.com/dcardenasl/ci4-starter-kit.git
cd ci4-starter-kit
bash new-project.sh
```

The script will:
1. Ask for a project name and output directory
2. Copy both sub-projects (no git history, no vendor files)
3. Initialize fresh git repos for each
4. Walk you through API setup: database config, migrations, superadmin
5. Walk you through Admin setup: API URL, ports, app name
6. Print the commands to start all three processes

Total time: ~5 minutes (mostly waiting on `composer install`).

## What the setup scripts do

### API setup (`init.sh`)
- Installs Composer dependencies
- Creates `.env` from `.env.example` and generates JWT + encryption keys
- Creates the main and test databases
- Runs all migrations
- Optionally creates a superadmin account
- Generates the OpenAPI schema

### Admin setup (`install.sh`)
- Replaces all template references (`ci4-api-starter` → your API name)
- Configures `.env` with your API URL, app name, and port
- Optionally installs Composer dependencies

## Running the project

After setup, open three terminals:

```bash
# Terminal 1 — API server
cd my-app-api && php spark serve

# Terminal 2 — Admin server
cd my-app-admin && php spark serve --port 8082

# Terminal 3 — Tailwind CSS watcher
cd my-app-admin && npm run dev:css
```

Then open [http://localhost:8082](http://localhost:8082) and log in with your superadmin credentials.

## Adding features

**New API endpoint:**
```bash
cd my-app-api
bash bin/make-crud.sh Product Catalog \
  'name:string:required|searchable,price:decimal:required|filterable' \
  yes
php spark module:check Product --domain Catalog
php spark migrate
pkill -f 'spark serve'; php spark serve --port 8080 &
php spark swagger:generate
```

**New Admin module:** See [`ci4-admin-starter/CLAUDE.md`](ci4-admin-starter/CLAUDE.md) for the module structure.

## Documentation

- [`ci4-api-starter/CLAUDE.md`](ci4-api-starter/CLAUDE.md) — API architecture, DTO-first patterns, testing
- [`ci4-admin-starter/CLAUDE.md`](ci4-admin-starter/CLAUDE.md) — Admin architecture, ApiClient, modules
- [`ci4-api-starter/GETTING_STARTED.md`](ci4-api-starter/GETTING_STARTED.md) — Detailed API setup guide
- [`ci4-admin-starter/docs/`](ci4-admin-starter/docs/) — Frontend, services, deployment guides
- [`CLAUDE.md`](CLAUDE.md) — System-wide overview for AI-assisted development
