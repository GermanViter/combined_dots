#!/usr/bin/env bash

# setup_symlinks.sh - Automate symlinking of dotfiles using GNU Stow
# Usage:
#   ./setup_symlinks.sh              → stows packages
#   ./setup_symlinks.sh --dry-run    → simulates without modifying
#   ./setup_symlinks.sh --unlink     → unstows packages
#   ./setup_symlinks.sh --help       → shows help

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
COMBINED_DIR=$(cd "$SCRIPT_DIR/.." && pwd)
PARENT_DIR=$(cd "$COMBINED_DIR/.." && pwd)

# Check if running within a parent dotfiles repository
IS_SUBMODULE=false
if [ -d "$PARENT_DIR" ] && [ "$PARENT_DIR" != "$COMBINED_DIR" ] && [ -f "$PARENT_DIR/.gitmodules" -o -d "$PARENT_DIR/.git" ]; then
    IS_SUBMODULE=true
    DOTFILES_DIR="$PARENT_DIR"
else
    DOTFILES_DIR="$COMBINED_DIR"
fi

DRY_RUN=false
UNLINK=false

# ── Colors ───────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
RESET='\033[0m'

log_info() { echo -e "${BLUE}  →${RESET} $*"; }
log_success() { echo -e "${GREEN}  ✓${RESET} $*"; }
log_error() { echo -e "${RED}  ✗${RESET} $*" >&2; }

# ── Arguments ──────────────────────────────────────────────────────────────────
for arg in "$@"; do
    case $arg in
    --dry-run)
        DRY_RUN=true
        echo -e "${YELLOW}[DRY RUN — no files will be modified]${RESET}\n"
        ;;
    --unlink)
        UNLINK=true
        echo -e "${CYAN}[UNLINK MODE — removing symlinks]${RESET}\n"
        ;;
    --help)
        echo "Usage: $0 [--dry-run | --unlink]"
        echo ""
        echo "  (no arguments)    Create symlinks using GNU Stow"
        echo "  --dry-run         Simulate the process"
        echo "  --unlink          Remove symlinks (unstow)"
        echo "  --help            Show this help"
        exit 0
        ;;
    *)
        log_error "Unknown argument: $arg"
        echo "Run '$0 --help' for options."
        exit 1
        ;;
    esac
done

# ── Dependency Check ──────────────────────────────────────────────────────────
if ! command -v stow &>/dev/null; then
    log_error "GNU Stow is not installed. Please install it using your package manager:"
    echo "  Arch Linux/CachyOS: sudo pacman -S stow"
    echo "  Debian/Ubuntu:      sudo apt install stow"
    echo "  Fedora:             sudo dnf install stow"
    exit 1
fi

# ── Stow Packages ─────────────────────────────────────────────────────────────
# Packages to exclude (not meant for stowing)
EXCLUDE=("scripts" "assets" "gemini" "combined_dots")

# Collect root packages if within parent dotfiles repository
root_packages=()
if [ "$IS_SUBMODULE" = true ]; then
    for dir in "$DOTFILES_DIR"/*/; do
        [ -d "$dir" ] || continue
        name=$(basename "$dir")
        [[ " ${EXCLUDE[@]} " =~ " ${name} " ]] && continue
        [[ "$name" == .* ]] && continue
        root_packages+=("$name")
    done
fi

# Collect combined_dots packages
combined_packages=()
for dir in "$COMBINED_DIR"/*/; do
    [ -d "$dir" ] || continue
    name=$(basename "$dir")
    [[ " ${EXCLUDE[@]} " =~ " ${name} " ]] && continue
    [[ "$name" == .* ]] && continue
    combined_packages+=("$name")
done

STOW_FLAGS="-v -t $HOME"
if [ "$DRY_RUN" = true ]; then
    STOW_FLAGS+=" -n"
fi

if [ "$UNLINK" = true ]; then
    STOW_FLAGS+=" -D"
    ACTION_DESC="unstow"
else
    STOW_FLAGS+=" -S"
    ACTION_DESC="stow"
fi

if [ "$IS_SUBMODULE" = true ] && [ ${#root_packages[@]} -gt 0 ]; then
    echo -e "${BLUE}Root packages to ${ACTION_DESC}:${RESET} ${root_packages[*]}"
fi
if [ ${#combined_packages[@]} -gt 0 ]; then
    echo -e "${BLUE}Combined packages to ${ACTION_DESC}:${RESET} ${combined_packages[*]}"
fi
echo ""

# Stow / Unstow root packages
if [ "$IS_SUBMODULE" = true ]; then
    for pkg in "${root_packages[@]}"; do
        if [ "$UNLINK" = true ]; then
            stow -d "$DOTFILES_DIR" $STOW_FLAGS "$pkg" || log_error "Failed to unstow $pkg"
        else
            stow -d "$DOTFILES_DIR" $STOW_FLAGS "$pkg" || log_error "Failed to stow $pkg. Check for existing files."
        fi
    done
fi

# Stow / Unstow combined_dots packages
for pkg in "${combined_packages[@]}"; do
    if [ "$UNLINK" = true ]; then
        stow -d "$COMBINED_DIR" $STOW_FLAGS "$pkg" || log_error "Failed to unstow combined_dots/$pkg"
    else
        stow -d "$COMBINED_DIR" $STOW_FLAGS "$pkg" || log_error "Failed to stow combined_dots/$pkg. Check for existing files."
    fi
done

echo ""
if [ "$UNLINK" = true ]; then
    log_success "Unlink complete!"
else
    log_success "Stow complete!"
    if [ "$DRY_RUN" = true ]; then
        echo -e "${YELLOW}(Dry-run mode — run without --dry-run to apply)${RESET}"
    fi
fi

exit 0
