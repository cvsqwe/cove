# yazi; при выходе остаёмся в папке, где закрыли файловый менеджер
function y
    set -l tmp (mktemp -t yazi-cwd.XXXXXX)
    yazi $argv --cwd-file=$tmp
    set -l cwd (command cat -- $tmp)
    if test -n "$cwd"; and test "$cwd" != "$PWD"
        builtin cd -- $cwd
    end
    rm -f -- $tmp
end
