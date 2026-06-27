#!/usr/bin/env bash
# =============================================================================
# network-menu.sh · Gestión de red WiFi/Ethernet con wofi
# Requiere: networkmanager (nmcli), wofi, (opcional) nm-connection-editor
# =============================================================================

set -euo pipefail

# Comando del menú centralizado (cambiar aquí si se sustituye wofi).
menu()  { wofi --dmenu -i --prompt "$1" --width 340 --height 360; }
menu_pw() { wofi --dmenu -i --password --prompt "$1" --width 340 --height 120; }

# ── Helpers ─────────────────────────────────────────────────────────────────
get_network_info() {
    local wifi eth info=""
    wifi=$(nmcli -t -f DEVICE,TYPE dev 2>/dev/null | awk -F: '$2=="wifi"     {print $1; exit}')
    eth=$( nmcli -t -f DEVICE,TYPE dev 2>/dev/null | awk -F: '$2=="ethernet" {print $1; exit}')

    if [[ -n "${wifi:-}" ]]; then
        local ssid ip
        ssid=$(nmcli -t -f GENERAL.CONNECTION dev show "$wifi" 2>/dev/null | cut -d: -f2)
        ip=$(  nmcli -t -f IP4.ADDRESS        dev show "$wifi" 2>/dev/null | cut -d: -f2 | head -1)
        if [[ -n "$ssid" && "$ssid" != "--" ]]; then
            info+="  WiFi: $ssid"$'\n'
            info+="  IP: ${ip:-N/A}"$'\n'
        else
            info+="  WiFi: Desconectado"$'\n'
        fi
    fi

    if [[ -n "${eth:-}" ]]; then
        local ip
        ip=$(nmcli -t -f IP4.ADDRESS dev show "$eth" 2>/dev/null | cut -d: -f2 | head -1)
        [[ -n "$ip" ]] && info+="  Ethernet: $ip"$'\n'
    fi

    printf '%s' "$info"
}

# ── Menú principal ──────────────────────────────────────────────────────────
OPTIONS="  Redes WiFi disponibles
  Activar/Desactivar WiFi
  Configuración de red
  Información de conexión"

CHOSEN=$(printf '%s' "$OPTIONS" | menu "Red")

case "$CHOSEN" in
    *"Redes WiFi disponibles"*)
        nmcli dev wifi rescan 2>/dev/null || true
        sleep 1

        NETWORKS=$(nmcli --terse -f IN-USE,SSID,SIGNAL,SECURITY dev wifi list 2>/dev/null | sort -t: -k3 -nr | head -15)

        if [[ -z "$NETWORKS" ]]; then
            notify-send "WiFi" "No se encontraron redes"
            exit 0
        fi

        WIFI_LIST=""
        while IFS=: read -r inuse ssid signal security; do
            [[ -z "${ssid:-}" ]] && continue

            if   (( signal >= 75 )); then icon="󰤨"
            elif (( signal >= 50 )); then icon="󰤥"
            elif (( signal >= 25 )); then icon="󰤢"
            else                          icon="󰤟"
            fi

            lock=""
            [[ -n "$security" && "$security" != "--" ]] && lock=" "

            active=""
            [[ "$inuse" == "*" ]] && active=" ✓"

            WIFI_LIST+="$icon  $ssid${lock} (${signal}%)${active}"$'\n'
        done <<< "$NETWORKS"

        SELECTED=$(printf '%s' "$WIFI_LIST" | menu "Seleccionar red")
        [[ -z "${SELECTED:-}" ]] && exit 0

        SSID=$(echo "$SELECTED" | sed -E 's/^[^ ]+ +//; s/ *\(.*//; s/ *$//')

        if nmcli connection show "$SSID" &>/dev/null; then
            nmcli connection up "$SSID" >/dev/null 2>&1 \
                && notify-send "WiFi" "Conectado a $SSID" \
                || notify-send "WiFi" "Error al conectar a $SSID"
        else
            PASSWORD=$(menu_pw "Contraseña para $SSID")
            if [[ -n "${PASSWORD:-}" ]]; then
                nmcli dev wifi connect "$SSID" password "$PASSWORD" >/dev/null 2>&1 \
                    && notify-send "WiFi" "Conectado a $SSID" \
                    || notify-send "WiFi" "Error al conectar a $SSID"
            fi
        fi
        ;;

    *"Activar/Desactivar WiFi"*)
        if nmcli radio wifi | grep -q enabled; then
            nmcli radio wifi off
            notify-send "WiFi" "Desactivado"
        else
            nmcli radio wifi on
            notify-send "WiFi" "Activado"
        fi
        ;;

    *"Configuración de red"*)
        if command -v nm-connection-editor &>/dev/null; then
            nm-connection-editor &
        else
            kitty -e nmtui &
        fi
        ;;

    *"Información de conexión"*)
        INFO=$(get_network_info)
        PUBLIC_IP=$(curl -s --max-time 3 ifconfig.me 2>/dev/null || echo "N/A")
        INFO+="  IP Pública: $PUBLIC_IP"
        notify-send -t 10000 "Información de Red" "$INFO"
        ;;
esac
