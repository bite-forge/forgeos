function backup --description 'Crear backup de archivo/dir con timestamp'
    if test (count $argv) -eq 0
        echo "Uso: backup <archivo_o_dir>"
        return 1
    end

    set -l target $argv[1]
    set -l stamp (date +%Y%m%d-%H%M%S)
    set -l dest "$target.bak.$stamp"

    cp -r $target $dest; and echo "✓ Backup: $dest"
end
