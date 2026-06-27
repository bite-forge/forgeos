function extract --description 'Extraer cualquier archivo comprimido'
    if test (count $argv) -ne 1
        echo "Uso: extract <archivo>"
        return 1
    end

    if not test -f $argv[1]
        echo "extract: '$argv[1]' no es un archivo válido"
        return 1
    end

    switch $argv[1]
        case '*.tar.bz2'  '*.tbz2'; tar xvjf $argv[1]
        case '*.tar.gz'   '*.tgz';  tar xvzf $argv[1]
        case '*.tar.xz';            tar xvJf $argv[1]
        case '*.tar';               tar xvf  $argv[1]
        case '*.bz2';               bunzip2   $argv[1]
        case '*.gz';                gunzip    $argv[1]
        case '*.zip';               unzip     $argv[1]
        case '*.rar';               unrar x   $argv[1]
        case '*.7z';                7z x      $argv[1]
        case '*.Z';                 uncompress $argv[1]
        case '*'
            echo "extract: formato no soportado ($argv[1])"
            return 1
    end
end
