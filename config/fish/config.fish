# ~/.config/fish/config.fish
# Цвета — только ANSI-имена: палитру kitty генерирует Quickshell из обоев,
# так что промпт, подсветка и fzf перекрашиваются вместе со всем шеллом.
# magenta = акцент шелла, blue = второй акцент (розовый).

fish_add_path -g ~/.local/bin

set -gx EDITOR nano
set -gx SUDO_EDITOR $EDITOR
set -gx PAGER less
set -gx MANPAGER "sh -c 'col -bx | bat -l man -p'"
set -gx MANROFFOPT -c
set -gx BAT_THEME ansi

if not status is-interactive
    command -q mise; and mise activate fish --shims | source
    exit
end

# ---------- приветствие ----------
# fastfetch только в первом окне за сессию; set -U fish_fastfetch 0 — выключить
set -q fish_fastfetch; or set -U fish_fastfetch 1
function fish_greeting
    test "$fish_fastfetch" = 1; or return
    set -l flag /tmp/fish-greet-(id -u)-$XDG_SESSION_ID
    test -e $flag; and return
    touch $flag
    command -q fastfetch; and fastfetch --config ~/.config/fish/fastfetch.jsonc
end

# ---------- подсветка синтаксиса ----------
set -g fish_color_command magenta --bold
set -g fish_color_keyword blue --bold
set -g fish_color_param normal
set -g fish_color_option cyan
set -g fish_color_quote green
set -g fish_color_redirection yellow
set -g fish_color_end blue
set -g fish_color_operator yellow
set -g fish_color_escape cyan
set -g fish_color_error red --bold
set -g fish_color_comment brblack --italics
set -g fish_color_autosuggestion brblack
set -g fish_color_valid_path --underline
set -g fish_color_search_match --background=brblack
set -g fish_color_selection --background=brblack
set -g fish_color_cancel red
set -g fish_pager_color_prefix magenta --bold --underline
set -g fish_pager_color_completion normal
set -g fish_pager_color_description brblack --italics
set -g fish_pager_color_progress brblack
set -g fish_pager_color_selected_background --background=brblack

# ---------- инструменты ----------
command -q mise; and mise activate fish | source
command -q zoxide; and zoxide init fish --cmd cd | source      # cd учится, cdi — интерактивно

if command -q fzf
    set -gx FZF_DEFAULT_COMMAND 'fd --type f --hidden --follow --exclude .git'
    set -gx FZF_CTRL_T_COMMAND $FZF_DEFAULT_COMMAND
    set -gx FZF_ALT_C_COMMAND 'fd --type d --hidden --follow --exclude .git'
    set -gx FZF_DEFAULT_OPTS '--height=45% --layout=reverse --border=rounded --info=inline-right
        --prompt="❯ " --pointer="▌" --marker="▍" --separator="─" --scrollbar="│"
        --color=fg:-1,bg:-1,hl:magenta,fg+:-1,bg+:black,hl+:magenta:bold
        --color=border:bright-black,prompt:magenta,pointer:magenta,marker:blue,info:bright-black,spinner:blue,header:cyan'
    set -gx FZF_CTRL_T_OPTS "--preview 'bat -n --color=always --line-range :300 {}'"
    set -gx FZF_ALT_C_OPTS "--preview 'eza --tree --level=2 --icons --color=always {}'"
    fzf --fish | source        # Ctrl+R история, Ctrl+T файлы, Alt+C папки
end

if command -q starship
    starship init fish | source
    enable_transience          # старые промпты сжимаются до одного ❯
end

# ---------- клавиши ----------
bind \e\e __fish_prepend_sudo  # Esc Esc — добавить/убрать sudo
