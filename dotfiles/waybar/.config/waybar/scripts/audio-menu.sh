#!/usr/bin/env bash
# =============================================================================
# audio-menu.sh · Control de volumen y dispositivos de audio con wofi
# Requiere: wireplumber (wpctl), pipewire-pulse (pactl), wofi, pavucontrol
# =============================================================================

set -euo pipefail

# Comando del menú centralizado (cambiar aquí si se sustituye wofi).
menu() { wofi --dmenu -i --prompt "$1" --width 300 --height 320; }

# ── Helpers ─────────────────────────────────────────────────────────────────
get_volume()  { pactl get-sink-volume @DEFAULT_SINK@ | grep -oP '\d+%' | head -1; }
is_muted()    { pactl get-sink-mute    @DEFAULT_SINK@ | grep -q yes; }

# ── Estado actual ───────────────────────────────────────────────────────────
if is_muted; then
    MUTE_OPT="  Activar sonido"
else
    MUTE_OPT="  Silenciar"
fi

CURRENT_VOL=$(get_volume)

OPTIONS="  Volumen: $CURRENT_VOL
$MUTE_OPT
  Dispositivo de salida
  Dispositivo de entrada
  Mezclador (pavucontrol)"

CHOSEN=$(printf '%s' "$OPTIONS" | menu "Audio")

case "$CHOSEN" in
    *Volumen:*)
        VOL_OPTS="  100%
  90%
  80%
  70%
  60%
  50%
  40%
  30%
  20%
  10%
  0%"
        VOL_SEL=$(printf '%s' "$VOL_OPTS" | menu "Volumen")
        if [[ -n "${VOL_SEL:-}" ]]; then
            VOL=$(echo "$VOL_SEL" | grep -oP '\d+')
            pactl set-sink-volume @DEFAULT_SINK@ "${VOL}%"
        fi
        ;;

    *Silenciar*|*"Activar sonido"*)
        pactl set-sink-mute @DEFAULT_SINK@ toggle
        if is_muted; then
            notify-send "Audio" "Silenciado"
        else
            notify-send "Audio" "Sonido activado"
        fi
        ;;

    *"Dispositivo de salida"*)
        DEFAULT_SINK=$(pactl get-default-sink)
        SINKS_DATA=$(pactl -f json list sinks 2>/dev/null | \
            python3 -c "import sys, json
for s in json.load(sys.stdin):
    print(f\"{s['index']}\\t{s['name']}\\t{s['description']}\")" 2>/dev/null || true)

        if [[ -z "$SINKS_DATA" ]]; then
            SINKS_DATA=$(pactl list sinks | awk '
                /^Sink #/       {id=$2; sub("#","",id)}
                /Name:/         {name=$2}
                /Description:/  {sub("^[[:space:]]*Description:[[:space:]]*",""); print id"\t"name"\t"$0}
            ')
        fi

        SINK_LIST=""
        while IFS=$'\t' read -r id name desc; do
            [[ -z "${id:-}" ]] && continue
            if [[ "$name" == "$DEFAULT_SINK" ]]; then
                SINK_LIST+="  $desc (actual)"$'\n'
            else
                SINK_LIST+="  $desc"$'\n'
            fi
        done <<< "$SINKS_DATA"

        SINK_SEL=$(printf '%s' "$SINK_LIST" | menu "Salida")
        if [[ -n "${SINK_SEL:-}" ]]; then
            SEL_DESC=$(echo "$SINK_SEL" | sed 's/^[^ ]* *//' | sed 's/ (actual)$//')
            NEW_NAME=$(echo "$SINKS_DATA" | awk -F'\t' -v d="$SEL_DESC" '$3==d {print $2; exit}')
            if [[ -n "$NEW_NAME" ]]; then
                pactl set-default-sink "$NEW_NAME"
                notify-send "Audio" "Salida: $SEL_DESC"
            fi
        fi
        ;;

    *"Dispositivo de entrada"*)
        DEFAULT_SOURCE=$(pactl get-default-source)
        SOURCES_DATA=$(pactl list sources | awk '
            /^Source #/     {id=$2; sub("#","",id)}
            /Name:/         {name=$2}
            /Description:/  {sub("^[[:space:]]*Description:[[:space:]]*",""); if (name !~ /\.monitor$/) print id"\t"name"\t"$0}
        ')

        SOURCE_LIST=""
        while IFS=$'\t' read -r id name desc; do
            [[ -z "${id:-}" ]] && continue
            if [[ "$name" == "$DEFAULT_SOURCE" ]]; then
                SOURCE_LIST+="  $desc (actual)"$'\n'
            else
                SOURCE_LIST+="  $desc"$'\n'
            fi
        done <<< "$SOURCES_DATA"

        SRC_SEL=$(printf '%s' "$SOURCE_LIST" | menu "Entrada")
        if [[ -n "${SRC_SEL:-}" ]]; then
            SEL_DESC=$(echo "$SRC_SEL" | sed 's/^[^ ]* *//' | sed 's/ (actual)$//')
            NEW_NAME=$(echo "$SOURCES_DATA" | awk -F'\t' -v d="$SEL_DESC" '$3==d {print $2; exit}')
            if [[ -n "$NEW_NAME" ]]; then
                pactl set-default-source "$NEW_NAME"
                notify-send "Audio" "Entrada: $SEL_DESC"
            fi
        fi
        ;;

    *Mezclador*)
        pavucontrol &
        ;;
esac
