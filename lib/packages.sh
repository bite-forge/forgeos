#!/usr/bin/env bash
# lib/packages.sh — manejo de paquetes (repos + AUR).

# Lee un .txt: quita comentarios y vacíos, un paquete por token.
read_profile() {
  local f="$1"
  [[ -f "$f" ]] || return 0
  sed 's/#.*//' "$f" | tr -s '[:space:]' '\n' | grep -v '^$' || true
}

# Acumula paquetes únicos de varios archivos en el array global PACKAGES.
# Uso: collect_packages file1 file2 ...
collect_packages() {
  local all=() f p
  for f in "$@"; do
    while IFS= read -r p; do
      [[ -n "$p" ]] && all+=("$p")
    done < <(read_profile "$f")
  done
  if ((${#all[@]})); then
    mapfile -t PACKAGES < <(printf '%s\n' "${all[@]}" | sort -u)
  else
    PACKAGES=()
  fi
}

# Habilita [multilib] en pacman.conf (necesario para lib32-*).
enable_multilib() {
  if maybe_sudo grep -q '^\[multilib\]' /etc/pacman.conf 2>/dev/null; then
    ok "[multilib] ya habilitado"
    return 0
  fi
  warn "Habilitando [multilib] en /etc/pacman.conf"
  run maybe_sudo cp /etc/pacman.conf /etc/pacman.conf.forgeos.bak
  run maybe_sudo sed -i '/^#\[multilib\]/,/^#Include/ s/^#//' /etc/pacman.conf
  run maybe_sudo pacman -Sy
}

# Actualiza mirrors con reflector (opcional, --mirrors).
refresh_mirrors() {
  command -v reflector &>/dev/null || run maybe_sudo pacman -S --needed --noconfirm reflector
  log "Actualizando mirrorlist con reflector (puede tardar)…"
  run maybe_sudo cp /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist.forgeos.bak
  run maybe_sudo reflector --country Spain,France,Germany --age 12 \
      --protocol https --sort rate --save /etc/pacman.d/mirrorlist
  run maybe_sudo pacman -Sy
}

# Instala paquetes de repos oficiales.
install_repo_packages() {
  local pkgs=("$@")
  ((${#pkgs[@]})) || { warn "Sin paquetes de repos que instalar"; return 0; }
  local nc=()
  [[ "$NOCONFIRM" == "true" ]] && nc=(--noconfirm)
  log "Instalando ${#pkgs[@]} paquetes de repos…"
  run maybe_sudo pacman -S --needed "${nc[@]}" "${pkgs[@]}"
}

# Bootstrap de paru respetando el flujo de revisión de PKGBUILD.
ensure_paru() {
  if command -v paru &>/dev/null; then ok "paru ya instalado"; return 0; fi
  log "paru no encontrado — bootstrap desde AUR"
  run maybe_sudo pacman -S --needed --noconfirm base-devel git

  local tmp; tmp="$(mktemp -d)"
  run git clone https://aur.archlinux.org/paru.git "$tmp/paru"

  if [[ "$DRY_RUN" == "true" ]]; then
    log "[dry-run] cat PKGBUILD; (cd $tmp/paru && makepkg -si)"
    return 0
  fi

  warn "Revisa el PKGBUILD de paru antes de compilar (flujo de seguridad AUR):"
  echo "--------------------------------------------------------------------"
  ${PAGER:-less} "$tmp/paru/PKGBUILD" 2>/dev/null || cat "$tmp/paru/PKGBUILD"
  echo "--------------------------------------------------------------------"
  if confirm "¿PKGBUILD revisado y OK para compilar paru?"; then
    ( cd "$tmp/paru" && makepkg -si )
  else
    error "Bootstrap de paru abortado por el operador"
    return 1
  fi
}

# Instala paquetes AUR con paru.
install_aur_packages() {
  local pkgs=("$@")
  ((${#pkgs[@]})) || { warn "Sin paquetes AUR que instalar"; return 0; }
  ensure_paru || return 1
  local nc=()
  [[ "$NOCONFIRM" == "true" ]] && nc=(--noconfirm)
  log "Instalando ${#pkgs[@]} paquetes AUR…"
  run paru -S --needed "${nc[@]}" "${pkgs[@]}"
}
