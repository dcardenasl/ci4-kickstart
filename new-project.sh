#!/usr/bin/env bash
# =============================================================================
# new-project.sh — CI4 Starter Kit · Orquestador de Nuevos Proyectos
#
# Uso: bash new-project.sh
#
# Clona ambos sub-proyectos (API y Admin) desde GitHub, inicializa
# git en cada uno y delega la configuración a sus scripts propios:
#   - init.sh    → deps, .env, DB, migraciones, superadmin
#   - install.sh → template config, .env, composer
#
# Compatible con macOS (BSD) y Linux (GNU).
# =============================================================================

set -euo pipefail

# ---------------------------------------------------------------------------
# Flags
# ---------------------------------------------------------------------------
AUTO_YES=false
RESET_DB=false
while [ $# -gt 0 ]; do
  case $1 in
    --yes|-y) AUTO_YES=true; shift ;;
    --reset-db)
      # Audit B11.3 (2026-05-07): drop the project DB before init.sh
      # creates it. Used when a previous run failed mid-setup and left
      # the DB in a partial state. Without this flag, re-running
      # new-project.sh either dies at the directory-exists check or
      # completes against a stale schema.
      RESET_DB=true; shift ;;
    --help|-h)
      printf "Usage: bash new-project.sh [--yes|-y] [--reset-db]\n\n"
      printf "Options:\n"
      printf "  --yes, -y      Auto-confirm the '¿Continuar?' prompt\n"
      printf "  --reset-db     Drop the project DB before init (recovery from partial setup)\n"
      printf "  --help         Show this help\n\n"
      printf "Env var overrides (used by CI / non-TTY runs):\n"
      printf "  CI4_PROJECT_NAME       Project name (skips prompt)\n"
      printf "  CI4_OUTPUT_DIR         Output directory (default ../)\n"
      printf "  CI4_INCLUDE_DOMAIN     y|n — include ci4-domain-starter as third repo\n"
      printf "  CI4_DOMAIN_APP_CODE    Application code in the hub (default <name>-domain)\n"
      printf "  CI4_DOMAIN_PORT        Port for domain dev server (default 8090)\n"
      exit 0
      ;;
    *)
      printf "Unknown option: %s\n" "$1" >&2
      exit 1
      ;;
  esac
done

# -----------------------------------------------------------------------------
# Colors & output helpers
# -----------------------------------------------------------------------------
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
BLUE='\033[0;34m'
BOLD='\033[1m'
RESET='\033[0m'

print_header() { echo -e "\n${BOLD}${BLUE}══ $* ══${RESET}"; }
print_ok()     { echo -e "  ${GREEN}${BOLD}✓${RESET}  $*"; }
print_warn()   { echo -e "  ${YELLOW}${BOLD}!${RESET}  $*"; }
print_err()    { echo -e "  ${RED}${BOLD}✗${RESET}  $*" >&2; }
die()          { print_err "$*"; exit 1; }

# -----------------------------------------------------------------------------
# Template repos en GitHub
# -----------------------------------------------------------------------------
API_TEMPLATE_REPO="https://github.com/dcardenasl/ci4-api-starter.git"
ADMIN_TEMPLATE_REPO="https://github.com/dcardenasl/ci4-admin-starter.git"
DOMAIN_TEMPLATE_REPO="https://github.com/dcardenasl/ci4-domain-starter.git"

# -----------------------------------------------------------------------------
# Cleanup: removes only directories THIS SCRIPT created on unexpected failure.
# Tracks what was actually created to avoid deleting pre-existing directories.
# -----------------------------------------------------------------------------
API_DIR=""
ADMIN_DIR=""
DOMAIN_DIR=""
API_CREATED=false
ADMIN_CREATED=false
DOMAIN_CREATED=false
HUB_PID=""

