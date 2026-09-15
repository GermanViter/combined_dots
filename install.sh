#!/usr/bin/env bash

# install.sh - Unified installer for dotfiles dependencies and GNU Stow symlinks
#
# Usage:
#   ./install.sh [options] [package ...]
#
# Examples:
#   ./install.sh                     Install core dependencies and stow all dotfiles
#   ./install.sh --dry-run           Simulate dependency installs and symlink actions
#   ./install.sh --deps-only         Only install dependencies (stow, fzf, eza, etc.)
#   ./install.sh --symlinks-only     Only create symlinks using GNU Stow
#   ./install.sh --all               Install extended packages (includes nvim, kitty, tmux)
#   ./install.sh --check             Display status of dependencies and packages
#   ./install.sh --unlink            Unstow (remove) dotfiles symlinks
#   ./install.sh --adopt             Adopt existing files into the dotfiles repo
#   ./install.sh zsh kitty           Install dependencies and stow only zsh and kitty

set -euo pipefail

# ── Path Resolution ────────────────────────────────────────────────────────────
SOURCE="${BASH_SOURCE[0]}"
while [ -h "$SOURCE" ]; do
    DIR="$(cd -P "$(dirname "$SOURCE")" && pwd)"
    SOURCE="$(readlink "$SOURCE")"
    [[ $SOURCE != /* ]] && SOURCE="$DIR/$SOURCE"
done
SCRIPT_DIR="$(cd -P "$(dirname "$SOURCE")" && pwd)"

if [ "$(basename "$SCRIPT_DIR")" = "scripts" ]; then
    COMBINED_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
elif [ -d "$SCRIPT_DIR/combined_dots" ]; then
    COMBINED_DIR="$SCRIPT_DIR/combined_dots"
else
    COMBINED_DIR="$SCRIPT_DIR"
fi
PARENT_DIR="$(cd "$COMBINED_DIR/.." && pwd)"

IS_SUBMODULE=false
if [ -d "$PARENT_DIR" ] && [ "$PARENT_DIR" != "$COMBINED_DIR" ] && [[ -f "$PARENT_DIR/.gitmodules" || -d "$PARENT_DIR/.git" ]]; then
    IS_SUBMODULE=true
    DOTFILES_DIR="$PARENT_DIR"
else
    DOTFILES_DIR="$COMBINED_DIR"
fi

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
DEPS_ONLY=false
SYMLINKS_ONLY=false
INSTALL_ALL=false
CHECK_ONLY=false
TARGET_PACKAGES=()

show_help() {
    echo -e "${BOLD}install.sh${RESET} - Unified installer for dotfiles dependencies and GNU Stow symlinks"
    echo ""
    echo -e "${BOLD}Usage:${RESET}"
    echo "  $0 [options] [package ...]"
    echo ""
    echo -e "${BOLD}Options:${RESET}"
    echo "  -n, --dry-run          Simulate installation and symlinks without modifying files"
    echo "  -d, --deps-only        Only install dependencies (skip symlinks)"
    echo "  -s, --symlinks-only    Only create symlinks using GNU Stow (skip dependency install)"
    echo "  -u, --unlink           Remove symlinks (unstow packages)"
    echo "  -a, --adopt            Adopt existing files into the repository during stowing"
    echo "      --all              Include extended tools (neovim, kitty, tmux, git, zsh)"
    echo "  -c, --check            Check status of dependencies and packages"
    echo "  -h, --help             Show this help message"
    echo ""
    echo -e "${BOLD}Packages:${RESET}"
    echo "  Optional name(s) of specific packages to stow or unstow (e.g. zsh nvim kitty)."
    echo "  If omitted, all detected packages are processed."
    echo ""
    echo -e "${BOLD}Examples:${RESET}"
    echo "  $0                     Full install (core dependencies + symlinks)"
    echo "  $0 --dry-run           Preview what would happen"
    echo "  $0 --deps-only         Install stow, fzf, eza, bat, zoxide, starship, fastfetch"
    echo "  $0 --symlinks-only     Link dotfiles without installing packages"
    echo "  $0 --all               Install full suite of CLI tools and GUI terminal apps"
    echo "  $0 --check             Inspect installed tools and available stow packages"
    echo "  $0 zsh                 Only stow zsh configuration"
}

while [[ $# -gt 0 ]]; do
    case "$1" in
    -n|--dry-run)
        DRY_RUN=true
        shift
        ;;
    -d|--deps-only)
        DEPS_ONLY=true
        shift
        ;;
    -s|--symlinks-only|--links-only)
        SYMLINKS_ONLY=true
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
    --all)
        INSTALL_ALL=true
        shift
        ;;
    -c|--check)
        CHECK_ONLY=true
        shift
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
        TARGET_PACKAGES+=("$1")
        shift
        ;;
    esac
done

if [ "$DRY_RUN" = true ]; then
    echo -e "${YELLOW}[DRY RUN — no files or packages will be modified]${RESET}"
fi

CORE_TOOLS=("stow" "fzf" "eza" "bat" "zoxide" "starship" "fastfetch")

# Extended tools configured in the repo
EXTENDED_TOOLS=("tmux" "neovim" "kitty" "git" "zsh")

is_tool_installed() {
    local tool="$1"
    case "$tool" in
    bat)
        command -v bat &>/dev/null || command -v batcat &>/dev/null
        ;;
    neovim)
        command -v nvim &>/dev/null || command -v neovim &>/dev/null
        ;;
    *)
        command -v "$tool" &>/dev/null
        ;;
    esac
}

get_tool_path() {
    local tool="$1"
    case "$tool" in
    bat)
        command -v bat 2>/dev/null || command -v batcat 2>/dev/null || echo "not installed"
        ;;
    neovim)
        command -v nvim 2>/dev/null || command -v neovim 2>/dev/null || echo "not installed"
        ;;
    *)
        command -v "$tool" 2>/dev/null || echo "not installed"
        ;;
    esac
}

detect_package_manager() {
    if command -v pacman &>/dev/null; then
        echo "pacman"
    elif command -v apt-get &>/dev/null || command -v apt &>/dev/null; then
        echo "apt"
    elif command -v dnf &>/dev/null; then
        echo "dnf"
    elif command -v zypper &>/dev/null; then
        echo "zypper"
    elif command -v brew &>/dev/null; then
        echo "brew"
    else
        echo "unknown"
    fi
}

run_elevated() {
    if [ "$EUID" -eq 0 ]; then
        "$@"
    elif command -v sudo &>/dev/null; then
        sudo "$@"
    else
        log_error "Root privileges or sudo required to run: $*"
        exit 1
    fi
}

run_status_check() {
    log_step "Dependency Status Check"
    echo -e "${BOLD}Core Dependencies:${RESET}"
    for tool in "${CORE_TOOLS[@]}"; do
        if is_tool_installed "$tool"; then
            echo -e "  ${GREEN}✓${RESET} $(printf '%-12s' "$tool") [$(get_tool_path "$tool")]"
        else
            echo -e "  ${RED}✗${RESET} $(printf '%-12s' "$tool") [not installed]"
        fi
    done

    echo -e "\n${BOLD}Extended Tools:${RESET}"
    for tool in "${EXTENDED_TOOLS[@]}"; do
        if is_tool_installed "$tool"; then
            echo -e "  ${GREEN}✓${RESET} $(printf '%-12s' "$tool") [$(get_tool_path "$tool")]"
        else
            echo -e "  ${YELLOW}-${RESET} $(printf '%-12s' "$tool") [not installed]"
        fi
    done

    log_step "Dotfiles Stow Packages"
    EXCLUDE=("scripts" "assets" "gemini" "combined_dots" "brain" "scratch")
    is_excluded() {
        local item="$1"
        for ex in "${EXCLUDE[@]}"; do
            [[ "$item" == "$ex" ]] && return 0
        done
        return 1
    }

    if [ "$IS_SUBMODULE" = true ]; then
        echo -e "${BOLD}Root Packages ($DOTFILES_DIR):${RESET}"
        for dir in "$DOTFILES_DIR"/*/; do
            [ -d "$dir" ] || continue
            name=$(basename "$dir")
            [[ "$name" == .* ]] && continue
            is_excluded "$name" && continue
            echo -e "  ${BLUE}•${RESET} $name"
        done
    fi

    echo -e "${BOLD}Combined Packages ($COMBINED_DIR):${RESET}"
    for dir in "$COMBINED_DIR"/*/; do
        [ -d "$dir" ] || continue
        name=$(basename "$dir")
        [[ "$name" == .* ]] && continue
        is_excluded "$name" && continue
        echo -e "  ${BLUE}•${RESET} $name"
    done
    echo ""
}

if [ "$CHECK_ONLY" = true ]; then
    run_status_check
    exit 0
fi

install_dependencies() {
    log_step "Step 1: Checking & Installing Dependencies"

    local tools_to_check=("${CORE_TOOLS[@]}")
    if [ "$INSTALL_ALL" = true ]; then
        tools_to_check+=("${EXTENDED_TOOLS[@]}")
    fi

    local missing_tools=()
    for tool in "${tools_to_check[@]}"; do
        if is_tool_installed "$tool"; then
            log_success "$tool is already installed ($(get_tool_path "$tool"))"
        else
            missing_tools+=("$tool")
        fi
    done

    if [ ${#missing_tools[@]} -eq 0 ]; then
        log_success "All dependencies are satisfied!"
        return 0
    fi

    log_warn "Missing dependencies: ${missing_tools[*]}"

    local pm
    pm=$(detect_package_manager)
    log_info "Detected package manager: $pm"

    case "$pm" in
    pacman)
        local pacman_pkgs=()
        for t in "${missing_tools[@]}"; do
            case "$t" in
            neovim) pacman_pkgs+=("neovim") ;;
            *)      pacman_pkgs+=("$t") ;;
            esac
        done

        if [ "$DRY_RUN" = true ]; then
            log_info "[DRY RUN] Would install: ${pacman_pkgs[*]}"
        else
            log_info "Installing packages with pacman..."
            if command -v yay &>/dev/null && [ "$EUID" -ne 0 ]; then
                yay -S --needed --noconfirm "${pacman_pkgs[@]}"
            elif command -v paru &>/dev/null && [ "$EUID" -ne 0 ]; then
                paru -S --needed --noconfirm "${pacman_pkgs[@]}"
            else
                run_elevated pacman -S --needed --noconfirm "${pacman_pkgs[@]}"
            fi
        fi
        ;;

    apt)
        local apt_pkgs=()
        local post_install_scripts=()

        for t in "${missing_tools[@]}"; do
            case "$t" in
            eza)
                if apt-cache show eza &>/dev/null; then
                    apt_pkgs+=("eza")
                else
                    post_install_scripts+=("install_eza_apt")
                fi
                ;;
            starship)
                if apt-cache show starship &>/dev/null; then
                    apt_pkgs+=("starship")
                else
                    post_install_scripts+=("install_starship_curl")
                fi
                ;;
            fastfetch)
                if apt-cache show fastfetch &>/dev/null; then
                    apt_pkgs+=("fastfetch")
                elif grep -qi ubuntu /etc/os-release 2>/dev/null; then
                    post_install_scripts+=("install_fastfetch_ppa")
                else
                    log_warn "fastfetch is not in your current apt repos. Skipping fastfetch."
                fi
                ;;
            neovim)
                apt_pkgs+=("neovim")
                ;;
            bat)
                apt_pkgs+=("bat")
                post_install_scripts+=("fix_bat_symlink")
                ;;
            *)
                apt_pkgs+=("$t")
                ;;
            esac
        done

        if [ ${#apt_pkgs[@]} -gt 0 ]; then
            if [ "$DRY_RUN" = true ]; then
                log_info "[DRY RUN] Would run: sudo apt-get update && sudo apt-get install -y ${apt_pkgs[*]}"
            else
                log_info "Updating apt index..."
                run_elevated apt-get update
                log_info "Installing packages: ${apt_pkgs[*]}"
                run_elevated apt-get install -y "${apt_pkgs[@]}"
            fi
        fi

        for script in "${post_install_scripts[@]}"; do
            case "$script" in
            install_eza_apt)
                if [ "$DRY_RUN" = true ]; then
                    log_info "[DRY RUN] Would install eza via official apt repository"
                else
                    log_info "Installing eza via official repository..."
                    run_elevated mkdir -p /etc/apt/keyrings
                    wget -qO- https://raw.githubusercontent.com/eza-community/eza/main/deb.asc | run_elevated gpg --dearmor -o /etc/apt/keyrings/gierens.gpg 2>/dev/null || true
                    echo "deb [signed-by=/etc/apt/keyrings/gierens.gpg] http://deb.gierens.de stable main" | run_elevated tee /etc/apt/sources.list.d/gierens.list >/dev/null
                    run_elevated chmod 644 /etc/apt/keyrings/gierens.gpg /etc/apt/sources.list.d/gierens.list 2>/dev/null || true
                    run_elevated apt-get update
                    run_elevated apt-get install -y eza
                fi
                ;;
            install_starship_curl)
                if [ "$DRY_RUN" = true ]; then
                    log_info "[DRY RUN] Would install starship via https://starship.rs/install.sh"
                else
                    log_info "Installing starship via official installer..."
                    curl -sS https://starship.rs/install.sh | sh -s -- -y
                fi
                ;;
            install_fastfetch_ppa)
                if [ "$DRY_RUN" = true ]; then
                    log_info "[DRY RUN] Would install fastfetch via PPA"
                else
                    log_info "Installing fastfetch via PPA..."
                    run_elevated add-apt-repository -y ppa:zhangsongcui3371/fastfetch
                    run_elevated apt-get update
                    run_elevated apt-get install -y fastfetch
                fi
                ;;
            fix_bat_symlink)
                if command -v batcat &>/dev/null && ! command -v bat &>/dev/null; then
                    mkdir -p "$HOME/.local/bin"
                    ln -sf "$(command -v batcat)" "$HOME/.local/bin/bat"
                    log_info "Created symlink: ~/.local/bin/bat -> $(command -v batcat)"
                fi
                ;;
            esac
        done
        ;;

    dnf)
        local dnf_pkgs=()
        for t in "${missing_tools[@]}"; do
            case "$t" in
            neovim) dnf_pkgs+=("neovim") ;;
            *)      dnf_pkgs+=("$t") ;;
            esac
        done

        if [ "$DRY_RUN" = true ]; then
            log_info "[DRY RUN] Would install: ${dnf_pkgs[*]}"
        else
            log_info "Installing packages with dnf: ${dnf_pkgs[*]}"
            run_elevated dnf install -y "${dnf_pkgs[@]}"
        fi
        ;;

    zypper)
        local zypper_pkgs=()
        for t in "${missing_tools[@]}"; do
            case "$t" in
            neovim) zypper_pkgs+=("neovim") ;;
            *)      zypper_pkgs+=("$t") ;;
            esac
        done

        if [ "$DRY_RUN" = true ]; then
            log_info "[DRY RUN] Would install: ${zypper_pkgs[*]}"
        else
            log_info "Installing packages with zypper: ${zypper_pkgs[*]}"
            run_elevated zypper install -y "${zypper_pkgs[@]}"
        fi
        ;;

    brew)
        local brew_pkgs=()
        for t in "${missing_tools[@]}"; do
            case "$t" in
            neovim) brew_pkgs+=("neovim") ;;
            *)      brew_pkgs+=("$t") ;;
            esac
        done

        if [ "$DRY_RUN" = true ]; then
            log_info "[DRY RUN] Would install via brew: ${brew_pkgs[*]}"
        else
            log_info "Installing packages with brew: ${brew_pkgs[*]}"
            brew install "${brew_pkgs[@]}"
        fi
        ;;

    *)
        log_error "Unsupported package manager. Please manually install: ${missing_tools[*]}"
        return 1
        ;;
    esac

    log_success "Dependency installation completed!"
}

setup_symlinks() {
    log_step "Step 2: Symlinking Dotfiles with GNU Stow"

    local symlink_script="$COMBINED_DIR/scripts/setup_symlinks.sh"
    if [ ! -f "$symlink_script" ]; then
        log_error "Symlink script not found at: $symlink_script"
        exit 1
    fi

    local args=()
    if [ "$DRY_RUN" = true ]; then
        args+=("--dry-run")
    fi
    if [ "$UNLINK" = true ]; then
        args+=("--unlink")
    fi
    if [ "$ADOPT" = true ]; then
        args+=("--adopt")
    fi
    if [ ${#TARGET_PACKAGES[@]} -gt 0 ]; then
        args+=("${TARGET_PACKAGES[@]}")
    fi

    bash "$symlink_script" "${args[@]}"
}

if [ "$SYMLINKS_ONLY" = false ] && [ "$UNLINK" = false ]; then
    install_dependencies
fi

if [ "$DEPS_ONLY" = false ]; then
    setup_symlinks
fi

echo ""
if [ "$UNLINK" = true ]; then
    log_success "Dotfiles unlinked successfully!"
elif [ "$DEPS_ONLY" = true ]; then
    log_success "All dependencies installed successfully!"
else
    log_success "Installation & dotfiles setup completed successfully!"
    if [ "$DRY_RUN" = true ]; then
        echo -e "${YELLOW}(Dry-run mode — run without --dry-run to apply changes)${RESET}"
    fi
fi

exit 0
