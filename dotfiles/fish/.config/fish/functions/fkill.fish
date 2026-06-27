function fkill --description 'Matar proceso con fzf'
    if not command -q fzf
        echo "fkill requiere fzf (sudo pacman -S fzf)"
        return 1
    end

    set -l signal SIGTERM
    test (count $argv) -gt 0; and set signal $argv[1]

    set -l pid (ps -ef | sed 1d | fzf -m --height 40% --reverse --header "Seleccionar proceso (Tab para multi)" | awk '{print $2}')

    if test -n "$pid"
        echo $pid | xargs kill -$signal
        echo "✓ Kill -$signal: $pid"
    end
end
