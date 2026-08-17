# ssh
alias ssh-german='ssh true_ssh_container'   

# Lazy
alias ..='z ..'
alias ...='z ../..'
alias ....='z ../../..'
alias .....='z ../../../..'
alias nv='nvim'
alias preview_sddm='sddm-greeter-qt6 --test-mode --theme /usr/share/sddm/themes/sddm-astronaut-theme/'

# git
alias gsw='git update-index --skip-worktree'
alias gnsw='git update-index --no-skip-worktree'

# Github
alias gh='open https://github.com/GermanViter/'

# --- Homebrew Setup ---
if [[ -f /opt/homebrew/bin/brew ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
elif [[ -f /usr/local/bin/brew ]]; then
    eval "$(/usr/local/bin/brew shellenv)"
elif [[ -f /home/linuxbrew/.linuxbrew/bin/brew ]]; then
    eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
fi

# --- Shell Configuration & Oh-My-Zsh ---
export ZSH="$HOME/.oh-my-zsh"
DISABLE_AUTO_TITLE="true"
ZSH_THEME="robbyrussell"
plugins=(git sudo zsh-autosuggestions zsh-syntax-highlighting)
export ZSH_DISABLE_COMPFIX=true

# Source Oh-My-Zsh if it exists
if [[ -f $ZSH/oh-my-zsh.sh ]]; then
    source $ZSH/oh-my-zsh.sh
fi

# Source Homebrew-installed plugins dynamically
if command -v brew >/dev/null 2>&1; then
    BREW_PREFIX=$(brew --prefix)
fi

# --- Editor ---
export EDITOR='nvim'

# --- Starship ---
# Use the symlinked path in ~/.config for portability
export STARSHIP_CONFIG="$HOME/.config/starship.toml"
if command -v starship >/dev/null 2>&1; then
    eval "$(starship init zsh)"
fi

# --- Zoxide (Navigation) ---
if command -v zoxide >/dev/null 2>&1; then
    eval "$(zoxide init zsh)"
    alias cd='zi'
fi

# --- Eza (Modern ls) ---
if command -v eza >/dev/null 2>&1; then
    alias ls='eza --icons=always -1'
    alias ll='eza --icons=always -la --group-directories-first'
    alias la='eza --icons=always -a --group-directories-first'
fi

# --- Fzf (Fuzzy Finder) ---
if command -v fzf >/dev/null 2>&1; then
    source <(fzf --zsh)
    alias fzshow='fzf --preview="bat --color=always {}"'
    alias fzvim='nvim $(fzf --preview="bat --color=always {}")'
fi

# --- Tmux ---
alias tms='tmux attach-session -t $1'
DISABLE_AUTO_TITLE=true

# --- AI & Sync Tools ---
alias claude='ollama launch claude --model gemma4:31b-cloud'
alias claw='ollama launch openclaw --model glm-5:cloud'
alias gsync='python3 $HOME/.gemini/scripts/obsidian_sync.py'

# --- Development Environment (Java, Go, Python) ---
if [[ -x /usr/libexec/java_home ]]; then
    export JAVA_HOME=$(/usr/libexec/java_home -v 25 2>/dev/null || /usr/libexec/java_home)
fi
export PATH="$PATH:$HOME/go/bin"
export PATH="$PATH:$HOME/.local/bin"

# --- Custom Functions ---
# Show most used commands
cmdhist() {
  fc -l 1 | awk '{print $2}' | sort | uniq -c | sort -nr | head -${1:-10}
}

# Count total lines of code in current directory
linec() {
    find . -type f -not -path '*/.*' -exec wc -l {} + | awk '{total += $1} END {print total}' 
}

fcd() {
    local dir
    dir=$(find ${1:-.} -type d -not -path '*/\.*' 2>/dev/null | fzf +m) && z "$dir"
}

# Load local overrides (for private paths/secrets)
[[ -f ~/.zshrc.local ]] && source ~/.zshrc.local


# Added by Antigravity CLI installer
export PATH="/home/user/.local/bin:$PATH"
export WEBKIT_DISABLE_DMABUF_RENDERER=1


# Added by Antigravity CLI installer
export PATH="/home/germanviter/.local/bin:$PATH"