cleanup_on_error() {
    local exit_code=$?
    if [ $exit_code -ne 0 ]; then
        echo ""
        print_err "El script falló (código $exit_code). Limpiando directorios creados..."
        # Kill the background hub process first so its file handles release before
        # we rm -rf the API dir.
        if [ -n "$HUB_PID" ] && kill -0 "$HUB_PID" 2>/dev/null; then
            kill "$HUB_PID" 2>/dev/null || true
            print_warn "Detenido proceso hub (PID ${HUB_PID})"
        fi
        local cleaned=false
        if [ "$API_CREATED" = "true" ] && [ -n "$API_DIR" ] && [ -e "$API_DIR" ]; then
            rm -rf "$API_DIR"
            print_warn "Eliminado: ${API_DIR}"
            cleaned=true
        fi
        if [ "$ADMIN_CREATED" = "true" ] && [ -n "$ADMIN_DIR" ] && [ -e "$ADMIN_DIR" ]; then
            rm -rf "$ADMIN_DIR"
            print_warn "Eliminado: ${ADMIN_DIR}"
            cleaned=true
        fi
        if [ "$DOMAIN_CREATED" = "true" ] && [ -n "$DOMAIN_DIR" ] && [ -e "$DOMAIN_DIR" ]; then
            rm -rf "$DOMAIN_DIR"
            print_warn "Eliminado: ${DOMAIN_DIR}"
            cleaned=true
        fi
        if [ "$cleaned" = "false" ]; then
            print_warn "No se realizaron cambios permanentes."
        fi
    fi
}

trap cleanup_on_error EXIT

