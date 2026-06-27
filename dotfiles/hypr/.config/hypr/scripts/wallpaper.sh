#!/usr/bin/env bash
# =============================================================================
# wallpaper.sh · Rotación aleatoria de wallpaper con hyprpaper
# ForgeOS. Elige un wallpaper aleatorio de la carpeta y lo aplica.
# Uso:
#   wallpaper.sh           → aplica uno aleatorio
#   wallpaper.sh <ruta>    → aplica el especificado
# Para rotación periódica: llamar desde hypridle o un systemd timer.
# =============================================================================

set -euo pipefail

WALLPAPER_DIR="$HOME/Pictures/Wallpapers/ForgeOS"
CURRENT_LINK="$HOME/.cache/forgeos-current-wallpaper"

# Patrón de wallpapers de fondo (excluye el logo)
shopt -s nullglob
mapfile -t WALLPAPERS < <(find "$WALLPAPER_DIR" -maxdepth 1 -type f \
    \( -name '*.png' -o -name '*.jpg' -o -name '*.jpeg' \) \
    ! -name '*logo*' | sort)
shopt -u nullglob

if (( ${#WALLPAPERS[@]} == 0 )); then
    echo "Sin wallpapers en $WALLPAPER_DIR" >&2
    exit 1
fi

# Elegir wallpaper: argumento explícito o aleatorio
if [[ $# -ge 1 && -f "$1" ]]; then
    WP="$1"
else
    WP="${WALLPAPERS[RANDOM % ${#WALLPAPERS[@]}]}"
fi

# Esperar a que hyprpaper esté listo (si se llama muy pronto al inicio)
for _ in {1..10}; do
    hyprctl hyprpaper listloaded &>/dev/null && break
    sleep 0.3
done

# Aplicar: precargar + asignar a todos los monitores
hyprctl hyprpaper preload "$WP" >/dev/null 2>&1 || true
hyprctl hyprpaper wallpaper ",$WP" >/dev/null 2>&1 || true

# Descargar los no usados para liberar RAM
hyprctl hyprpaper unload unused >/dev/null 2>&1 || true

# Guardar el actual (para que hyprlock use el mismo)
mkdir -p "$(dirname "$CURRENT_LINK")"
printf '%s' "$WP" > "$CURRENT_LINK"

echo "Wallpaper: $WP"
