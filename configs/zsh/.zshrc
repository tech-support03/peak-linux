# ╔══════════════════════════════════════════════════════════════╗
# ║  peak-linux — Zsh Configuration                           ║
# ║  Minimal, fast, developer-focused                          ║
# ╚══════════════════════════════════════════════════════════════╝

# ── History ────────────────────────────────────────────────────
HISTFILE=~/.zsh_history
HISTSIZE=10000
SAVEHIST=10000
setopt HIST_IGNORE_ALL_DUPS
setopt HIST_SAVE_NO_DUPS
setopt HIST_REDUCE_BLANKS
setopt SHARE_HISTORY
setopt APPEND_HISTORY

# ── Options ────────────────────────────────────────────────────
setopt AUTO_CD
setopt INTERACTIVE_COMMENTS
setopt CORRECT

# ── Completion ─────────────────────────────────────────────────
autoload -Uz compinit
compinit
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'
zstyle ':completion:*' menu select
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"

# ── Aliases ────────────────────────────────────────────────────
# File listing (eza)
alias ls='eza --icons --group-directories-first'
alias ll='eza -la --icons --group-directories-first'
alias lt='eza -la --icons --tree --level=2'

# Cat replacement (bat)
alias cat='bat --style=auto'

# Git shortcuts
alias g='git'
alias gs='git status'
alias ga='git add'
alias gc='git commit'
alias gp='git push'
alias gl='git log --oneline --graph --decorate -15'
alias gd='git diff'
alias lg='lazygit'

# System
alias update='sudo pacman -Syu'
alias cleanup='sudo pacman -Rns $(pacman -Qtdq) 2>/dev/null; paru -Scc --noconfirm'
alias ..='cd ..'
alias ...='cd ../..'
alias mkdir='mkdir -pv'

# Neovim
alias v='nvim'
alias vi='nvim'
alias vim='nvim'

# ── Key bindings ───────────────────────────────────────────────
bindkey '^[[A' history-search-backward
bindkey '^[[B' history-search-forward
bindkey '^[[H' beginning-of-line
bindkey '^[[F' end-of-line
bindkey '^[[3~' delete-char

# ── Path ───────────────────────────────────────────────────────
export PATH="$HOME/.local/bin:$PATH"

# ── Editor ─────────────────────────────────────────────────────
export EDITOR='nvim'
export VISUAL='nvim'

# ── Tool init ──────────────────────────────────────────────────
# Zoxide (smarter cd)
eval "$(zoxide init zsh --cmd cd)"

# FZF
source /usr/share/fzf/key-bindings.zsh 2>/dev/null
source /usr/share/fzf/completion.zsh 2>/dev/null
export FZF_DEFAULT_OPTS="
    --color=bg+:#3A3A3C,bg:#1C1C1E,fg:#D1D1D6,fg+:#FFFFFF
    --color=hl:#007AFF,hl+:#0A84FF,info:#FF9F0A,marker:#30D158
    --color=prompt:#007AFF,spinner:#BF5AF2,pointer:#BF5AF2,header:#007AFF
    --color=border:#3A3A3C
    --border=rounded --padding=1 --margin=0
    --prompt='▸ ' --pointer='▸' --marker='✓'
"

# Starship prompt
eval "$(starship init zsh)"
