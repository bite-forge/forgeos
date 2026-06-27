#!/usr/bin/env bash
# lib/dotfiles.sh — backup de configs existentes + stow de dotfiles.
# dotfiles/ está vacío hasta Fase 2: las funciones hacen skip elegante.

# ¿Hay paquetes stow (subcarpetas) en dotfiles/?
_dotfiles_packages() {
  [[ -d "$DOTFILES_DIR" ]] || return 0
  find "$DOTFILES_DIR" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' 2>/dev/null || true
}

backup_configs() {
  local pkgs; mapfile -t pkgs < <(_dotfiles_packages)
  if ((${#pkgs[@]} == 0)); then
    warn "dotfiles/ vacío (Fase 2 pendiente) — sin backup que hacer"
    return 0
  fi
  local ts backupdir
  ts="$(date +%Y%m%d-%H%M%S)"
  backupdir="$HOME/.forgeos-config-backup-$ts"
  run mkdir -p "$backupdir"
  log "Backup de configs existentes → $backupdir"

  # Para cada paquete stow, copia los targets que ya existan en $HOME.
  local pkg target rel
  for pkg in "${pkgs[@]}"; do
    while IFS= read -r -d '' f; do
      rel="${f#"$DOTFILES_DIR/$pkg/"}"
      target="$HOME/$rel"
      if [[ -e "$target" && ! -L "$target" ]]; then
        run mkdir -p "$backupdir/$(dirname "$rel")"
        run cp -a "$target" "$backupdir/$rel"
      fi
    done < <(find "$DOTFILES_DIR/$pkg" -type f -print0 2>/dev/null)
  done
  ok "Backup completado"
}

stow_dotfiles() {
  local pkgs; mapfile -t pkgs < <(_dotfiles_packages)
  if ((${#pkgs[@]} == 0)); then
    warn "dotfiles/ vacío (Fase 2 pendiente) — nada que enlazar con stow"
    return 0
  fi
  command -v stow &>/dev/null || run maybe_sudo pacman -S --needed --noconfirm stow
  local pkg
  for pkg in "${pkgs[@]}"; do
    log "stow: $pkg → \$HOME"
    run stow --dir="$DOTFILES_DIR" --target="$HOME" --restow "$pkg"
  done
  ok "Dotfiles enlazados"
}

# Fragmentos de hardware para Hyprland. Los dotfiles NO contienen
# config de hardware: se genera aquí según detect.sh y Hyprland
# lo sourcea desde ~/.config/forgeos/ (fuera del árbol stow).

FORGEOS_GEN_DIR="$HOME/.config/forgeos"

# ── Helpers GPU ──────────────────────────────────────────────

# Devuelve la PCI address (0000:xx:xx.x) de la primera GPU de un vendor.
_pci_addr_for_vendor() {
  local vendor="$1" card v path
  for card in /sys/class/drm/card[0-9]*; do
    [[ -e "$card/device/vendor" ]] || continue
    v="$(cat "$card/device/vendor" 2>/dev/null)"
    if [[ "$v" == "$vendor" ]]; then
      path="$(readlink -f "$card/device")"
      basename "$path"
      return 0
    fi
  done
  return 1
}

# Regla udev para symlinks GPU estables (solo híbrido Intel+NVIDIA).
# AQ_DRM_DEVICES usa ':' como separador → las rutas by-path PCI rompen
# el parser. Symlinks propios (igpu/dgpu) sin ':' lo resuelven.
_gpu_udev_rule() {
  local rule="/etc/udev/rules.d/99-forgeos-gpu.rules"
  local intel_pci nvidia_pci
  intel_pci="$(_pci_addr_for_vendor 0x8086)"
  nvidia_pci="$(_pci_addr_for_vendor 0x10de)"

  if [[ -z "$intel_pci" || -z "$nvidia_pci" ]]; then
    warn "No se pudo resolver PCI de Intel/NVIDIA — regla udev omitida"
    return 0
  fi

  log "Regla udev GPU → $rule (igpu=$intel_pci dgpu=$nvidia_pci)"
  write_file "$rule" --sudo <<EOF
# ForgeOS — symlinks GPU estables por PCI (sin ':' para AQ_DRM_DEVICES)
KERNEL=="card*", KERNELS=="$intel_pci",  SYMLINK+="dri/igpu"
KERNEL=="card*", KERNELS=="$nvidia_pci", SYMLINK+="dri/dgpu"
EOF
  run maybe_sudo udevadm control --reload-rules
  run maybe_sudo udevadm trigger
}

# ── Fragmento GPU ────────────────────────────────────────────
generate_gpu_config() {
  local out="$FORGEOS_GEN_DIR/hardware-gpu.conf"
  run mkdir -p "$FORGEOS_GEN_DIR"

  local is_intel=false is_nvidia=false is_amd=false g
  for g in "${DETECTED_GPU[@]}"; do
    case "$g" in
      intel)  is_intel=true ;;
      nvidia) is_nvidia=true ;;
      amd)    is_amd=true ;;
    esac
  done

  # Caso 1: híbrido Intel + NVIDIA (Katana)
  if [[ "$HYBRID_GPU" == "true" ]]; then
    _gpu_udev_rule
    log "GPU config: híbrido Intel(primary)+NVIDIA(offload)"
    write_file "$out" <<'EOF'
# ── ForgeOS · GPU: híbrido Intel iGPU (primary) + NVIDIA dGPU (offload) ──
# Generado por el instalador. NO editar a mano — se regenera.
# Symlinks igpu/dgpu provistos por /etc/udev/rules.d/99-forgeos-gpu.rules
env = AQ_DRM_DEVICES,/dev/dri/igpu:/dev/dri/dgpu
env = LIBVA_DRIVER_NAME,nvidia
env = __GLX_VENDOR_LIBRARY_NAME,nvidia
env = NVD_BACKEND,direct
EOF
    ok "hardware-gpu.conf (híbrido) → $out"
    return 0
  fi

  # Caso 2: AMD solo (WS2)
  if [[ "$is_amd" == "true" ]]; then
    log "GPU config: AMD"
    write_file "$out" <<'EOF'
# ── ForgeOS · GPU: AMD Radeon ──
# Generado por el instalador. NO editar a mano — se regenera.
env = LIBVA_DRIVER_NAME,radeonsi
EOF
    ok "hardware-gpu.conf (AMD) → $out"
    return 0
  fi

  # Caso 3: Intel solo
  if [[ "$is_intel" == "true" ]]; then
    log "GPU config: Intel"
    write_file "$out" <<'EOF'
# ── ForgeOS · GPU: Intel ──
# Generado por el instalador. NO editar a mano — se regenera.
env = LIBVA_DRIVER_NAME,iHD
EOF
    ok "hardware-gpu.conf (Intel) → $out"
    return 0
  fi

  # Caso 4: NVIDIA sola (dGPU única)
  if [[ "$is_nvidia" == "true" ]]; then
    log "GPU config: NVIDIA (única)"
    write_file "$out" <<'EOF'
# ── ForgeOS · GPU: NVIDIA (única) ──
# Generado por el instalador. NO editar a mano — se regenera.
env = LIBVA_DRIVER_NAME,nvidia
env = __GLX_VENDOR_LIBRARY_NAME,nvidia
env = NVD_BACKEND,direct
EOF
    ok "hardware-gpu.conf (NVIDIA) → $out"
    return 0
  fi

  warn "Sin GPU reconocida — hardware-gpu.conf placeholder"
  write_file "$out" <<'EOF'
# ── ForgeOS · GPU: no detectada ──
EOF
}

# ── Helpers monitores ────────────────────────────────────────

# Detecta el conector de panel interno conectado (eDP-1, LVDS-1...)
# vía sysfs. Funciona sin Hyprland corriendo (entorno post-install).
# Devuelve el nombre del conector o vacío.
_detect_internal_panel() {
  local card status name
  for card in /sys/class/drm/card*-eDP-* /sys/class/drm/card*-LVDS-*; do
    [[ -e "$card/status" ]] || continue
    status="$(cat "$card/status" 2>/dev/null)"
    if [[ "$status" == "connected" ]]; then
      # card1-eDP-1 → eDP-1
      name="${card##*/card[0-9]-}"
      printf '%s' "$name"
      return 0
    fi
  done
  return 1
}

# Lee el modo preferido del conector (primera línea de 'modes' suele
# ser el preferido). Devuelve algo como "1920x1080" o vacío.
_panel_preferred_mode() {
  local connector="$1" card modefile
  for card in /sys/class/drm/card*-"$connector"; do
    modefile="$card/modes"
    [[ -e "$modefile" ]] || continue
    head -1 "$modefile" 2>/dev/null
    return 0
  done
  return 1
}

# ── Fragmento monitores (B+A) ────────────────────────────────
# B: default `,preferred,auto,1` que SIEMPRE funciona (resolución
#    nativa, sin scale).
# A: si detecta el panel interno por sysfs, añade una línea
#    específica COMENTADA con el modo detectado, para que el
#    usuario solo descomente y afine el scale si quiere.
generate_monitors_config() {
  local out="$FORGEOS_GEN_DIR/monitors.conf"
  run mkdir -p "$FORGEOS_GEN_DIR"

  local panel mode hint=""
  panel="$(_detect_internal_panel || true)"
  if [[ -n "$panel" ]]; then
    mode="$(_panel_preferred_mode "$panel" || true)"
    if [[ -n "$mode" ]]; then
      hint="# Panel detectado: $panel @ ${mode}. Descomenta y ajusta scale si quieres:
# monitor = $panel, ${mode}@60, 0x0, 1.0"
      log "Monitor detectado: $panel @ $mode"
    else
      hint="# Panel detectado: $panel (modo no resuelto).
# monitor = $panel, preferred, 0x0, 1.0"
      log "Monitor detectado: $panel (sin modo)"
    fi
  else
    hint="# No se detectó panel interno por sysfs (¿desktop?).
# Añade tu monitor manualmente si necesitas afinar."
    log "Monitor: sin panel interno detectado"
  fi

  write_file "$out" <<EOF
# ── ForgeOS · monitors.conf ──
# Generado por el instalador. NO editar a mano — se regenera.
# El default de abajo funciona en cualquier panel a resolución
# nativa sin escalado. Para afinar (scale, posición, refresh),
# descomenta la línea sugerida o añade la tuya.

# Default universal: resolución preferida, sin scale
monitor = , preferred, auto, 1

$hint
EOF
  ok "monitors.conf → $out"
}

# Copia los wallpapers del repo (assets, no config) a la carpeta
# del usuario. No van por stow: son binarios, no configs enlazables.

install_wallpapers() {
  local src="$REPO_DIR/wallpapers"
  local dst="$HOME/Pictures/Wallpapers/ForgeOS"

  if [[ ! -d "$src" ]]; then
    warn "wallpapers/ no existe en el repo — omitido"
    return 0
  fi

  run mkdir -p "$dst"

  local count=0 f
  shopt -s nullglob
  for f in "$src"/*.png "$src"/*.jpg "$src"/*.jpeg; do
    [[ -e "$f" ]] || continue
    if [[ "$DRY_RUN" == "true" ]]; then
      printf '%b[dry-run]%b cp → %s\n' "$C_DIM" "$C_RESET" "$dst/$(basename "$f")"
    else
      cp -n "$f" "$dst/" 2>/dev/null || true
    fi
    ((count++)) || true
  done
  shopt -u nullglob

  if (( count > 0 )); then
    ok "Wallpapers instalados ($count) → $dst"
  else
    warn "Sin imágenes en $src"
  fi
}
