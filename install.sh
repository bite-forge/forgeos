#!/usr/bin/env bash
# ForgeOS — install.sh
# Orquestador (Capa 1). Bootstrap desde un Arch limpio.
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# --- cargar libs ---
source "$REPO_DIR/lib/config.sh"
source "$REPO_DIR/lib/utils.sh"
source "$REPO_DIR/lib/detect.sh"
source "$REPO_DIR/lib/packages.sh"
source "$REPO_DIR/lib/dotfiles.sh"
source "$REPO_DIR/scripts/post-install.sh"   # expone post_install()

usage() {
  cat <<EOF
ForgeOS install.sh — bootstrap de Arch para desarrollo web

Uso: ./install.sh [MODO] [opciones]

Modos (elige uno; por defecto: --desktop):
  --minimal     Solo núcleo (core.txt)
  --dev         core + dev + AUR
  --desktop     core + dev + desktop + AUR        [default]
  --full        core + dev + desktop + optional + AUR

Opciones:
  --dry-run     Muestra qué haría sin tocar nada
  --yes         No pregunta confirmaciones (asume sí)
  --noconfirm   Pasa --noconfirm a pacman/paru
  --no-aur      Omite paquetes AUR
  --mirrors     Refresca mirrorlist con reflector antes de instalar
  -h, --help    Esta ayuda

Ejemplos:
  ./install.sh --desktop --dry-run
  ./install.sh --dev --yes
  ./install.sh --full --mirrors
EOF
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --minimal) MODE="minimal" ;;
      --dev)     MODE="dev" ;;
      --desktop) MODE="desktop" ;;
      --full)    MODE="full" ;;
      --dry-run) DRY_RUN="true" ;;
      --yes)     ASSUME_YES="true" ;;
      --noconfirm) NOCONFIRM="true" ;;
      --no-aur)  SKIP_AUR="true" ;;
      --mirrors) DO_MIRRORS="true" ;;
      -h|--help) usage; exit 0 ;;
      *) error "Opción desconocida: $1"; usage; exit 1 ;;
    esac
    shift
  done
}

# Selecciona los profiles/*.txt según el modo.
select_profiles() {
  PROFILE_FILES=("$PROFILES_DIR/core.txt")
  case "$MODE" in
    minimal) ;;
    dev)     PROFILE_FILES+=("$PROFILES_DIR/dev.txt") ;;
    desktop) PROFILE_FILES+=("$PROFILES_DIR/dev.txt" "$PROFILES_DIR/desktop.txt") ;;
    full)    PROFILE_FILES+=("$PROFILES_DIR/dev.txt" "$PROFILES_DIR/desktop.txt" "$PROFILES_DIR/optional.txt") ;;
  esac
}

# Añade hardware (microcode siempre; GPU solo si hay desktop; laptop si aplica).
select_hardware() {
  HW_FILES=()
  EXTRA_PACKAGES=("linux-firmware")
  [[ -n "$DETECTED_UCODE" ]] && EXTRA_PACKAGES+=("$DETECTED_UCODE")

  [[ "$IS_LAPTOP" == "true" ]] && HW_FILES+=("$HARDWARE_DIR/laptop.txt")

  if [[ "$MODE" == "desktop" || "$MODE" == "full" ]]; then
    local g
    for g in "${DETECTED_GPU[@]}"; do
      [[ -f "$HARDWARE_DIR/gpu/$g.txt" ]] && HW_FILES+=("$HARDWARE_DIR/gpu/$g.txt")
    done
  fi
}

# ¿Toca instalar AUR en este modo?
aur_enabled() {
  [[ "$SKIP_AUR" == "true" ]] && return 1
  [[ "$MODE" == "minimal" ]] && return 1
  return 0
}

# ¿Hay que habilitar multilib? (lib32-* del perfil nvidia con desktop/full)
multilib_needed() {
  [[ "$MODE" == "desktop" || "$MODE" == "full" ]] || return 1
  [[ " ${DETECTED_GPU[*]} " == *" nvidia "* ]]
}

show_plan() {
  echo
  log "===== PLAN DE INSTALACIÓN ====="
  printf '  Modo:      %s\n' "$MODE"
  printf '  Dry-run:   %s\n' "$DRY_RUN"
  printf '  AUR:       %s\n' "$(aur_enabled && echo sí || echo no)"
  printf '  Multilib:  %s\n' "$(multilib_needed && echo sí || echo no)"
  printf '  Mirrors:   %s\n' "$DO_MIRRORS"
  printf '  Log:       %s\n' "$LOG_FILE"
  echo
  print_detection
  echo
  collect_packages "${PROFILE_FILES[@]}" "${HW_FILES[@]}"
  local repo_all=("${PACKAGES[@]}" "${EXTRA_PACKAGES[@]}")
  mapfile -t repo_all < <(printf '%s\n' "${repo_all[@]}" | sort -u)
  log "Paquetes de repos (${#repo_all[@]}): ${repo_all[*]}"
  if aur_enabled; then
    collect_packages "$PROFILES_DIR/aur.txt"
    log "Paquetes AUR (${#PACKAGES[@]}): ${PACKAGES[*]}"
  fi
  echo
}

main() {
  parse_args "$@"
  assert_arch
  log "ForgeOS install — modo: $MODE  (log: $LOG_FILE)"

  detect_all
  select_profiles
  select_hardware
  show_plan

  if ! confirm "¿Proceder con la instalación?"; then
    warn "Cancelado por el operador."
    exit 0
  fi

  # 1. Mirrors (opcional)
  [[ "$DO_MIRRORS" == "true" ]] && refresh_mirrors

  # 2. Multilib si hace falta
  if multilib_needed; then enable_multilib; fi

  # 3. Paquetes de repos (profiles + hardware + extras)
  collect_packages "${PROFILE_FILES[@]}" "${HW_FILES[@]}"
  local repo_all=("${PACKAGES[@]}" "${EXTRA_PACKAGES[@]}")
  mapfile -t repo_all < <(printf '%s\n' "${repo_all[@]}" | sort -u)
  install_repo_packages "${repo_all[@]}"

  # 4. AUR
  if aur_enabled; then
    collect_packages "$PROFILES_DIR/aur.txt"
    install_aur_packages "${PACKAGES[@]}"
  fi

  # 5. Dotfiles (skip elegante hasta Fase 2)
  backup_configs
  stow_dotfiles
  generate_gpu_config        # fragmento GPU dinámico según hardware
  generate_monitors_config   # fragmento monitores (B+A)
  install_wallpapers         # ← copia assets de wallpapers al usuario

  # 6. Post-install (servicios, docker, etc.)
  post_install

  echo
  ok "ForgeOS: instalación de modo '$MODE' completada."
  log "Revisa el log en: $LOG_FILE"
}

main "$@"
