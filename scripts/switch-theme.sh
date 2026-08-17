#!/usr/bin/env bash

# switch-theme.sh - Robust theme switcher for Linux dotfiles
# Usage:
#   ./switch-theme.sh [main|moon|dawn|catppuccin|black|gruvbox]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMBINED_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
PARENT_DIR="$(cd "$COMBINED_DIR/.." && pwd)"

THEME="${1:-}"

# Helper function to find first existing directory from candidate paths
find_config_dir() {
    for dir in "$@"; do
        if [ -d "$dir" ]; then
            echo "$dir"
            return 0
        fi
    done
    return 1
}

# Available Themes: main, moon, dawn, catppuccin, black, gruvbox
if [[ -z "$THEME" ]]; then
    echo "Usage: $(basename "$0") [main|moon|dawn|catppuccin|black|gruvbox]"
    exit 1
fi

# --- Theme Metadata ---
declare -A GHOSTTY_THEMES=(
    [main]="Rose Pine"
    [moon]="Rose Pine Moon"
    [dawn]="Rose Pine Dawn"
    [catppuccin]="Catppuccin Mocha"
    [black]="Black Metal (Gorgoroth)"
    [gruvbox]="Gruvbox Dark"
)

declare -A KITTY_THEMES=(
    [main]="Rosé Pine"
    [moon]="Rosé Pine Moon"
    [dawn]="Rosé Pine Dawn"
    [catppuccin]="Catppuccin-Mocha"
    [black]="Black Metal"
    [gruvbox]="Gruvbox Dark"
)

declare -A ALACRITTY_THEMES=(
    [main]="rose-pine.toml"
    [moon]="rose-pine-moon.toml"
    [dawn]="rose-pine-dawn.toml"
    [catppuccin]="catppuccin-mocha.toml"
    [black]="black-metal-gorgoroth.toml"
    [gruvbox]="gruvbox-dark.toml"
)

declare -A WAYBAR_THEMES=(
    [main]="rose-pine.css"
    [moon]="rose-pine-moon.css"
    [dawn]="rose-pine-dawn.css"
    [catppuccin]="mocha.css"
    [black]="black-metal.css"
    [gruvbox]="gruvbox.css"
)

declare -A WOFI_THEMES=(
    [main]="rose-pine.css"
    [moon]="rose-pine-moon.css"
    [dawn]="rose-pine-dawn.css"
    [catppuccin]="mocha.css"
    [black]="black-metal.css"
    [gruvbox]="gruvbox.css"
)

declare -A NVIM_VARIANTS=(
    [main]="main"
    [moon]="moon"
    [dawn]="dawn"
    [catppuccin]="catppuccin"
    [black]="black"
    [gruvbox]="gruvbox"
)

declare -A YAZI_THEMES=(
    [main]="theme-rose-pine.toml"
    [moon]="theme-rose-pine.toml"
    [dawn]="theme-rose-pine.toml"
    [catppuccin]="Catppuccin-Mocha"
    [black]="theme-black.toml"
    [gruvbox]="theme-gruvbox.toml"
)

declare -A TMUX_THEMES=(
    [main]="rose-pine-main.tmux"
    [moon]="rose-pine-moon.tmux"
    [dawn]="rose-pine-dawn.tmux"
    [catppuccin]="catppuccin.tmux"
    [black]="black.tmux"
    [gruvbox]="gruvbox.tmux"
)

# Validate Theme
if [[ -z "${GHOSTTY_THEMES[$THEME]:-}" ]]; then
    echo "Unknown theme: $THEME"
    exit 1
fi

echo "Switching to $THEME..."

# --- 1. Ghostty ---
GHOSTTY_DIR="$(find_config_dir "$COMBINED_DIR/ghostty/.config/ghostty" "$PARENT_DIR/ghostty/.config/ghostty" "$HOME/.config/ghostty" || true)"
if [ -n "$GHOSTTY_DIR" ] && [ -d "$GHOSTTY_DIR" ]; then
    echo "theme = ${GHOSTTY_THEMES[$THEME]}" > "$GHOSTTY_DIR/theme.config"
    echo "✓ Ghostty updated"
fi

# --- 2. Kitty ---
if command -v kitty >/dev/null 2>&1; then
    kitty +kitten themes --reload-in=all "${KITTY_THEMES[$THEME]}"
    echo "✓ Kitty updated"
fi

# --- 3. Alacritty ---
ALACRITTY_DIR="$(find_config_dir "$COMBINED_DIR/alacritty/.config/alacritty" "$PARENT_DIR/alacritty/.config/alacritty" "$HOME/.config/alacritty" || true)"
if [ -n "$ALACRITTY_DIR" ] && [ -d "$ALACRITTY_DIR" ]; then
    ALACRITTY_THEME_FILE="$ALACRITTY_DIR/theme.toml"
    THEME_SRC="$ALACRITTY_DIR/${ALACRITTY_THEMES[$THEME]}"
    if [ -f "$THEME_SRC" ]; then
        rm -f "$ALACRITTY_THEME_FILE"
        cp "$THEME_SRC" "$ALACRITTY_THEME_FILE"
        echo "✓ Alacritty updated"
    fi
fi

