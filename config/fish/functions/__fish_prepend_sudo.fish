function __fish_prepend_sudo
    set -l cmd (commandline)
    test -z "$cmd"; and set cmd $history[1]
    if string match -q 'sudo *' -- $cmd
        commandline -r (string replace -r '^sudo ' '' -- $cmd)
    else
        commandline -r "sudo $cmd"
    end
    commandline -f end-of-line
end
