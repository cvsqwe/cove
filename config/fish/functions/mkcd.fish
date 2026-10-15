function mkcd -d "Создать папку и перейти в неё"
    mkdir -p -- $argv[1]; and builtin cd -- $argv[1]
end
