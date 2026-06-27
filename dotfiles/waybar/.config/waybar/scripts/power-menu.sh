#!/usr/bin/env bash
# =============================================================================
# power-menu.sh · Apagado/reinicio/suspend/logout/lock con wofi
# =============================================================================

set -euo pipefail

# Comando del menú centralizado (cambiar aquí si se sustituye wofi).
MENU=(wofi --dmenu -i --prompt "Power" --width 240 --height 240)

OPTIONS="  Apagar
  Reiniciar
  Suspender
  Cerrar sesión
  Bloquear"

CHOSEN=$(printf '%s' "$OPTIONS" | "${MENU[@]}")

case "$CHOSEN" in
    *Apagar*)          systemctl poweroff ;;
    *Reiniciar*)       systemctl reboot ;;
    *Suspender*)       systemctl suspend ;;
    *"Cerrar sesión"*) hyprctl dispatch exit ;;
    *Bloquear*)        hyprlock ;;
esac
