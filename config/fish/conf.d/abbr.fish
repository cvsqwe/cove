# Аббревиатуры раскрываются по пробелу — в истории остаётся полная команда.
status is-interactive; or exit

# файлы
if command -q eza
    abbr -a ls 'eza --group-directories-first --icons=auto'
    abbr -a l  'eza -lh --group-directories-first --icons=auto --git'
    abbr -a la 'eza -lah --group-directories-first --icons=auto --git'
    abbr -a lt 'eza --tree --level=2 --icons=auto --git-ignore'
end
abbr -a cat 'bat --paging=never'
abbr -a .. 'cd ..'
abbr -a ... 'cd ../..'
abbr -a .... 'cd ../../..'
abbr -a md 'mkdir -p'

# git
abbr -a g git
abbr -a gs 'git status -sb'
abbr -a ga 'git add'
abbr -a gaa 'git add -A'
abbr -a gc 'git commit -m'
abbr -a gca 'git commit --amend --no-edit'
abbr -a gp 'git push'
abbr -a gl 'git pull --rebase'
abbr -a gd 'git diff'
abbr -a gco 'git checkout'
abbr -a gsw 'git switch'
abbr -a glog 'git log --oneline --graph --decorate -20'

# пакеты (Arch)
abbr -a i 'sudo pacman -S'
abbr -a up 'yay -Syu'
abbr -a rem 'sudo pacman -Rns'
abbr -a ss 'yay -Ss'
abbr -a orphans 'pacman -Qdtq | sudo pacman -Rns -'

# система
abbr -a d docker
abbr -a sc 'systemctl'
abbr -a scu 'systemctl --user'
abbr -a jf 'journalctl -f'
# ff — функция в functions/ff.fish (fastfetch Cove на языке шелла)
abbr -a qsr 'pkill -x qs; hyprctl dispatch \'hl.dsp.exec_cmd("qs")\''

# !! — последняя команда, !$ — её последний аргумент (как в bash)
function __last_cmd; echo $history[1]; end
function __last_arg; echo (string split ' ' -- $history[1])[-1]; end
abbr -a !! --position anywhere --function __last_cmd
abbr -a !\$ --position anywhere --function __last_arg
