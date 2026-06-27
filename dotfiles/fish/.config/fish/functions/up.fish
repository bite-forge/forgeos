function up --description 'Actualización completa del sistema Arch'
    echo "→ Actualizando mirrorlist..."
    if command -q reflector
        sudo reflector --latest 10 --country Spain,France --sort rate --save /etc/pacman.d/mirrorlist
    end

    echo
    echo "→ Actualizando paquetes (pacman + AUR)..."
    yay -Syu --noconfirm; or return 1

    echo
    echo "→ Limpiando paquetes huérfanos..."
    set -l orphans (pacman -Qtdq 2>/dev/null)
    if test -n "$orphans"
        sudo pacman -Rns $orphans --noconfirm
    else
        echo "  (ninguno)"
    end

    echo
    echo "→ Limpiando caché antigua (manteniendo últimas 3 versiones)..."
    if command -q paccache
        sudo paccache -rk3
    else
        echo "  paccache no instalado (sudo pacman -S pacman-contrib)"
    end

    echo
    echo "✓ Sistema actualizado"
end
