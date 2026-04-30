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
while [ $# -gt 0 ]; do
  case $1 in
    --yes|-y) AUTO_YES=true; shift ;;
    --help|-h)
      printf "Usage: bash new-project.sh [--yes|-y]\n\n"
      printf "Options:\n"
      printf "  --yes, -y   Auto-confirm the '¿Continuar?' prompt\n"
      printf "  --help      Show this help\n"
      exit 0
      ;;
    *)
      print_err "Unknown option: $1"
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

# -----------------------------------------------------------------------------
# Cleanup: removes only directories THIS SCRIPT created on unexpected failure.
# Tracks what was actually created to avoid deleting pre-existing directories.
# -----------------------------------------------------------------------------
API_DIR=""
ADMIN_DIR=""
API_CREATED=false
ADMIN_CREATED=false

cleanup_on_error() {
    local exit_code=$?
    if [ $exit_code -ne 0 ]; then
        echo ""
        print_err "El script falló (código $exit_code). Limpiando directorios creados..."
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
echo -e "${BOLD}${CYAN}║          CI4 Starter Kit — Nuevo Proyecto                    ║${RESET}"
echo -e "${BOLD}${CYAN}╚══════════════════════════════════════════════════════════════╝${RESET}"
echo ""
echo "  Crea dos proyectos independientes (API + Admin) a partir"
echo "  del kit, configura entornos, base de datos y superadmin."
echo ""
echo "  Presiona Ctrl+C en cualquier momento para cancelar."
echo ""

# =============================================================================
# Prerequisitos mínimos del orquestador
# =============================================================================
print_header "Verificando prerequisitos"
require_cmd git
print_ok "git encontrado"

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

API_DIR="${OUTPUT_DIR}${PROJECT_NAME}-api"
ADMIN_DIR="${OUTPUT_DIR}${PROJECT_NAME}-admin"

echo ""
echo -e "  ${BOLD}Se crearán:${RESET}"
echo -e "    API:   ${CYAN}${API_DIR}${RESET}"
echo -e "    Admin: ${CYAN}${ADMIN_DIR}${RESET}"
echo ""

# Verificar que los directorios destino no existan
[[ ! -e "$API_DIR" ]]   || die "El directorio '${API_DIR}' ya existe. Elige otro nombre o elimínalo."
[[ ! -e "$ADMIN_DIR" ]] || die "El directorio '${ADMIN_DIR}' ya existe. Elige otro nombre o elimínalo."

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
API_CREATED=true
clone_project "$ADMIN_TEMPLATE_REPO" "$ADMIN_DIR" "Admin"
ADMIN_CREATED=true

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
        git add . -q
        if git commit -q -m "Initial commit from ci4-starter-kit" 2>/dev/null; then
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

cd "$API_DIR"
bash init.sh
cd "$SCRIPT_DIR"

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
echo ""
echo -e "  ${BOLD}Para levantar el entorno de desarrollo:${RESET}"
echo ""
echo -e "  ${YELLOW}Terminal 1 — API:${RESET}"
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
echo ""
echo -e "  ${BOLD}Accede en:${RESET}  ${CYAN}http://localhost:8082${RESET}"
echo ""
