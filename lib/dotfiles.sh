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
