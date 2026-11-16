#!/usr/bin/env bash

set -Eeuo pipefail

# ============================================================================
# Kathy - Intelligent Data Analytics Assistant
# Application Startup Script
# ============================================================================

# ----------------------------------------------------------------------------
# Project Paths
# ----------------------------------------------------------------------------

PROJECT_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

SCRIPTS_DIR="$PROJECT_ROOT/scripts"
CONFIG_DIR="$PROJECT_ROOT/backend/config"

ENV_FILE="$PROJECT_ROOT/.env"
SETUP_SCRIPT="$SCRIPTS_DIR/setup.sh"

VENV_DIR="$PROJECT_ROOT/backend/.venv"
VENV_PYTHON="$VENV_DIR/bin/python"

# ----------------------------------------------------------------------------
# Shared Terminal Utilities
# ----------------------------------------------------------------------------

source "$SCRIPTS_DIR/lib/common.sh"

# ============================================================================
# Environment Validation & Setup
# ============================================================================

is_setup_complete() {
    [[ -x "$VENV_PYTHON" ]] &&
        "$VENV_PYTHON" -c "import uvicorn" &>/dev/null
}

confirm_setup() {

    printf '\n'
    printf '%bSETUP REQUIRED%b\n' "$YELLOW" "$RESET"
    printf '  Kathy has not been set up yet.\n'
    printf '  You need to configure the project environment before launching it.\n\n'

    if [[ ! -t 0 ]]; then
        log_error "Setup required. Run './kathy.sh setup' first."
        exit 1
    fi

    read -r -p "  Would you like to set up Kathy now? [y/N]: " response

    case "$response" in
        [yY]|[yY][eE][sS])
            printf '\n'
            log_info "Starting Kathy setup..."
            ;;

        *)
            printf '\n'
            log_info "Startup cancelled. Run './kathy.sh setup' when ready."
            exit 0
            ;;
    esac
}

ensure_setup() {

    if is_setup_complete; then
        log_success "Project environment is ready."
        return 0
    fi

    confirm_setup

    if [[ ! -f "$SETUP_SCRIPT" ]]; then
        log_error "Setup script not found: $SETUP_SCRIPT"
        exit 1
    fi

    bash "$SETUP_SCRIPT"

    printf '\n'

    if ! is_setup_complete; then
        log_error "Kathy setup did not complete successfully."
        log_error "Please check the setup logs and try again."
        exit 1
    fi

    log_success "Project environment is ready."
}

# ============================================================================
# Configuration Loading
# ============================================================================

load_toml_exports() {
    local toml_file="$1"

    "$VENV_PYTHON" - "$toml_file" <<'PY'
import shlex
import sys
import tomllib

with open(sys.argv[1], "rb") as f:
    data = tomllib.load(f)

app = data.get("app", {})
db = data.get("database", {})
py = data.get("python", {})

exports = {
    "KATHY_APP_MODULE": app.get("module"),
    "APP_NAME": app.get("name"),
    "APP_DEBUG": str(app["debug"]).lower() if "debug" in app else None,
    "KATHY_HOST": app.get("host"),
    "KATHY_PORT": app.get("port"),
    "DB_DRIVER": db.get("driver"),
    "DB_HOST": db.get("host"),
    "DB_PORT": db.get("port"),
    "DB_NAME": db.get("name"),
    "DB_POOL_SIZE": db.get("pool_size"),
    "DB_MAX_OVERFLOW": db.get("max_overflow"),
    "PYTHONUNBUFFERED": py.get("unbuffered"),
    "PYTHONDONTWRITEBYTECODE": py.get("dont_write_bytecode"),
}

for key, val in exports.items():
    if val is not None:
        print(f"export {key}={shlex.quote(str(val))}")
PY
}

load_configuration() {

    # ------------------------------------------------------------------------
    # Load Base Environment Variables (.env)
    # ------------------------------------------------------------------------

    if [[ ! -f "$ENV_FILE" ]]; then
        log_error ".env file not found: $ENV_FILE"
        log_info "Create one using .env.example in the project root."
        exit 1
    fi

    set -a
    # shellcheck disable=SC1090
    source "$ENV_FILE"
    set +a

    # ------------------------------------------------------------------------
    # Validate Environment
    # ------------------------------------------------------------------------

    if [[ -z "${ENV:-}" ]]; then
        log_error "ENV is not defined in .env."
        exit 1
    fi

    case "$ENV" in
        development|testing|production)
            SETTINGS_FILE="$CONFIG_DIR/${ENV}.toml"
            ;;
        *)
            log_error "Invalid environment: $ENV"
            log_error "Allowed environments: development, testing, production"
            exit 1
            ;;
    esac

    # ------------------------------------------------------------------------
    # Load Environment-Specific TOML Settings
    # ------------------------------------------------------------------------

    if [[ ! -f "$SETTINGS_FILE" ]]; then
        log_error "Configuration file not found: $SETTINGS_FILE"
        exit 1
    fi

    local toml_exports
    toml_exports="$(load_toml_exports "$SETTINGS_FILE")"
    eval "$toml_exports"

    # ------------------------------------------------------------------------
    # Application Defaults
    # ------------------------------------------------------------------------

    APP_MODULE="${KATHY_APP_MODULE:-src.main:app}"
    HOST="${KATHY_HOST:-127.0.0.1}"
    PORT="${KATHY_PORT:-8000}"
}

# ============================================================================
# Application Startup
# ============================================================================

start_kathy() {

    local uvicorn_args=(
        "$APP_MODULE"
        --host "$HOST"
        --port "$PORT"
    )

    if [[ "$ENV" == "development" || "${APP_DEBUG:-false}" == "true" ]]; then
        uvicorn_args+=(--reload)
    fi

    printf '\n'
    log_info "Launching Kathy..."

    printf '\n'
    printf '%bAPPLICATION CONFIGURATION%b\n' "$BOLD" "$RESET"
    printf '  Application : %s\n' "${APP_NAME:-Kathy}"
    printf '  Environment : %s\n' "$ENV"
    printf '  Debug Mode  : %s\n' "${APP_DEBUG:-false}"
    printf '  Host        : %s\n' "$HOST"
    printf '  Port        : %s\n' "$PORT"
    printf '  Entry point : %s\n\n' "$APP_MODULE"

    cd "$PROJECT_ROOT/backend"

    exec uv run \
        --project "$PROJECT_ROOT/backend" \
        --no-sync \
        python -m uvicorn "${uvicorn_args[@]}"
}

# ============================================================================
# Main
# ============================================================================

main() {

    print_banner

    if ! command -v uv &>/dev/null; then
        log_error "uv is not installed or not available in PATH."
        exit 1
    fi

    ensure_setup

    load_configuration

    start_kathy
}

main "$@"