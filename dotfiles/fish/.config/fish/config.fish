# ┌─────────────────────────────────────────────────────────────┐
# │  ForgeOS · config.fish                                       │
# │  Config principal. Abbreviations en conf.d/abbr.fish        │
# │  Funciones personalizadas en functions/                     │
# └─────────────────────────────────────────────────────────────┘

# Solo en sesiones interactivas. Scripts y tty embebidas no pasan
# por aquí → arranque más rápido.
if status is-interactive

    # ── Greeting off ────────────────────────────────────────────
    set -g fish_greeting

    # ── PATH ────────────────────────────────────────────────────
    # fish_add_path es idempotente: no duplica entradas.
    fish_add_path -g $HOME/.local/bin
    fish_add_path -g $HOME/.cargo/bin
    fish_add_path -g $HOME/go/bin
    fish_add_path -g $HOME/scripts

    # ── Editor y pager ──────────────────────────────────────────
    set -gx EDITOR   nvim
    set -gx VISUAL   nvim
    set -gx SUDO_EDITOR nvim
    set -gx PAGER    less
    set -gx MANPAGER 'less -R --use-color -Dd+r -Du+b'
    set -gx LESS     '-R --use-color'

    # SSH
    set -gx SSH_AUTH_SOCK "$XDG_RUNTIME_DIR/ssh-agent.socket"

    # ── Colores LS con vivid (si está instalado) ────────────────
    if command -q vivid
        set -gx LS_COLORS (vivid generate molokai 2>/dev/null)
    end

    # ── FZF defaults (monocromo ForgeOS) ────────────────────────
    if command -q fzf
        set -gx FZF_DEFAULT_OPTS '--height 40% --layout=reverse --border --color=bg+:#1c1c1c,bg:#0a0a0a,spinner:#ffffff,hl:#888888,fg:#e8e8e8,header:#888888,info:#aaaaaa,pointer:#ffffff,marker:#ffffff,fg+:#ffffff,prompt:#aaaaaa,hl+:#ffffff'
        command -q fd; and set -gx FZF_DEFAULT_COMMAND 'fd --type f --hidden --exclude .git'
    end

    # ── Man pages con color ─────────────────────────────────────
    set -gx LESS_TERMCAP_mb (printf '\e[01;37m')
    set -gx LESS_TERMCAP_md (printf '\e[01;37m')
    set -gx LESS_TERMCAP_me (printf '\e[0m')
    set -gx LESS_TERMCAP_se (printf '\e[0m')
    set -gx LESS_TERMCAP_so (printf '\e[01;47;30m')
    set -gx LESS_TERMCAP_ue (printf '\e[0m')
    set -gx LESS_TERMCAP_us (printf '\e[01;37m')

    # ── Integraciones ───────────────────────────────────────────
    command -q starship; and starship init fish | source
    command -q zoxide;   and zoxide init fish --cmd cd | source

end
