#!/bin/sh
# История буфера для лаунчера: id<TAB>тип<TAB>текст-или-путь-к-превью.
# Картинки декодируются в $XDG_RUNTIME_DIR/qs-clip (только первые 30).
dir="${XDG_RUNTIME_DIR:-/tmp}/qs-clip"; mkdir -p "$dir"
n=0
cliphist list | head -200 | while IFS="$(printf '\t')" read -r id rest; do
    case "$rest" in
        "[[ binary data"*png*|"[[ binary data"*jpg*|"[[ binary data"*jpeg*|"[[ binary data"*webp*|"[[ binary data"*bmp*)
            n=$((n+1)); [ $n -gt 30 ] && continue
            f="$dir/$id.png"; [ -s "$f" ] || cliphist decode "$id" > "$f" 2>/dev/null
            printf '%s\timg\t%s\t%s\n' "$id" "$f" "$(echo "$rest" | grep -oE '[0-9]+x[0-9]+')";;
        "[[ binary data"*) ;;
        *) printf '%s\ttxt\t%s\n' "$id" "$rest";;
    esac
done
