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
      printf "  CI4_DOMAINS            CSV of 'name:template_slug:port' tuples (e.g. shop:vanilla:8090,blog:vanilla:8091)\n"
      printf "                         template_slug must match an entry in templates.json or be 'vanilla'\n"
      printf "  CI4_INCLUDE_DOMAIN     [legacy] y|n — equivalent to CI4_DOMAINS='<name>-domain:vanilla:<port>'\n"
      printf "  CI4_DOMAIN_APP_CODE    [legacy] App code when CI4_INCLUDE_DOMAIN=y (default <name>-domain)\n"
      printf "  CI4_DOMAIN_PORT        [legacy] Port when CI4_INCLUDE_DOMAIN=y (default 8090)\n"
      printf "  CI4_INCLUDE_BFF        y|n — include ci4-bff-starter as gateway\n"
      printf "  CI4_BFF_PORT           Port for bff dev server (default 8088)\n"
      printf "  CI4_BFF_ALLOWED_ORIGINS  CSV of CORS origins for the BFF (default: localhost:5173,localhost:3000)\n"
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
BFF_TEMPLATE_REPO="https://github.com/dcardenasl/ci4-bff-starter.git"

# -----------------------------------------------------------------------------
# Cleanup: removes only directories THIS SCRIPT created on unexpected failure.
# Tracks what was actually created to avoid deleting pre-existing directories.
# -----------------------------------------------------------------------------
API_DIR=""
ADMIN_DIR=""
BFF_DIR=""
API_CREATED=false
ADMIN_CREATED=false
BFF_CREATED=false
HUB_PID=""
# Parallel arrays describing every domain app this run scaffolds.
# Populated in the prompt phase; consumed by clone/init/bootstrap/summary loops.
DOMAIN_NAMES=()        # repo dir slug (e.g. "shop")
DOMAIN_TEMPLATES=()    # "vanilla" or a templates.json slug
DOMAIN_PORTS=()        # dev server port
DOMAIN_APP_CODES=()    # application code registered in the hub
DOMAIN_DIRS=()         # absolute path of the cloned dir (set after clone)
DOMAIN_REQUIRES_BFF=() # "true" if template.json declares requires_bff:true

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
        # Domains: DOMAIN_DIRS holds dirs we've created so far in this run.
        # Entries are only appended after a successful clone. Guard against
        # set -u: under bash 3.2 / strict mode, "${arr[@]}" on an empty array
        # is treated as unbound, so we check size first.
        if [ ${#DOMAIN_DIRS[@]} -gt 0 ]; then
            for _ddir in "${DOMAIN_DIRS[@]}"; do
                if [ -n "$_ddir" ] && [ -e "$_ddir" ]; then
                    rm -rf "$_ddir"
                    print_warn "Eliminado: ${_ddir}"
                    cleaned=true
                fi
            done
        fi
        if [ "$BFF_CREATED" = "true" ] && [ -n "$BFF_DIR" ] && [ -e "$BFF_DIR" ]; then
            rm -rf "$BFF_DIR"
            print_warn "Eliminado: ${BFF_DIR}"
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
# Template helpers (TMPL-002 → TMPL-004)
# -----------------------------------------------------------------------------
# Reads templates.json catalog and returns the selected template slug to stdout.
# UI (prompts, menu) goes to stderr so callers can `slug=$(prompt_template_selection)`.
# Returns "vanilla" when catalog is empty, jq is unavailable, or user picks 0.
prompt_template_selection() {
    local templates_file="${SCRIPT_DIR}/templates.json"
    local count=0
    if [ -f "$templates_file" ] && command -v jq >/dev/null 2>&1; then
        count=$(jq '.templates | length' "$templates_file" 2>/dev/null || echo 0)
    fi

    if [ "$count" = "0" ]; then
        # Empty catalog or jq missing → silently use vanilla. The interactive
        # caller still sees the rest of the domain prompt; only the template
        # menu is skipped.
        printf "vanilla"
        return
    fi

    {
        echo ""
        echo "  Templates disponibles:"
        echo "    0) vanilla — ci4-domain-starter sin entidades"
        jq -r '.templates | to_entries[] | "    \(.key + 1)) \(.value.name) — \(.value.description)"' "$templates_file"
    } >&2

    local choice
    printf "  Selección [0]: " >&2
    read -r choice
    choice="${choice:-0}"

    if ! printf '%s' "$choice" | grep -qE '^[0-9]+$'; then
        echo "  Selección inválida (no es número), usando vanilla." >&2
        printf "vanilla"
        return
    fi

    if [ "$choice" -eq 0 ]; then
        printf "vanilla"
    elif [ "$choice" -le "$count" ]; then
        jq -r ".templates[$((choice - 1))].slug" "$templates_file"
    else
        echo "  Selección fuera de rango, usando vanilla." >&2
        printf "vanilla"
    fi
}

# Looks up the GitHub repo for a template slug from templates.json.
# Echoes the repo as "owner/repo" or returns 1 if not found.
template_repo_for_slug() {
    local slug="$1"
    local templates_file="${SCRIPT_DIR}/templates.json"
    [ -f "$templates_file" ] || return 1
    command -v jq >/dev/null 2>&1 || return 1
    local repo
    repo=$(jq -r --arg s "$slug" '.templates[] | select(.slug == $s) | .repo' "$templates_file" 2>/dev/null)
    [ -n "$repo" ] && [ "$repo" != "null" ] || return 1
    printf "%s" "$repo"
}

# Reads a single boolean field from a cloned template's template.json.
# Returns "true" or "false" on stdout. Defaults to "false" if file or field is missing.
template_field_bool() {
    local template_json="$1"
    local field="$2"
    [ -f "$template_json" ] || { printf "false"; return; }
    command -v jq >/dev/null 2>&1 || { printf "false"; return; }
    local value
    value=$(jq -r --arg f "$field" '.[$f] // false' "$template_json" 2>/dev/null)
    if [ "$value" = "true" ]; then
        printf "true"
    else
        printf "false"
    fi
}

# Validates a cloned template's template.json against the contract in
# docs/TEMPLATE_CONTRACT.md and executes the post-clone steps:
#   - Validate required fields + permission separator + admin_modules.service
#   - Generate admin modules via ci4-admin-starter/bin/make-module.sh
#   - Warn about public_endpoints[] if BFF is active (manual review)
# init.sh (which runs after this) handles permissions via domain:sync-permissions
# reading DomainPermissions.php, so this function does not register permissions itself.
apply_template() {
    local domain_dir="$1"
    local template_json="${domain_dir}/template.json"

    if [ ! -f "$template_json" ]; then
        return 0
    fi

    command -v jq >/dev/null 2>&1 || die "jq es requerido para procesar template.json. Instálalo: 'brew install jq' (macOS) o 'apt install jq' (Linux)."

    jq empty "$template_json" 2>/dev/null || die "template.json inválido en ${domain_dir}"

    # Validate required fields
    local missing=()
    local field
    for field in name slug version entities permissions admin_modules; do
        if ! jq -e ".${field}" "$template_json" >/dev/null 2>&1; then
            missing+=("$field")
        fi
    done
    if [ ${#missing[@]} -gt 0 ]; then
        die "template.json en ${domain_dir} no tiene campos obligatorios: ${missing[*]}"
    fi

    local template_name
    template_name=$(jq -r '.name' "$template_json")
    print_ok "Aplicando template '${template_name}'"

    # Validate permission codes use dot separator (not colon — CI4 filter parser splits on :)
    local bad_perms
    bad_perms=$(jq -r '.permissions[] | select(test(":"))' "$template_json")
    if [ -n "$bad_perms" ]; then
        die "template.json: los permisos deben usar punto (.) como separador, no dos puntos. Encontrados con ':' → ${bad_perms}"
    fi

    # Validate admin_modules[].service ∈ {hub, domain}
    local bad_svc
    bad_svc=$(jq -r '.admin_modules[] | select(.service != "hub" and .service != "domain") | .name' "$template_json")
    if [ -n "$bad_svc" ]; then
        die "template.json: admin_modules[].service debe ser 'hub' o 'domain'. Módulos inválidos: ${bad_svc}"
    fi

    # Generate admin modules
    local module_count
    module_count=$(jq '.admin_modules | length' "$template_json")
    if [ "$module_count" -gt 0 ]; then
        if [ ! -x "${ADMIN_DIR}/bin/make-module.sh" ]; then
            print_warn "  ${ADMIN_DIR}/bin/make-module.sh no encontrado — saltando ${module_count} módulos admin del template."
        else
            print_warn "  Generando ${module_count} módulos admin desde template..."
            local i
            for ((i=0; i<module_count; i++)); do
                local mod_name mod_entity mod_service mod_path
                mod_name=$(jq -r ".admin_modules[$i].name" "$template_json")
                mod_entity=$(jq -r ".admin_modules[$i].entity" "$template_json")
                mod_service=$(jq -r ".admin_modules[$i].service" "$template_json")

                # entity name (PascalCase) → kebab-case URL segment, pluralized with -s
                mod_path=$(printf '%s' "$mod_entity" | sed -E 's/([a-z0-9])([A-Z])/\1-\2/g' | tr '[:upper:]' '[:lower:]')
                mod_path="/api/v1/${mod_path}s"

                (cd "$ADMIN_DIR" && bash bin/make-module.sh "$mod_entity" "$mod_name" "$mod_path" "--service=${mod_service}") || \
                    print_warn "  make-module.sh falló para ${mod_name} — revisa manualmente."
            done
        fi
    fi

    # Public endpoints — only warn, since wiring routes into the BFF reliably
    # requires inspecting its Routes/v1/ structure and that's better done by hand
    # for the first release of the template system.
    local public_count
    public_count=$(jq '(.public_endpoints // []) | length' "$template_json")
    if [ "$public_count" -gt 0 ]; then
        if [ "$INCLUDE_BFF" = true ]; then
            print_warn "  Template declara ${public_count} public_endpoints. Agrégalos manualmente al BFF en ${BFF_DIR}/app/Config/Routes/v1/ sin filtro de auth."
        else
            print_warn "  Template declara ${public_count} public_endpoints pero el BFF no está incluido. Activa CI4_INCLUDE_BFF=y para usarlos."
        fi
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
echo "  un Domain y un BFF) a partir del kit, configura entornos,"
echo "  base de datos y superadmin."
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

# Optional: scaffold one or more ci4-domain-starter apps alongside the API + Admin.
# Domain apps delegate auth/RBAC to the API (the "hub") and own their own
# business-logic tables. See KICK-001 + TMPL-003.
#
# A run can register 0..N domains. Each domain has:
#   - a repo dir slug (name)
#   - a template choice (slug from templates.json or "vanilla")
#   - a dev server port
#   - an application code in the hub (defaults to the slug itself)
#
# Three input modes:
#   1. CI4_DOMAINS env var (CSV of "name:template:port") — for CI / non-TTY
#   2. Legacy CI4_INCLUDE_DOMAIN=y + CI4_DOMAIN_APP_CODE + CI4_DOMAIN_PORT — single vanilla domain
#   3. Interactive prompt loop — asks "¿Agregar un domain app?" until user answers no

INCLUDE_DOMAIN=false

if [ -n "${CI4_DOMAINS:-}" ]; then
  # Mode 1: parse CSV. Empty entries are skipped silently.
  IFS=',' read -r -a _csv_entries <<< "$(trim "$CI4_DOMAINS")"
  for _entry in "${_csv_entries[@]}"; do
    _entry="$(trim "$_entry")"
    [ -z "$_entry" ] && continue
    IFS=':' read -r _d_name _d_tpl _d_port <<< "$_entry"
    _d_name="$(slugify "$(trim "$_d_name")")"
    _d_tpl="$(trim "${_d_tpl:-vanilla}")"
    _d_port="$(trim "${_d_port:-$((8089 + ${#DOMAIN_NAMES[@]} + 1))}")"
    [ -n "$_d_name" ] || die "CI4_DOMAINS: entrada con nombre vacío en '${_entry}'."
    DOMAIN_NAMES+=("$_d_name")
    DOMAIN_TEMPLATES+=("$_d_tpl")
    DOMAIN_PORTS+=("$_d_port")
    DOMAIN_APP_CODES+=("$_d_name")
    INCLUDE_DOMAIN=true
  done
elif [ -n "${CI4_INCLUDE_DOMAIN:-}" ]; then
  # Mode 2: legacy single-domain env vars. Preserved for backwards compat.
  _legacy_lower="$(printf '%s' "$CI4_INCLUDE_DOMAIN" | tr '[:upper:]' '[:lower:]')"
  if [ "$_legacy_lower" = "y" ] || [ "$_legacy_lower" = "yes" ]; then
    _legacy_code="$(slugify "$(trim "${CI4_DOMAIN_APP_CODE:-${PROJECT_NAME}-domain}")")"
    _legacy_port="$(trim "${CI4_DOMAIN_PORT:-8090}")"
    DOMAIN_NAMES+=("$_legacy_code")
    DOMAIN_TEMPLATES+=("vanilla")
    DOMAIN_PORTS+=("$_legacy_port")
    DOMAIN_APP_CODES+=("$_legacy_code")
    INCLUDE_DOMAIN=true
  fi
else
  # Mode 3: interactive loop.
  _domain_idx=0
  while true; do
    if [ "$_domain_idx" -eq 0 ]; then
      read -r -p "$(echo -e "  ${BOLD}¿Agregar un domain app?${RESET} (y/N): ")" _add_domain
    else
      read -r -p "$(echo -e "  ${BOLD}¿Agregar otro domain app?${RESET} (y/N): ")" _add_domain
    fi
    _add_lower="$(printf '%s' "${_add_domain:-n}" | tr '[:upper:]' '[:lower:]')"
    [ "$_add_lower" = "y" ] || [ "$_add_lower" = "yes" ] || break

    _domain_idx=$((_domain_idx + 1))
    _default_name="${PROJECT_NAME}-domain"
    [ "$_domain_idx" -gt 1 ] && _default_name="${PROJECT_NAME}-domain-${_domain_idx}"
    read -r -p "$(echo -e "  ${BOLD}Nombre del domain${RESET} [${_default_name}]: ")" _d_name
    _d_name="$(slugify "$(trim "${_d_name:-$_default_name}")")"
    [ -n "$_d_name" ] || die "El nombre del domain no puede estar vacío."

    _d_template="$(prompt_template_selection)"

    _default_port=$((8089 + _domain_idx))
    read -r -p "$(echo -e "  ${BOLD}Puerto${RESET} [${_default_port}]: ")" _d_port
    _d_port="$(trim "${_d_port:-$_default_port}")"

    DOMAIN_NAMES+=("$_d_name")
    DOMAIN_TEMPLATES+=("$_d_template")
    DOMAIN_PORTS+=("$_d_port")
    DOMAIN_APP_CODES+=("$_d_name")
    INCLUDE_DOMAIN=true
  done
fi

# Optional: scaffold a ci4-bff-starter alongside API + Admin (+ Domain). The
# BFF is a stateless gateway over the hub (and optionally the domain) for
# decoupled clients (SPA, mobile). See BFF-006.
if [ -n "${CI4_INCLUDE_BFF:-}" ]; then
  INCLUDE_BFF_RAW="$(trim "$CI4_INCLUDE_BFF")"
else
  read -r -p "$(echo -e "  ${BOLD}Incluir BFF starter?${RESET} (y/N): ")" INCLUDE_BFF_RAW
fi
_include_bff_lower="$(printf '%s' "${INCLUDE_BFF_RAW:-n}" | tr '[:upper:]' '[:lower:]')"
INCLUDE_BFF=false
if [ "$_include_bff_lower" = "y" ] || [ "$_include_bff_lower" = "yes" ]; then
  INCLUDE_BFF=true
fi

BFF_PORT=""
BFF_ALLOWED_ORIGINS=""
if [ "$INCLUDE_BFF" = true ]; then
  if [ -n "${CI4_BFF_PORT:-}" ]; then
    BFF_PORT="$(trim "$CI4_BFF_PORT")"
  else
    read -r -p "$(echo -e "  ${BOLD}BFF port${RESET} [8088]: ")" INPUT_BFF_PORT
    BFF_PORT="$(trim "${INPUT_BFF_PORT:-8088}")"
  fi
  BFF_ALLOWED_ORIGINS="$(trim "${CI4_BFF_ALLOWED_ORIGINS:-http://localhost:5173,http://localhost:3000}")"
fi

API_DIR="${OUTPUT_DIR}${PROJECT_NAME}-api"
ADMIN_DIR="${OUTPUT_DIR}${PROJECT_NAME}-admin"
[ "$INCLUDE_BFF" = true ] && BFF_DIR="${OUTPUT_DIR}${PROJECT_NAME}-bff"

# Domain dirs: one per entry in DOMAIN_NAMES. Resolved to absolute paths after clone.
DOMAIN_DIRS_PLANNED=()
for _i in "${!DOMAIN_NAMES[@]}"; do
  DOMAIN_DIRS_PLANNED+=("${OUTPUT_DIR}${DOMAIN_NAMES[$_i]}")
done

echo ""
echo -e "  ${BOLD}Se crearán:${RESET}"
echo -e "    API:    ${CYAN}${API_DIR}${RESET}"
echo -e "    Admin:  ${CYAN}${ADMIN_DIR}${RESET}"
for _i in "${!DOMAIN_NAMES[@]}"; do
  _tpl_label="${DOMAIN_TEMPLATES[$_i]}"
  echo -e "    Domain: ${CYAN}${DOMAIN_DIRS_PLANNED[$_i]}${RESET} (template=${_tpl_label}, app=${DOMAIN_APP_CODES[$_i]}, port=${DOMAIN_PORTS[$_i]})"
done
[ "$INCLUDE_BFF" = true ]    && echo -e "    BFF:    ${CYAN}${BFF_DIR}${RESET} (port=${BFF_PORT})"
echo ""

# Verificar que los directorios destino no existan
[[ ! -e "$API_DIR" ]]   || die "El directorio '${API_DIR}' ya existe. Elige otro nombre o elimínalo."
[[ ! -e "$ADMIN_DIR" ]] || die "El directorio '${ADMIN_DIR}' ya existe. Elige otro nombre o elimínalo."
for _i in "${!DOMAIN_DIRS_PLANNED[@]}"; do
  [[ ! -e "${DOMAIN_DIRS_PLANNED[$_i]}" ]] || die "El directorio '${DOMAIN_DIRS_PLANNED[$_i]}' ya existe. Elige otro nombre o elimínalo."
done
if [ "$INCLUDE_BFF" = true ]; then
  [[ ! -e "$BFF_DIR" ]] || die "El directorio '${BFF_DIR}' ya existe. Elige otro nombre o elimínalo."
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

# Domains: clone each, resolving the repo URL from templates.json when the
# template slug is not "vanilla". Detect requires_bff after clone so we can
# auto-enable the BFF before its block runs.
for _i in "${!DOMAIN_NAMES[@]}"; do
  _d_name="${DOMAIN_NAMES[$_i]}"
  _d_template="${DOMAIN_TEMPLATES[$_i]}"
  _d_dir="${DOMAIN_DIRS_PLANNED[$_i]}"
  _d_label="Domain ${_d_name}"

  if [ "$_d_template" = "vanilla" ]; then
    clone_project "$DOMAIN_TEMPLATE_REPO" "$_d_dir" "$_d_label (vanilla)"
  else
    _repo_path="$(template_repo_for_slug "$_d_template")" \
      || die "Template '${_d_template}' no encontrado en templates.json. Revisa el catálogo o usa 'vanilla'."
    _repo_url="https://github.com/${_repo_path}.git"
    clone_project "$_repo_url" "$_d_dir" "$_d_label (template=${_d_template})"
  fi

  _d_abs="$(cd "$_d_dir" && pwd)"
  DOMAIN_DIRS+=("$_d_abs")

  # Read requires_bff from the cloned template.json. The flag is read once here
  # so the BFF auto-enable decision is made before any clone/init happens for
  # the BFF itself.
  _d_requires_bff="$(template_field_bool "${_d_abs}/template.json" requires_bff)"
  DOMAIN_REQUIRES_BFF+=("$_d_requires_bff")
  if [ "$_d_requires_bff" = "true" ] && [ "$INCLUDE_BFF" != true ]; then
    print_warn "  Template del domain '${_d_name}' declara requires_bff:true — activando BFF automáticamente."
    INCLUDE_BFF=true
    BFF_PORT="${BFF_PORT:-8088}"
    BFF_ALLOWED_ORIGINS="${BFF_ALLOWED_ORIGINS:-http://localhost:5173,http://localhost:3000}"
    BFF_DIR="${OUTPUT_DIR}${PROJECT_NAME}-bff"
    [[ ! -e "$BFF_DIR" ]] || die "El directorio '${BFF_DIR}' ya existe (auto-activado por requires_bff). Elimínalo o desactiva el template."
  fi
done

if [ "$INCLUDE_BFF" = true ]; then
  clone_project "$BFF_TEMPLATE_REPO" "$BFF_DIR" "BFF"
  BFF_DIR="$(cd "$BFF_DIR" && pwd)"
  BFF_CREATED=true
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
for _i in "${!DOMAIN_DIRS[@]}"; do
  init_git "${DOMAIN_DIRS[$_i]}" "${DOMAIN_NAMES[$_i]}"
done
[ "$INCLUDE_BFF" = true ]    && init_git "$BFF_DIR"    "${PROJECT_NAME}-bff"

# =============================================================================
# Derive admin install defaults from PROJECT_NAME when not explicitly set.
# install.sh (ci4-admin-starter) reads these; filling them in here means a
# CI caller only needs to supply DB creds and SA details — not admin branding.
# =============================================================================
: "${CI4_API_NAME:=${PROJECT_NAME}-api}"
: "${CI4_API_GITHUB_URL:=https://github.com/yourusername/${PROJECT_NAME}-api}"
: "${CI4_API_BASE_URL:=http://localhost:8080}"
: "${CI4_APP_NAME:=${PROJECT_NAME} Admin}"
: "${CI4_ADMIN_PORT:=8082}"

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
if [ -n "${CI4_DB_HOST:-}" ]; then
  # Non-interactive mode: pipe answers to every read prompt in init.sh so a
  # fresh GitHub clone (which may predate CI4_DB_* env-var support) still
  # gets the right data. --skip-server suppresses the final "Start server?" prompt.
  _sa_pass="${CI4_SA_PASSWORD:-}"
  {
    printf '%s\n' "${CI4_DB_HOST}"
    printf '%s\n' "${CI4_DB_PORT:-3306}"
    printf '%s\n' "${CI4_DB_USER:-root}"
    printf '%s\n' "${CI4_DB_PASS:-}"
    printf '%s\n' "${CI4_DB_NAME}"
    printf '%s\n' "${CI4_TEST_DB_NAME:-${CI4_DB_NAME}_test}"
    if [ -n "${CI4_SA_EMAIL:-}" ] && [ "${#_sa_pass}" -ge 8 ]; then
      printf 'y\n%s\n%s\n%s\n%s\n' \
        "${CI4_SA_EMAIL}" "${_sa_pass}" \
        "${CI4_SA_FIRST_NAME:-Super}" "${CI4_SA_LAST_NAME:-Admin}"
    else
      printf 'n\n'
    fi
  } | bash init.sh --skip-server
else
  bash init.sh
fi
cd "$SCRIPT_DIR"

# =============================================================================
# Bootstrap del hub + setup de cada domain starter (KICK-001 + TMPL-003/004)
# =============================================================================
# Cuando hay uno o más domains, automatizamos los pasos manuales que cada uno
# normalmente requeriría:
#   1. Registrar TODAS las applications en el hub vía `apps:bootstrap --create-api-key`
#      (consume API-007: emite API_KEY=apk_... y APP_ID=N en stdout).
#   2. Levantar el hub UNA VEZ en background para que todos los init.sh puedan
#      sync-permissions contra él.
#   3. Loginear con el superadmin recién creado para capturar un JWT compartido.
#   4. Para cada domain: ejecutar apply_template() si trae template.json, exportar
#      las coords correspondientes y correr su init.sh --skip-server.
#   5. Apagar el hub.
# Si algo falla a mitad, cleanup_on_error mata HUB_PID y rm -rf todos los dirs.
if [ "$INCLUDE_DOMAIN" = true ]; then
    print_header "Preparando hub para ${#DOMAIN_NAMES[@]} domain app(s)"

    # 1. Registrar cada app + capturar API keys (PRE-1 / API-007)
    DOMAIN_API_KEYS=()
    cd "$API_DIR"
    for _i in "${!DOMAIN_NAMES[@]}"; do
        _d_code="${DOMAIN_APP_CODES[$_i]}"
        _d_template_label="${DOMAIN_TEMPLATES[$_i]}"
        APPS_BOOTSTRAP_OUT=$(php spark apps:bootstrap "$_d_code" \
            --name="${PROJECT_NAME} ${_d_code}" \
            --no-grant-user \
            --create-api-key 2>&1) || die "apps:bootstrap falló para ${_d_code}. Output:\n${APPS_BOOTSTRAP_OUT}"
        _api_key=$(printf '%s' "$APPS_BOOTSTRAP_OUT" | awk -F= '/^API_KEY=/{print $2; exit}' | tr -d '\r')
        [ -n "$_api_key" ] || die "No se obtuvo API_KEY de apps:bootstrap para ${_d_code}. Output:\n${APPS_BOOTSTRAP_OUT}"
        DOMAIN_API_KEYS+=("$_api_key")
        print_ok "Application '${_d_code}' registrada (template=${_d_template_label})"
    done

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

    # 4. Por cada domain: apply_template + export env vars + run init.sh
    for _i in "${!DOMAIN_NAMES[@]}"; do
        _d_name="${DOMAIN_NAMES[$_i]}"
        _d_code="${DOMAIN_APP_CODES[$_i]}"
        _d_port="${DOMAIN_PORTS[$_i]}"
        _d_dir="${DOMAIN_DIRS[$_i]}"
        _d_key="${DOMAIN_API_KEYS[$_i]}"

        print_header "Configurando Domain (${_d_name})"

        # TMPL-004: si el repo trae template.json, validarlo y aplicar
        # (validación + generación de módulos admin). No-op para vanilla.
        apply_template "$_d_dir"

        # Sanitize DB name: replace dashes with underscores (MySQL identifiers)
        _d_db_safe="$(printf '%s' "$_d_name" | tr '-' '_')"
        export CI4_DOMAIN_HUB_URL="http://localhost:8080"
        export CI4_DOMAIN_APP_CODE="$_d_code"
        export CI4_DOMAIN_API_KEY="$_d_key"
        export CI4_DOMAIN_ADMIN_TOKEN="$DOMAIN_ADMIN_TOKEN"
        export CI4_DOMAIN_PORT="$_d_port"
        # DB defaults: misma instancia MySQL que el api-starter, distinta DB por domain
        export CI4_DOMAIN_DB_HOST="${CI4_DB_HOST:-127.0.0.1}"
        export CI4_DOMAIN_DB_PORT="${CI4_DB_PORT:-3306}"
        export CI4_DOMAIN_DB_USER="${CI4_DB_USER:-root}"
        export CI4_DOMAIN_DB_PASS="${CI4_DB_PASS-}"
        export CI4_DOMAIN_DB_NAME="${_d_db_safe}"
        export CI4_DOMAIN_TEST_DB_NAME="${_d_db_safe}_test"

        cd "$_d_dir"
        bash init.sh --skip-server
        cd "$SCRIPT_DIR"
    done

    # 5. Apagar el hub background
    if [ -n "$HUB_PID" ] && kill -0 "$HUB_PID" 2>/dev/null; then
        kill "$HUB_PID" 2>/dev/null || true
        print_ok "Hub detenido (PID ${HUB_PID})"
    fi
    HUB_PID=""
fi

# =============================================================================
# Setup del BFF (BFF-006)
# =============================================================================
# El BFF es un gateway stateless: no necesita registrar app en el hub, ni
# bootstrap, ni DB. Solo lo configuramos con HUB_URL (de la API recién
# creada), DOMAIN_URL (si el domain fue incluido) y BFF_ALLOWED_ORIGINS
# (CSV), y delegamos al init.sh del BFF.
if [ "$INCLUDE_BFF" = true ]; then
    print_header "Configurando BFF (${PROJECT_NAME}-bff)"

    export BFF_HUB_URL="http://localhost:8080"
    # BFF_DOMAIN_URL is single-valued in the BFF config today: when multiple
    # domains are scaffolded, point it at the first one. Operators with N
    # domains will need to extend HubClient / DomainClient wiring manually for
    # the additional domains — flagged in the summary below.
    if [ ${#DOMAIN_PORTS[@]} -gt 0 ]; then
        export BFF_DOMAIN_URL="http://localhost:${DOMAIN_PORTS[0]}"
    else
        export BFF_DOMAIN_URL=""
    fi
    export BFF_ALLOWED_ORIGINS="$BFF_ALLOWED_ORIGINS"
    export BFF_PORT
    export BFF_APP_CODE="${PROJECT_NAME}-bff"

    cd "$BFF_DIR"
    # init.sh reads BFF_* env vars; --skip-server suppresses the final prompt.
    bash init.sh --skip-server
    cd "$SCRIPT_DIR"
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
if [ -n "${CI4_DB_HOST:-}" ]; then
  # Non-interactive: install.sh already reads CI4_API_NAME / CI4_API_BASE_URL /
  # CI4_APP_NAME / etc. via env vars; only the final "¿Continuar?" confirm still
  # needs a piped answer.
  printf 'y\n' | bash install.sh
else
  bash install.sh
fi
cd "$SCRIPT_DIR"

# =============================================================================
# Resumen final
# =============================================================================
print_header "Proyecto listo"
echo ""
echo -e "  ${BOLD}Proyectos creados:${RESET}"
echo -e "    ${CYAN}${API_DIR}${RESET}"
echo -e "    ${CYAN}${ADMIN_DIR}${RESET}"
for _i in "${!DOMAIN_DIRS[@]}"; do
  echo -e "    ${CYAN}${DOMAIN_DIRS[$_i]}${RESET}  (template=${DOMAIN_TEMPLATES[$_i]})"
done
[ "$INCLUDE_BFF" = true ] && echo -e "    ${CYAN}${BFF_DIR}${RESET}"
echo ""
echo -e "  ${BOLD}Para levantar el entorno de desarrollo:${RESET}"
echo ""

# Terminal counter — Terminal 1 always goes to the API.
_term=1
echo -e "  ${YELLOW}Terminal ${_term} — API (hub):${RESET}"
echo -e "    cd ${API_DIR}"
echo -e "    php spark serve"
_term=$((_term + 1))

echo ""
echo -e "  ${YELLOW}Terminal ${_term} — Admin:${RESET}"
echo -e "    cd ${ADMIN_DIR}"
echo -e "    php spark serve --port 8082"
_term=$((_term + 1))

echo ""
echo -e "  ${YELLOW}Terminal ${_term} — CSS (Tailwind watcher):${RESET}"
echo -e "    cd ${ADMIN_DIR}"
echo -e "    npm run dev:css"
_term=$((_term + 1))

for _i in "${!DOMAIN_DIRS[@]}"; do
echo ""
echo -e "  ${YELLOW}Terminal ${_term} — Domain ${DOMAIN_NAMES[$_i]}:${RESET}"
echo -e "    cd ${DOMAIN_DIRS[$_i]}"
echo -e "    php spark serve --port ${DOMAIN_PORTS[$_i]}"
_term=$((_term + 1))
done

if [ "$INCLUDE_BFF" = true ]; then
echo ""
echo -e "  ${YELLOW}Terminal ${_term} — BFF:${RESET}"
echo -e "    cd ${BFF_DIR}"
echo -e "    php spark serve --port ${BFF_PORT}"
_term=$((_term + 1))
fi

echo ""
echo -e "  ${BOLD}Accede al admin en:${RESET}  ${CYAN}http://localhost:8082${RESET}"
for _i in "${!DOMAIN_DIRS[@]}"; do
  echo -e "  ${BOLD}Domain ${DOMAIN_NAMES[$_i]}:${RESET}      ${CYAN}http://localhost:${DOMAIN_PORTS[$_i]}${RESET}  (app=${DOMAIN_APP_CODES[$_i]}, template=${DOMAIN_TEMPLATES[$_i]})"
done
if [ "$INCLUDE_BFF" = true ]; then
  echo -e "  ${BOLD}BFF en:${RESET}               ${CYAN}http://localhost:${BFF_PORT}${RESET}  (CORS: ${BFF_ALLOWED_ORIGINS})"
  if [ ${#DOMAIN_DIRS[@]} -gt 1 ]; then
    echo -e "  ${YELLOW}Nota:${RESET} el BFF apunta solo al primer domain (${DOMAIN_NAMES[0]}:${DOMAIN_PORTS[0]}). Para usar los demás, extiende HubClient/DomainClient manualmente en ${BFF_DIR}/app/Libraries/."
  fi
fi
echo ""
