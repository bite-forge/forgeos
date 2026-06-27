#!/usr/bin/env bash
# lib/utils.sh — utilidades: logging, dry-run, sudo, confirmación, servicios.

# --- logging ---
_log_raw() { printf '%s\n' "$*" >>"$LOG_FILE" 2>/dev/null || true; }
log()   { printf '%b[forgeos]%b %s\n' "$C_BLUE"  "$C_RESET" "$*"; _log_raw "[forgeos] $*"; }
ok()    { printf '%b[ ok ]%b %s\n'    "$C_GREEN" "$C_RESET" "$*"; _log_raw "[ ok ] $*"; }
warn()  { printf '%b[warn]%b %s\n'    "$C_YELLOW" "$C_RESET" "$*"; _log_raw "[warn] $*"; }
error() { printf '%b[fail]%b %s\n'    "$C_RED"   "$C_RESET" "$*" >&2; _log_raw "[fail] $*"; }

# --- sudo transparente ---
maybe_sudo() {
  if [[ $EUID -ne 0 ]]; then sudo "$@"; else "$@"; fi
}

# --- ejecutor con dry-run ---
# Uso: run <comando> [args...]   (sin pipes; para pipes usa funciones dedicadas)
run() {
  if [[ "$DRY_RUN" == "true" ]]; then
    printf '%b[dry-run]%b %s\n' "$C_DIM" "$C_RESET" "$*"
    _log_raw "[dry-run] $*"
    return 0
  fi
  _log_raw "[run] $*"
  "$@"
}

# --- escribir contenido a un archivo, respetando dry-run y sudo ---
# Uso:  write_file <ruta> [--sudo] <<EOF ... EOF
#   o:  printf '%s' "$c" | write_file <ruta> [--sudo]
write_file() {
  local path="$1"; shift
  local use_sudo=false
  [[ "${1:-}" == "--sudo" ]] && { use_sudo=true; shift; }
  local content; content="$(cat)"   # stdin → variable

  if [[ "$DRY_RUN" == "true" ]]; then
    printf '%b[dry-run]%b write → %s (%d bytes)\n' \
      "$C_DIM" "$C_RESET" "$path" "${#content}"
    _log_raw "[dry-run] write $path"
    return 0
  fi
  _log_raw "[write] $path"
  if [[ "$use_sudo" == "true" ]]; then
    printf '%s\n' "$content" | maybe_sudo tee "$path" >/dev/null
  else
    printf '%s\n' "$content" > "$path"
  fi
}

# --- confirmación interactiva ---
confirm() {
  local prompt="${1:-¿Continuar?}"
  [[ "$ASSUME_YES" == "true" ]] && return 0
  local ans
  read -rp "$(printf '%b?%b %s [s/N] ' "$C_YELLOW" "$C_RESET" "$prompt")" ans
  [[ "$ans" =~ ^[sSyY]$ ]]
}

# --- habilitar servicio systemd solo si su unit existe ---
enable_service() {
  local svc="$1"
  if systemctl list-unit-files 2>/dev/null | grep -q "^${svc}"; then
    run maybe_sudo systemctl enable "$svc"
  else
    warn "Servicio '$svc' no presente — salto"
  fi
}

# --- comprobar que estamos en Arch ---
assert_arch() {
  if [[ ! -f /etc/arch-release ]] && ! command -v pacman &>/dev/null; then
    error "Esto no parece Arch Linux (sin pacman). Abortando."
    exit 1
  fi
}
