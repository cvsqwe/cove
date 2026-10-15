function bak -d "Скопировать файл в file.bak (или вернуть из .bak)"
    for f in $argv
        if string match -q '*.bak' -- $f
            cp -i -- $f (string replace -r '\.bak$' '' -- $f)
        else
            cp -i -- $f $f.bak
        end
    end
end
