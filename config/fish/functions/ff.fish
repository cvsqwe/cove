# Полный fastfetch Cove на языке шелла (~/.cache/cove/lang пишет Quickshell)
function ff --description 'fastfetch Cove'
    set -l lang ru
    test -r ~/.cache/cove/lang; and set lang (string trim < ~/.cache/cove/lang)
    test -r ~/.config/fastfetch/config.$lang.jsonc; or set lang ru
    fastfetch --config ~/.config/fastfetch/config.$lang.jsonc $argv
end
