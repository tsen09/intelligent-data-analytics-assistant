
#!/usr/bin/env bash

set -Eeuo pipefail

# ============================================================
# Kathy - Environment Setup
# ============================================================

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"

source "$SCRIPT_DIR/lib/common.sh"

cd "$PROJECT_ROOT"

PYTHON_VERSION="3.13"

# ============================================================
# Setup
# ============================================================

setup_environment() {

    print_banner

    printf '  %bEnvironment Setup%b\n' "$BOLD$WHITE" "$RESET"
    printf '  %bPreparing Kathy...%b\n' "$DIM" "$RESET"

    # --------------------------------------------------------
    # 1. Prerequisites
    # --------------------------------------------------------

    print_section "1. Checking prerequisites"

    # Check for curl
    if ! command -v curl &>/dev/null; then
        log_error "curl is not installed."
        log_info "Please install curl using your system package manager and retry."
        return 1
    fi

    log_success "curl is available."

    # Install uv if missing
    if ! command -v uv &>/dev/null; then
        log_warning "uv is not installed."
        log_info "Installing uv using the official Astral installer..."

        if ! curl -LsSf https://astral.sh/uv/install.sh | sh; then
            log_error "Failed to install uv."
            return 1
        fi

        # Update PATH for the current shell session
        export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$PATH"

        if ! command -v uv &>/dev/null; then
            log_error "uv installation could not be verified."
            log_info "Please restart your terminal and run setup again."
            return 1
        fi

        log_success "uv installed successfully."
    else
        log_success "uv is already installed."
    fi

    log_info "Detected version: $(uv --version)"

    # --------------------------------------------------------
    # 2. Project configuration
    # --------------------------------------------------------

    print_section "2. Validating project configuration"

    if [[ ! -f "$PROJECT_ROOT/backend/pyproject.toml" ]]; then
        log_error "backend/pyproject.toml not found."
        log_info "Please ensure the Kathy backend project is configured correctly."
        return 1
    fi

    log_success "Project configuration found."

    # --------------------------------------------------------
    # 3. Python 3.13 installation
    # --------------------------------------------------------

    print_section "3. Checking Python runtime"

    if ! uv python find "$PYTHON_VERSION" &>/dev/null; then
        log_warning "Python $PYTHON_VERSION is not available."
        log_info "Installing Python $PYTHON_VERSION using uv..."

        if ! uv python install "$PYTHON_VERSION"; then
            log_error "Failed to install Python $PYTHON_VERSION."
            return 1
        fi

        log_success "Python $PYTHON_VERSION installed successfully."
    else
        log_success "Python $PYTHON_VERSION is already available."
    fi

    # Resolve the Python interpreter path
    PYTHON_INTERPRETER="$(uv python find "$PYTHON_VERSION")"

    if [[ -z "$PYTHON_INTERPRETER" ]]; then
        log_error "Unable to locate the Python $PYTHON_VERSION interpreter."
        return 1
    fi

    log_info "Using Python interpreter: $PYTHON_INTERPRETER"

    # --------------------------------------------------------
    # 4. Dependencies
    # --------------------------------------------------------

    print_section "4. Installing dependencies"

    cd "$PROJECT_ROOT/backend"

    log_info "Synchronizing project dependencies using uv..."

    if ! uv sync --python "$PYTHON_INTERPRETER" --group dev; then
        log_error "Dependency installation failed."
        log_info "Please review the error messages above and resolve the issue."
        return 1
    fi

    log_success "Dependencies installed successfully."

    # --------------------------------------------------------
    # 5. Verification
    # --------------------------------------------------------

    print_section "5. Verifying installation"

    PYTHON_VERSION_INSTALLED="$(uv run python --version)"

    log_success "Virtual environment: backend/.venv"
    log_success "Runtime: $PYTHON_VERSION_INSTALLED"

    # --------------------------------------------------------
    # 6. Completion
    # --------------------------------------------------------

    printf '\n'
    print_line

    printf '  %b✔ KATHY IS READY!%b\n' "$BOLD$GREEN" "$RESET"
    printf '\n'

    printf '  %bYour development environment has been configured.%b\n' \
        "$WHITE" "$RESET"
    printf '\n'

    printf '  %bNext steps%b\n' "$BOLD$CYAN" "$RESET"
    printf '  %b────────────────────────────────────────────%b\n' \
        "$DIM" "$RESET"

    printf '  %b1.%b Configure environment variables in %b.env%b\n' \
        "$YELLOW" "$RESET" "$BOLD" "$RESET"

    printf '  %b2.%b Start Kathy using %b./kathy.sh run%b\n' \
        "$YELLOW" "$RESET" "$BOLD" "$RESET"

    printf '\n'

    print_footer
}

# ============================================================
# Main
# ============================================================

main() {
    setup_environment "$@"
}

main "$@"