trim() {
    local value="$1"
    value="${value#"${value%%[![:space:]]*}"}"
    value="${value%"${value##*[![:space:]]}"}"
    printf "%s" "$value"
}

slugify() {
    local input
    input="$(printf "%s" "$1" | tr '[:upper:]' '[:lower:]')"
    input="$(printf "%s" "$input" | sed -E 's/[^a-z0-9._-]+/-/g; s/^-+//; s/-+$//')"
    printf "%s" "$input"
}

require_cmd() {
    command -v "$1" >/dev/null 2>&1 || die "Comando requerido no encontrado: '$1'. Instálalo antes de continuar."
}

# Validate that PHP meets minimum version. Aborts with a clear message otherwise.
require_php_version() {
    local min_major="$1"
    local min_minor="$2"
    local current
    current="$(php -r 'echo PHP_VERSION;' 2>/dev/null)" || die "PHP no responde. Verifica tu instalación."

    if ! php -r "exit(version_compare(PHP_VERSION, '${min_major}.${min_minor}.0', '>=') ? 0 : 1);" 2>/dev/null; then
        die "Se requiere PHP ${min_major}.${min_minor}+ (encontrado: ${current})."
    fi
}

# Validate Composer is at least version 2. Aborts otherwise.
require_composer_v2() {
    local version_line
    version_line="$(composer --version 2>/dev/null | head -n1)" || die "Composer no responde."
    if ! printf "%s" "$version_line" | grep -qE 'Composer.*version (2\.|[3-9]\.)'; then
        die "Se requiere Composer 2.x o superior. Detectado: ${version_line}"
    fi
}

# -----------------------------------------------------------------------------
# Directorio del script (para regresar después de cd a subdirectorios)
# -----------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# =============================================================================
# Banner
# =============================================================================
echo ""
echo -e "${BOLD}${CYAN}╔══════════════════════════════════════════════════════════════╗${RESET}"
echo -e "${BOLD}${CYAN}║              CI4 Kickstart — Nuevo Proyecto                  ║${RESET}"
echo -e "${BOLD}${CYAN}╚══════════════════════════════════════════════════════════════╝${RESET}"
echo ""
echo "  Crea proyectos independientes (API + Admin, opcionalmente"
echo "  un Domain) a partir del kit, configura entornos, base de"
echo "  datos y superadmin."
echo ""
echo "  Presiona Ctrl+C en cualquier momento para cancelar."
echo ""

# =============================================================================
# Prerequisitos mínimos del orquestador
# =============================================================================
print_header "Verificando prerequisitos"
require_cmd git
require_cmd php
require_cmd composer
require_cmd npm
require_cmd mysql
require_php_version 8 2
require_composer_v2
print_ok "git, php (8.2+), composer (2.x), npm y mysql encontrados"

# =============================================================================
# Recolección de datos
# =============================================================================
print_header "Configuración del proyecto"

if [ -n "${CI4_PROJECT_NAME:-}" ]; then
  PROJECT_NAME_RAW="$(trim "$CI4_PROJECT_NAME")"
else
  read -r -p "$(echo -e "  ${BOLD}Nombre del proyecto${RESET} (e.g. my-app): ")" INPUT_PROJECT_NAME
  PROJECT_NAME_RAW="$(trim "$INPUT_PROJECT_NAME")"
fi
[[ -n "$PROJECT_NAME_RAW" ]] || die "El nombre del proyecto no puede estar vacío."
PROJECT_NAME="$(slugify "$PROJECT_NAME_RAW")"
[[ -n "$PROJECT_NAME" ]] || die "El nombre resultante está vacío tras el slugify. Usa caracteres alfanuméricos."

if [ -n "${CI4_OUTPUT_DIR:-}" ]; then
  OUTPUT_DIR="$(trim "$CI4_OUTPUT_DIR")"
else
  read -r -p "$(echo -e "  ${BOLD}Directorio de salida${RESET} [../]: ")" INPUT_OUTPUT_DIR
  OUTPUT_DIR="$(trim "${INPUT_OUTPUT_DIR:-../}")"
fi
# Asegurar que termina en /
[[ "${OUTPUT_DIR: -1}" == "/" ]] || OUTPUT_DIR="${OUTPUT_DIR}/"

# Optional: scaffold a ci4-domain-starter alongside the API + Admin.
# Domain apps delegate auth/RBAC to the API (the "hub") and own their own
# business-logic tables. See KICK-001.
if [ -n "${CI4_INCLUDE_DOMAIN:-}" ]; then
  INCLUDE_DOMAIN_RAW="$(trim "$CI4_INCLUDE_DOMAIN")"
else
  read -r -p "$(echo -e "  ${BOLD}Incluir domain starter?${RESET} (y/N): ")" INCLUDE_DOMAIN_RAW
fi
_include_lower="$(printf '%s' "${INCLUDE_DOMAIN_RAW:-n}" | tr '[:upper:]' '[:lower:]')"
INCLUDE_DOMAIN=false
if [ "$_include_lower" = "y" ] || [ "$_include_lower" = "yes" ]; then
  INCLUDE_DOMAIN=true
fi

DOMAIN_APP_CODE=""
DOMAIN_PORT=""
if [ "$INCLUDE_DOMAIN" = true ]; then
  DEFAULT_DOMAIN_CODE="${PROJECT_NAME}-domain"
  if [ -n "${CI4_DOMAIN_APP_CODE:-}" ]; then
    DOMAIN_APP_CODE="$(trim "$CI4_DOMAIN_APP_CODE")"
  else
    read -r -p "$(echo -e "  ${BOLD}Application code${RESET} [${DEFAULT_DOMAIN_CODE}]: ")" INPUT_DOMAIN_CODE
    DOMAIN_APP_CODE="$(trim "${INPUT_DOMAIN_CODE:-$DEFAULT_DOMAIN_CODE}")"
  fi
  DOMAIN_APP_CODE="$(slugify "$DOMAIN_APP_CODE")"

  if [ -n "${CI4_DOMAIN_PORT:-}" ]; then
    DOMAIN_PORT="$(trim "$CI4_DOMAIN_PORT")"
  else
    read -r -p "$(echo -e "  ${BOLD}Domain port${RESET} [8090]: ")" INPUT_DOMAIN_PORT
    DOMAIN_PORT="$(trim "${INPUT_DOMAIN_PORT:-8090}")"
  fi
fi

API_DIR="${OUTPUT_DIR}${PROJECT_NAME}-api"
ADMIN_DIR="${OUTPUT_DIR}${PROJECT_NAME}-admin"
[ "$INCLUDE_DOMAIN" = true ] && DOMAIN_DIR="${OUTPUT_DIR}${PROJECT_NAME}-domain"

echo ""
echo -e "  ${BOLD}Se crearán:${RESET}"
echo -e "    API:    ${CYAN}${API_DIR}${RESET}"
echo -e "    Admin:  ${CYAN}${ADMIN_DIR}${RESET}"
[ "$INCLUDE_DOMAIN" = true ] && echo -e "    Domain: ${CYAN}${DOMAIN_DIR}${RESET} (app=${DOMAIN_APP_CODE}, port=${DOMAIN_PORT})"
echo ""

# Verificar que los directorios destino no existan
[[ ! -e "$API_DIR" ]]   || die "El directorio '${API_DIR}' ya existe. Elige otro nombre o elimínalo."
[[ ! -e "$ADMIN_DIR" ]] || die "El directorio '${ADMIN_DIR}' ya existe. Elige otro nombre o elimínalo."
if [ "$INCLUDE_DOMAIN" = true ]; then
  [[ ! -e "$DOMAIN_DIR" ]] || die "El directorio '${DOMAIN_DIR}' ya existe. Elige otro nombre o elimínalo."
fi

if [ "$AUTO_YES" = true ] || [ -n "${CI4_CONFIRM:-}" ]; then
  CONFIRM="${CI4_CONFIRM:-y}"
else
  read -r -p "$(echo -e "  ${BOLD}¿Continuar? [y/N]:${RESET} ")" CONFIRM
fi
_confirm_lower="$(printf '%s' "$CONFIRM" | tr '[:upper:]' '[:lower:]')"
[ "$_confirm_lower" = "y" ] || { echo ""; print_warn "Cancelado. No se realizaron cambios."; exit 0; }

# =============================================================================
# Clonación de proyectos desde GitHub
# =============================================================================
print_header "Clonando proyectos desde GitHub"

clone_project() {
    local repo_url="$1"
    local dst="$2"
    local label="$3"

    echo -e "  ${CYAN}▶${RESET}  Clonando ${label} desde GitHub..."
    git clone --depth 1 --quiet "$repo_url" "$dst" || \
        die "No se pudo clonar ${label}. Verifica la URL y tu conexión a internet."
    rm -rf "${dst}/.git"
    print_ok "${label} clonado"
}

clone_project "$API_TEMPLATE_REPO"   "$API_DIR"   "API"
API_DIR="$(cd "$API_DIR" && pwd)"
API_CREATED=true
clone_project "$ADMIN_TEMPLATE_REPO" "$ADMIN_DIR" "Admin"
ADMIN_DIR="$(cd "$ADMIN_DIR" && pwd)"
ADMIN_CREATED=true
if [ "$INCLUDE_DOMAIN" = true ]; then
  clone_project "$DOMAIN_TEMPLATE_REPO" "$DOMAIN_DIR" "Domain"
  DOMAIN_DIR="$(cd "$DOMAIN_DIR" && pwd)"
  DOMAIN_CREATED=true
fi

# =============================================================================
# Inicialización de git
# =============================================================================
print_header "Inicializando repositorios git"

init_git() {
    local dir="$1"
    local label="$2"

    cd "$dir"

    git init -q

    # Verificar que .env está en .gitignore antes de hacer commit
    if git check-ignore -q .env 2>/dev/null; then
        git add . >/dev/null 2>&1
        if git commit -q -m "Initial commit from ci4-kickstart" 2>/dev/null; then
            print_ok "Git inicializado en ${label} con commit inicial"
        else
            print_warn "Git inicializado en ${label} pero el commit falló — configura git user.name/email y haz commit manualmente."
        fi
    else
        print_warn ".env no está en .gitignore de ${label} — git inicializado pero sin commit para evitar filtrar credenciales."
    fi

    cd "$SCRIPT_DIR"
}

init_git "$API_DIR"   "${PROJECT_NAME}-api"
init_git "$ADMIN_DIR" "${PROJECT_NAME}-admin"
[ "$INCLUDE_DOMAIN" = true ] && init_git "$DOMAIN_DIR" "${PROJECT_NAME}-domain"

# =============================================================================
# Export CI4_* env vars so child scripts inherit them
# =============================================================================
export CI4_DB_HOST CI4_DB_PORT CI4_DB_USER CI4_DB_PASS CI4_DB_NAME CI4_TEST_DB_NAME
export CI4_SA_EMAIL CI4_SA_PASSWORD CI4_SA_FIRST_NAME CI4_SA_LAST_NAME
export CI4_API_NAME CI4_API_GITHUB_URL CI4_API_BASE_URL CI4_APP_NAME CI4_ADMIN_PORT
export CI4_RUN_COMPOSER CI4_REMOVE_SELF CI4_CONFIRM CI4_START_SERVER
export CI4_RESET_GIT CI4_DOCKER_CONTAINER CI4_OVERWRITE_ENV

# =============================================================================
# Setup de la API
# =============================================================================
print_header "Configurando API (${PROJECT_NAME}-api)"
echo ""
echo -e "  ${YELLOW}init.sh tomará el control a continuación.${RESET}"
echo -e "  Te pedirá: configuración de DB, credenciales del superadmin, etc."
echo ""

# Audit B11.3 (2026-05-07): when --reset-db was passed, drop the target
# DB before init.sh runs so a partial previous run can't pollute the new
# setup. Best-effort: connection failures are warnings, not hard fails —
# init.sh will fail predictably if the DB really is unreachable.
if [ "$RESET_DB" = "true" ]; then
  if [ -n "${CI4_DB_NAME:-}" ] && command -v mysql >/dev/null 2>&1; then
    print_warn "  --reset-db: dropping database '${CI4_DB_NAME}' (and '${CI4_TEST_DB_NAME:-${CI4_DB_NAME}_test}') before init.sh."
    MYSQL_PWD="${CI4_DB_PASS:-}" mysql \
      -h "${CI4_DB_HOST:-127.0.0.1}" \
      -P "${CI4_DB_PORT:-3306}" \
      -u "${CI4_DB_USER:-root}" \
      -e "DROP DATABASE IF EXISTS \`${CI4_DB_NAME}\`; DROP DATABASE IF EXISTS \`${CI4_TEST_DB_NAME:-${CI4_DB_NAME}_test}\`;" \
      2>&1 | sed 's/^/    /' || print_warn "  --reset-db: drop failed (DB unreachable?). init.sh will surface the real error."
  else
    print_warn "  --reset-db: skipped — needs CI4_DB_NAME exported and 'mysql' CLI available."
  fi
fi

cd "$API_DIR"
bash init.sh
cd "$SCRIPT_DIR"

# =============================================================================
# Bootstrap del hub para el domain starter (KICK-001)
# =============================================================================
# Cuando el usuario pide incluir el domain starter, automatizamos los pasos
# manuales que normalmente requeriría:
#   1. Registrar la application en el hub vía `apps:bootstrap --create-api-key`
#      (consume API-007: emite API_KEY=apk_... y APP_ID=N en stdout).
#   2. Levantar el hub en background para login + sync-permissions.
#   3. Loginear con el superadmin recién creado para capturar un JWT.
#   4. Pasar todo eso al domain init.sh vía env vars (corre no-TTY).
#   5. Apagar el hub.
# Si algo falla a mitad, cleanup_on_error mata HUB_PID y rm -rf los dirs.
if [ "$INCLUDE_DOMAIN" = true ]; then
    print_header "Preparando hub para domain starter"

    # 1. Registrar la app + crear API key (PRE-1 / API-007)
    cd "$API_DIR"
    APPS_BOOTSTRAP_OUT=$(php spark apps:bootstrap "$DOMAIN_APP_CODE" \
        --name="${PROJECT_NAME} domain" \
        --no-grant-user \
        --create-api-key 2>&1) || die "apps:bootstrap falló. Output:\n${APPS_BOOTSTRAP_OUT}"
    HUB_API_KEY=$(printf '%s' "$APPS_BOOTSTRAP_OUT" | awk -F= '/^API_KEY=/{print $2; exit}' | tr -d '\r')
    [ -n "$HUB_API_KEY" ] || die "No se obtuvo API_KEY de apps:bootstrap. Output:\n${APPS_BOOTSTRAP_OUT}"
    print_ok "Application '${DOMAIN_APP_CODE}' registrada y API key generada"

    # 2. Levantar el hub en background
    HUB_LOG="/tmp/ci4-kickstart-hub-${PROJECT_NAME}.log"
    php spark serve --port 8080 >"$HUB_LOG" 2>&1 &
    HUB_PID=$!
    cd "$SCRIPT_DIR"

    # Esperar readiness — health endpoint o accept on port
    print_warn "  Esperando que el hub responda en :8080..."
    for _i in $(seq 1 20); do
        if curl -fsS http://localhost:8080/health >/dev/null 2>&1; then
            break
        fi
        sleep 1
    done
    kill -0 "$HUB_PID" 2>/dev/null || die "El hub no arrancó en 20s. Ver ${HUB_LOG}"
    print_ok "Hub corriendo en background (PID ${HUB_PID})"

    # 3. Login con el SA para capturar un JWT (sync-permissions necesita iam.superadmin-access)
    if [ -z "${CI4_SA_EMAIL:-}" ] || [ -z "${CI4_SA_PASSWORD:-}" ]; then
        kill "$HUB_PID" 2>/dev/null || true
        HUB_PID=""
        die "CI4_SA_EMAIL y CI4_SA_PASSWORD no fueron exportados por init.sh — no puedo loginear al hub."
    fi
    LOGIN_RESP=$(curl -fsS -X POST http://localhost:8080/api/v1/auth/login \
        -H "Content-Type: application/json" \
        -d "{\"email\":\"${CI4_SA_EMAIL}\",\"password\":\"${CI4_SA_PASSWORD}\"}" 2>&1) \
        || die "Login en el hub falló. Response:\n${LOGIN_RESP}"
    DOMAIN_ADMIN_TOKEN=$(printf '%s' "$LOGIN_RESP" | sed -E 's/.*"access_token":"([^"]+)".*/\1/')
    if [ -z "$DOMAIN_ADMIN_TOKEN" ] || [ "$DOMAIN_ADMIN_TOKEN" = "$LOGIN_RESP" ]; then
        kill "$HUB_PID" 2>/dev/null || true
        HUB_PID=""
        die "No se pudo extraer access_token de la respuesta del hub.\nResponse: ${LOGIN_RESP}"
    fi
    print_ok "Superadmin JWT capturado"

    # 4. Exportar coords para domain init.sh (corre no-TTY, no prompts)
    export CI4_DOMAIN_HUB_URL="http://localhost:8080"
    export CI4_DOMAIN_APP_CODE="$DOMAIN_APP_CODE"
    export CI4_DOMAIN_API_KEY="$HUB_API_KEY"
    export CI4_DOMAIN_ADMIN_TOKEN="$DOMAIN_ADMIN_TOKEN"
    # DB defaults: misma instancia MySQL que el api-starter, distinta DB
    export CI4_DOMAIN_DB_HOST="${CI4_DB_HOST:-127.0.0.1}"
    export CI4_DOMAIN_DB_PORT="${CI4_DB_PORT:-3306}"
    export CI4_DOMAIN_DB_USER="${CI4_DB_USER:-root}"
    export CI4_DOMAIN_DB_PASS="${CI4_DB_PASS-}"
    export CI4_DOMAIN_DB_NAME="${PROJECT_NAME}_domain"
    export CI4_DOMAIN_TEST_DB_NAME="${PROJECT_NAME}_domain_test"

    print_header "Configurando Domain (${PROJECT_NAME}-domain)"
    cd "$DOMAIN_DIR"
    bash init.sh --skip-server
    cd "$SCRIPT_DIR"

    # 5. Apagar el hub background
    if [ -n "$HUB_PID" ] && kill -0 "$HUB_PID" 2>/dev/null; then
        kill "$HUB_PID" 2>/dev/null || true
        print_ok "Hub detenido (PID ${HUB_PID})"
    fi
    HUB_PID=""
fi

# =============================================================================
# Setup del Admin
# =============================================================================
print_header "Configurando Admin (${PROJECT_NAME}-admin)"
echo ""
echo -e "  ${YELLOW}install.sh tomará el control a continuación.${RESET}"
echo -e "  Te pedirá: nombre del repo API, URL base del API, puerto del admin, etc."
echo ""
echo -e "  ${BOLD}Consejo:${RESET} cuando te pregunte si deseas eliminar install.sh,"
echo -e "  responde ${BOLD}N${RESET} para conservarlo y poder reconfigurar en el futuro."
echo ""

cd "$ADMIN_DIR"
bash install.sh
cd "$SCRIPT_DIR"

# =============================================================================
# Resumen final
# =============================================================================
print_header "Proyecto listo"
echo ""
echo -e "  ${BOLD}Proyectos creados:${RESET}"
echo -e "    ${CYAN}$(cd "$API_DIR" && pwd)${RESET}"
echo -e "    ${CYAN}$(cd "$ADMIN_DIR" && pwd)${RESET}"
[ "$INCLUDE_DOMAIN" = true ] && echo -e "    ${CYAN}$(cd "$DOMAIN_DIR" && pwd)${RESET}"
echo ""
echo -e "  ${BOLD}Para levantar el entorno de desarrollo:${RESET}"
echo ""
echo -e "  ${YELLOW}Terminal 1 — API (hub):${RESET}"
echo -e "    cd ${API_DIR}"
echo -e "    php spark serve"
echo ""
echo -e "  ${YELLOW}Terminal 2 — Admin:${RESET}"
echo -e "    cd ${ADMIN_DIR}"
echo -e "    php spark serve --port 8082"
echo ""
echo -e "  ${YELLOW}Terminal 3 — CSS (Tailwind watcher):${RESET}"
echo -e "    cd ${ADMIN_DIR}"
echo -e "    npm run dev:css"
if [ "$INCLUDE_DOMAIN" = true ]; then
echo ""
echo -e "  ${YELLOW}Terminal 4 — Domain:${RESET}"
echo -e "    cd ${DOMAIN_DIR}"
echo -e "    php spark serve --port ${DOMAIN_PORT}"
fi
echo ""
echo -e "  ${BOLD}Accede al admin en:${RESET}  ${CYAN}http://localhost:8082${RESET}"
[ "$INCLUDE_DOMAIN" = true ] && echo -e "  ${BOLD}Domain API en:${RESET}        ${CYAN}http://localhost:${DOMAIN_PORT}${RESET}  (app=${DOMAIN_APP_CODE})"
echo ""
