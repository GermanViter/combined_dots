#!/usr/bin/env bash

# setup_symlinks.sh - Automate symlinking of dotfiles using GNU Stow
#
# Usage:
#   ./setup_symlinks.sh [options] [package ...]
#
# Examples:
#   ./setup_symlinks.sh                  Stow all detected packages
#   ./setup_symlinks.sh --dry-run        Simulate without modifying anything
#   ./setup_symlinks.sh --unlink         Unstow (remove) dotfiles symlinks
#   ./setup_symlinks.sh --adopt          Adopt existing files into the repo
#   ./setup_symlinks.sh --check          Show stow packages and their link status
#   ./setup_symlinks.sh zsh kitty        Only stow the zsh and kitty packages

set -euo pipefail

# ── Path Resolution ────────────────────────────────────────────────────────────
SOURCE="${BASH_SOURCE[0]}"
while [ -h "$SOURCE" ]; do
    DIR="$(cd -P "$(dirname "$SOURCE")" && pwd)"
    SOURCE="$(readlink "$SOURCE")"
    [[ $SOURCE != /* ]] && SOURCE="$DIR/$SOURCE"
done
SCRIPT_DIR="$(cd -P "$(dirname "$SOURCE")" && pwd)"
COMBINED_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
PARENT_DIR="$(cd "$COMBINED_DIR/.." && pwd)"

# Check if running within a parent dotfiles repository
IS_SUBMODULE=false
if [ -d "$PARENT_DIR" ] && [ "$PARENT_DIR" != "$COMBINED_DIR" ] && [[ -f "$PARENT_DIR/.gitmodules" || -d "$PARENT_DIR/.git" ]]; then
    IS_SUBMODULE=true
    DOTFILES_DIR="$PARENT_DIR"
else
    DOTFILES_DIR="$COMBINED_DIR"
fi

# ── Colors ─────────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
RESET='\033[0m'

log_info()    { echo -e "${BLUE}  →${RESET} $*"; }
log_success() { echo -e "${GREEN}  ✓${RESET} $*"; }
log_warn()    { echo -e "${YELLOW}  !${RESET} $*"; }
log_error()   { echo -e "${RED}  ✗${RESET} $*" >&2; }
log_step()    { echo -e "\n${BOLD}${CYAN}=== $* ===${RESET}"; }

DRY_RUN=false
UNLINK=false
ADOPT=false
CHECK_ONLY=false
TARGET_PACKAGES=()

show_help() {
    echo -e "${BOLD}setup_symlinks.sh${RESET} - Symlink dotfiles with GNU Stow"
    echo ""
    echo -e "${BOLD}Usage:${RESET}"
    echo "  $0 [options] [package ...]"
    echo ""
    echo -e "${BOLD}Options:${RESET}"
    echo "  -n, --dry-run          Simulate symlink actions without modifying files"
    echo "  -u, --unlink           Remove symlinks (unstow packages)"
    echo "  -a, --adopt            Adopt existing files into the repository while stowing"
    echo "  -c, --check            Show stow packages and whether they are linked"
    echo "  -h, --help             Show this help message"
    echo ""
    echo -e "${BOLD}Accepted for compatibility with install.sh:${RESET}"
    echo "  -s, --symlinks-only    No-op (this script only handles symlinks)"
    echo "      --all              No-op (dependency install is handled by install.sh)"
    echo "  -d, --deps-only        Exits immediately; dependencies are install.sh's job"
    echo ""
    echo -e "${BOLD}Packages:${RESET}"
    echo "  Optional name(s) of specific packages to stow or unstow (e.g. zsh nvim kitty)."
    echo "  If omitted, all detected packages are processed."
    echo ""
    echo -e "${BOLD}Examples:${RESET}"
    echo "  $0                     Stow every detected package"
    echo "  $0 --dry-run           Preview what would happen"
    echo "  $0 --unlink zsh        Remove only the zsh symlinks"
    echo "  $0 --adopt nvim        Pull existing ~/.config/nvim files into the repo"
}

# ── Arguments ──────────────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
    case "$1" in
    -n|--dry-run)
        DRY_RUN=true
        shift
        ;;
    -u|--unlink)
        UNLINK=true
        shift
        ;;
    -a|--adopt)
        ADOPT=true
        shift
        ;;
    -c|--check)
        CHECK_ONLY=true
        shift
        ;;
    -s|--symlinks-only|--links-only|--all)
        # Accepted so the same command line works for install.sh and this script.
        shift
        ;;
    -d|--deps-only)
        log_warn "--deps-only has no effect here; dependencies are installed by install.sh."
        exit 0
        ;;
    -h|--help)
        show_help
        exit 0
        ;;
    -*)
        log_error "Unknown option: $1"
        echo "Run '$0 --help' for options."
        exit 1
        ;;
    *)
        TARGET_PACKAGES+=("${1%/}")
        shift
        ;;
    esac
done

if [ "$DRY_RUN" = true ]; then
    echo -e "${YELLOW}[DRY RUN — no files will be modified]${RESET}"
fi
if [ "$UNLINK" = true ]; then
    echo -e "${CYAN}[UNLINK MODE — removing symlinks]${RESET}"
fi
if [ "$ADOPT" = true ] && [ "$UNLINK" = true ]; then
    log_warn "--adopt is ignored when unlinking."
    ADOPT=false
fi

# ── Dependency Check ───────────────────────────────────────────────────────────
if ! command -v stow &>/dev/null; then
    log_error "GNU Stow is not installed. Please install it using your package manager:"
    echo "  Arch Linux/CachyOS: sudo pacman -S stow"
    echo "  Debian/Ubuntu:      sudo apt install stow"
    echo "  Fedora:             sudo dnf install stow"
    echo "  macOS:              brew install stow"
    exit 1
fi

# ── Package Discovery ──────────────────────────────────────────────────────────
EXCLUDE=("scripts" "assets" "gemini" "combined_dots" "brain" "scratch")

is_excluded() {
    local item="$1"
    for ex in "${EXCLUDE[@]}"; do
        [[ "$item" == "$ex" ]] && return 0
    done
    return 1
}

discover_packages() {
    local base="$1"
    local dir name
    for dir in "$base"/*/; do
        [ -d "$dir" ] || continue
        name=$(basename "$dir")
        [[ "$name" == .* ]] && continue
        is_excluded "$name" && continue
        echo "$name"
    done
}

root_packages=()
combined_packages=()

if [ ${#TARGET_PACKAGES[@]} -gt 0 ]; then
    # Explicit packages: resolve each one to the directory that actually contains it.
    for pkg in "${TARGET_PACKAGES[@]}"; do
        if [ -d "$COMBINED_DIR/$pkg" ]; then
            combined_packages+=("$pkg")
        elif [ "$IS_SUBMODULE" = true ] && [ -d "$DOTFILES_DIR/$pkg" ]; then
            root_packages+=("$pkg")
        else
            log_error "Package not found: $pkg"
            echo "  Looked in: $COMBINED_DIR"
            [ "$IS_SUBMODULE" = true ] && echo "         and: $DOTFILES_DIR"
            echo "Run '$0 --check' to list available packages."
            exit 1
        fi
    done
else
    if [ "$IS_SUBMODULE" = true ]; then
        while IFS= read -r name; do
            [ -n "$name" ] && root_packages+=("$name")
        done < <(discover_packages "$DOTFILES_DIR")
    fi
    while IFS= read -r name; do
        [ -n "$name" ] && combined_packages+=("$name")
    done < <(discover_packages "$COMBINED_DIR")
fi

# ── Status Check ───────────────────────────────────────────────────────────────
# Reports how many of a package's files are currently symlinked into $HOME.
package_link_status() {
    local pkgdir="$1"
    local total=0 linked=0
    local file rel target

    while IFS= read -r file; do
        rel="${file#"$pkgdir"/}"
        total=$((total + 1))
        target="$HOME/$rel"
        # The target may be reached through a folded directory symlink (stow links
        # ~/.config itself rather than each file), so compare resolved paths rather
        # than requiring the target itself to be a symlink.
        if [ -e "$target" ] && [ "$(readlink -f "$target" 2>/dev/null)" = "$(readlink -f "$file" 2>/dev/null)" ]; then
            linked=$((linked + 1))
        fi
    done < <(find "$pkgdir" -type f -o -type l 2>/dev/null)

    if [ "$total" -eq 0 ]; then
        echo -e "${YELLOW}empty${RESET}"
    elif [ "$linked" -eq 0 ]; then
        echo -e "${RED}not linked${RESET}"
    elif [ "$linked" -eq "$total" ]; then
        echo -e "${GREEN}linked${RESET} ($linked/$total)"
    else
        echo -e "${YELLOW}partial${RESET} ($linked/$total)"
    fi
}

run_status_check() {
    log_step "Dotfiles Stow Packages"

    if [ "$IS_SUBMODULE" = true ] && [ ${#root_packages[@]} -gt 0 ]; then
        echo -e "${BOLD}Root Packages ($DOTFILES_DIR):${RESET}"
        for pkg in "${root_packages[@]}"; do
            echo -e "  ${BLUE}•${RESET} $(printf '%-14s' "$pkg") $(package_link_status "$DOTFILES_DIR/$pkg")"
        done
        echo ""
    fi

    if [ ${#combined_packages[@]} -gt 0 ]; then
        echo -e "${BOLD}Combined Packages ($COMBINED_DIR):${RESET}"
        for pkg in "${combined_packages[@]}"; do
            echo -e "  ${BLUE}•${RESET} $(printf '%-14s' "$pkg") $(package_link_status "$COMBINED_DIR/$pkg")"
        done
        echo ""
    fi

    if [ ${#root_packages[@]} -eq 0 ] && [ ${#combined_packages[@]} -eq 0 ]; then
        log_warn "No stow packages found."
    fi
}

if [ "$CHECK_ONLY" = true ]; then
    run_status_check
    exit 0
fi

# ── Stow Flags ─────────────────────────────────────────────────────────────────
STOW_FLAGS=(-v -t "$HOME")
[ "$DRY_RUN" = true ] && STOW_FLAGS+=(-n)
[ "$ADOPT" = true ] && STOW_FLAGS+=(--adopt)

if [ "$UNLINK" = true ]; then
    STOW_FLAGS+=(-D)
    ACTION_DESC="unstow"
else
    STOW_FLAGS+=(-S)
    ACTION_DESC="stow"
fi

log_step "Symlinking Dotfiles with GNU Stow"

if [ ${#root_packages[@]} -gt 0 ]; then
    echo -e "${BLUE}Root packages to ${ACTION_DESC}:${RESET} ${root_packages[*]}"
fi
if [ ${#combined_packages[@]} -gt 0 ]; then
    echo -e "${BLUE}Combined packages to ${ACTION_DESC}:${RESET} ${combined_packages[*]}"
fi
if [ ${#root_packages[@]} -eq 0 ] && [ ${#combined_packages[@]} -eq 0 ]; then
    log_warn "No packages to ${ACTION_DESC}. Nothing to do."
    exit 0
fi
echo ""

FAILED=()

stow_package() {
    local base="$1" pkg="$2" label="$3"
    if stow -d "$base" "${STOW_FLAGS[@]}" "$pkg"; then
        return 0
    fi
    FAILED+=("$label")
    if [ "$UNLINK" = true ]; then
        log_error "Failed to unstow $label"
    else
        log_error "Failed to stow $label. Check for existing files (try --adopt)."
    fi
    return 0
}

for pkg in ${root_packages[@]+"${root_packages[@]}"}; do
    stow_package "$DOTFILES_DIR" "$pkg" "$pkg"
done

for pkg in ${combined_packages[@]+"${combined_packages[@]}"}; do
    stow_package "$COMBINED_DIR" "$pkg" "combined_dots/$pkg"
done

echo ""
if [ ${#FAILED[@]} -gt 0 ]; then
    log_error "${ACTION_DESC} finished with errors: ${FAILED[*]}"
    exit 1
fi

if [ "$UNLINK" = true ]; then
    log_success "Unlink complete!"
else
    log_success "Stow complete!"
    if [ "$DRY_RUN" = true ]; then
        echo -e "${YELLOW}(Dry-run mode — run without --dry-run to apply)${RESET}"
    fi
fi

exit 0
