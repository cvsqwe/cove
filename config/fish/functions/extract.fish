function extract -d "Распаковать любой архив"
    for f in $argv
        switch $f
            case '*.tar.gz' '*.tgz';   tar xzf $f
            case '*.tar.xz' '*.txz';   tar xJf $f
            case '*.tar.zst';          tar --zstd -xf $f
            case '*.tar.bz2' '*.tbz2'; tar xjf $f
            case '*.tar';              tar xf $f
            case '*.zip';              unzip $f
            case '*.7z';               7z x $f
            case '*.rar';              unrar x $f
            case '*.gz';               gunzip $f
            case '*.xz';               unxz $f
            case '*.zst';              unzstd $f
            case '*';                  echo "extract: не знаю, как распаковать $f" >&2; return 1
        end
    end
end