# --- 4. Neovim ---
NVIM_CONFIG_DIR="$(find_config_dir "$COMBINED_DIR/nvim/.config/nvim" "$PARENT_DIR/nvim/.config/nvim" "$HOME/.config/nvim" || true)"
if [ -n "$NVIM_CONFIG_DIR" ] && [ -d "$NVIM_CONFIG_DIR" ]; then
    NVIM_VARIANT_FILE="$NVIM_CONFIG_DIR/lua/config/theme_variant.lua"
    mkdir -p "$(dirname "$NVIM_VARIANT_FILE")"
    echo "return \"${NVIM_VARIANTS[$THEME]}\"" > "$NVIM_VARIANT_FILE"
    echo "✓ Neovim updated"
fi

# --- 5. Waybar ---
WAYBAR_DIR="$(find_config_dir "$COMBINED_DIR/waybar/.config/waybar" "$PARENT_DIR/waybar/.config/waybar" "$HOME/.config/waybar" || true)"
if [ -n "$WAYBAR_DIR" ] && [ -d "$WAYBAR_DIR" ]; then
    WAYBAR_THEME_FILE="$WAYBAR_DIR/theme.css"
    THEME_SRC="$WAYBAR_DIR/themes/${WAYBAR_THEMES[$THEME]}"
    if [ -f "$THEME_SRC" ]; then
        rm -f "$WAYBAR_THEME_FILE"
        cp "$THEME_SRC" "$WAYBAR_THEME_FILE"
        if [ -f "$WAYBAR_DIR/style.css" ]; then
            touch "$WAYBAR_DIR/style.css"
        fi
        if pgrep -x waybar >/dev/null; then
            pkill -USR2 waybar
            echo "✓ Waybar updated and reloaded"
        else
            echo "✓ Waybar updated"
        fi
    fi
fi

# --- 6. Wofi ---
WOFI_DIR="$(find_config_dir "$COMBINED_DIR/wofi/.config/wofi" "$PARENT_DIR/wofi/.config/wofi" "$HOME/.config/wofi" || true)"
if [ -n "$WOFI_DIR" ] && [ -d "$WOFI_DIR" ]; then
    WOFI_THEME_FILE="$WOFI_DIR/theme.css"
    THEME_SRC="$WOFI_DIR/themes/${WOFI_THEMES[$THEME]}"
    if [ -f "$THEME_SRC" ]; then
        rm -f "$WOFI_THEME_FILE"
        cp "$THEME_SRC" "$WOFI_THEME_FILE"
        echo "✓ Wofi updated"
    fi
fi

# --- 7. Tmux ---
TMUX_DIR="$(find_config_dir "$COMBINED_DIR/tmux" "$PARENT_DIR/tmux" "$HOME/.config/tmux" || true)"
if [ -n "$TMUX_DIR" ] && [ -d "$TMUX_DIR" ]; then
    TMUX_TARGET="$HOME/.tmux_theme.tmux"
    TMUX_SOURCE="$TMUX_DIR/themes/${TMUX_THEMES[$THEME]}"
    if [ -f "$TMUX_SOURCE" ]; then
        ln -sf "$TMUX_SOURCE" "$TMUX_TARGET"
        if [ -n "${TMUX:-}" ] && command -v tmux >/dev/null 2>&1; then
            tmux source-file "$HOME/.tmux.conf" 2>/dev/null || true
            echo "✓ Tmux updated and reloaded"
        else
            echo "✓ Tmux updated"
        fi
    fi
fi

# --- 8. Yazi ---
YAZI_DIR="$(find_config_dir "$COMBINED_DIR/yazi/.config/yazi" "$PARENT_DIR/yazi/.config/yazi" "$HOME/.config/yazi" || true)"
if [ -n "$YAZI_DIR" ] && [ -d "$YAZI_DIR" ]; then
    YAZI_SOURCE="${YAZI_THEMES[$THEME]}"
    if [ -f "$YAZI_DIR/$YAZI_SOURCE" ]; then
        ln -sf "$YAZI_SOURCE" "$YAZI_DIR/theme.toml"
        echo "✓ Yazi updated"
    fi
fi

# --- 9. Starship ---
STARSHIP_DIR="$(find_config_dir "$COMBINED_DIR/starship/.config" "$PARENT_DIR/starship/.config" "$HOME/.config" || true)"
if [ -n "$STARSHIP_DIR" ] && [ -d "$STARSHIP_DIR" ]; then
    STARSHIP_CONFIG="$STARSHIP_DIR/starship.toml"
    THEME_FILE=""
    if [ "$THEME" = "catppuccin" ]; then
        THEME_FILE="$STARSHIP_DIR/catppuccin.toml"
    elif [ "$THEME" = "main" ] || [ "$THEME" = "moon" ] || [ "$THEME" = "dawn" ]; then
        THEME_FILE="$STARSHIP_DIR/starship_rosepine.bak"
    fi

    if [ -n "$THEME_FILE" ] && [ -f "$THEME_FILE" ]; then
        cp "$THEME_FILE" "$STARSHIP_CONFIG"
        echo "✓ Starship updated ($THEME)"
    else
        echo "✓ Starship left as standard"
    fi
fi

echo "Successfully switched to theme: $THEME"
exit 0
