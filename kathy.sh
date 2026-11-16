#!/usr/bin/env bash

set -Eeuo pipefail

# ============================================================================
# Kathy - Intelligent Data Analytics Assistant
# Main CLI Entry Point
# ============================================================================

# ----------------------------------------------------------------------------
# Project Paths
# ----------------------------------------------------------------------------

PROJECT_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_DIR="$PROJECT_ROOT/scripts"

SETUP_SCRIPT="$SCRIPTS_DIR/setup.sh"
RUN_SCRIPT="$SCRIPTS_DIR/run.sh"
UNINSTALL_SCRIPT="$SCRIPTS_DIR/uninstall.sh"

# ----------------------------------------------------------------------------
# Shared Terminal Utilities
# ----------------------------------------------------------------------------

source "$SCRIPTS_DIR/lib/common.sh"

# ============================================================================
# Help
# ============================================================================

show_help() {
    print_banner

    printf '%bUSAGE%b\n' "$BOLD" "$RESET"
    printf '  ./kathy.sh <command> [options]\n\n'

    printf '%bCOMMANDS%b\n' "$BOLD" "$RESET"
    printf '  %bsetup%b       Set up the project environment\n' "$CYAN" "$RESET"
    printf '  %brun%b         Start Kathy\n' "$CYAN" "$RESET"
    printf '  %bremove%b      Uninstall Kathy\n' "$CYAN" "$RESET"
    printf '  %bhelp%b        Display this help message\n\n' "$CYAN" "$RESET"

    printf '%bOPTIONS%b\n' "$BOLD" "$RESET"
    printf '  %b-s, --setup%b      Set up the project environment\n' "$CYAN" "$RESET"
    printf '  %b-r, --remove%b     Uninstall Kathy\n' "$CYAN" "$RESET"
    printf '  %b-y, --yes%b        Skip uninstallation confirmation\n' "$CYAN" "$RESET"
    printf '  %b-h, --help%b       Display help\n' "$CYAN" "$RESET"
    printf '  %b-v, --version%b    Display version information\n\n' "$CYAN" "$RESET"

    printf '%bEXAMPLES%b\n' "$BOLD" "$RESET"
    printf '  ./kathy.sh setup\n'
    printf '  ./kathy.sh --setup\n'
    printf '  ./kathy.sh -s\n'
    printf '  ./kathy.sh run\n'
    printf '  ./kathy.sh --remove\n'
    printf '  ./kathy.sh -r\n'
    printf '  ./kathy.sh --remove --yes\n\n'

    printf '%bKathy | Intelligent Data Analytics Assistant | MIT License%b\n\n' \
        "$DIM" "$RESET"
}

# ============================================================================
# Command Execution
# ============================================================================

execute_script() {
    local script_path="$1"
    local script_name="$2"

    shift 2

    if [[ ! -f "$script_path" ]]; then
        log_error "Script not found: $script_path"
        exit 1
    fi

    log_info "$script_name"

    exec bash "$script_path" "$@"
}

# ============================================================================
# Uninstallation Confirmation
# ============================================================================

confirm_uninstallation() {
    printf '\n'
    printf '%bWARNING%b\n' "$YELLOW" "$RESET"
    printf '  You are about to uninstall Kathy and remove its local environment.\n'
    printf '  This action cannot be undone.\n\n'

    if [[ ! -t 0 ]]; then
        log_error "Interactive confirmation required. Use --yes to proceed."
        exit 1
    fi

    read -r -p "  Are you sure you want to uninstall Kathy? [y/N]: " response

    case "$response" in
        [yY]|[yY][eE][sS])
            printf '\n'
            log_info "Uninstallation confirmed."
            ;;

        *)
            printf '\n'
            log_info "Uninstallation cancelled."
            exit 0
            ;;
    esac
}

# ============================================================================
# Main
# ============================================================================

main() {
    local command="${1:-help}"
    local skip_confirmation=false

    case "$command" in

        setup|--setup|-s)
            shift
            execute_script "$SETUP_SCRIPT" "Preparing Kathy..." "$@"
            ;;

        run)
            shift
            execute_script "$RUN_SCRIPT" "Launching Kathy..." "$@"
            ;;

        remove|--remove|-r)
            shift

            while [[ $# -gt 0 ]]; do
                case "$1" in
                    --yes|-y)
                        skip_confirmation=true
                        shift
                        ;;

                    *)
                        log_error "Unknown option for remove: $1"
                        exit 1
                        ;;
                esac
            done

            if [[ "$skip_confirmation" == false ]]; then
                confirm_uninstallation
            else
                log_info "Uninstallation confirmation skipped."
            fi

            execute_script "$UNINSTALL_SCRIPT" "Uninstalling Kathy..."
            ;;

        help|--help|-h)
            show_help
            ;;

        --version|-v)
            print_banner

            if [[ ! -f "$PROJECT_ROOT/backend/pyproject.toml" ]]; then
                log_error "pyproject.toml not found in backend directory."
                exit 1
            fi

            if ! command -v python3 &>/dev/null; then
                log_error "Python 3 is required to read the project version."
                exit 1
            fi

            VERSION="$(python3 -c '
import sys
import tomllib

with open(sys.argv[1], "rb") as f:
    print(tomllib.load(f)["project"]["version"])
' "$PROJECT_ROOT/backend/pyproject.toml")"

            printf '  %bKathy v%s%b\n\n' "$BOLD" "$VERSION" "$RESET"
            ;;

        *)
            print_banner

            log_error "Unknown command: $command"

            printf '\n'
            show_help

            exit 1
            ;;

    esac
}

main "$@"
