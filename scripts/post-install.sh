#!/usr/bin/env bash
# scripts/post-install.sh — configuración post-instalación.
# Ejecutable standalone (./scripts/post-install.sh) o llamado por install.sh.
set -euo pipefail

# Cargar libs si se ejecuta directamente
if [[ -z "${REPO_DIR:-}" ]]; then
  SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
  REPO_DIR="$SELF_DIR"
  source "$REPO_DIR/lib/config.sh"
  source "$REPO_DIR/lib/utils.sh"
fi

post_install() {
  log "== Post-install =="

  # 1. Servicios systemd (solo si la unit existe)
  enable_service docker.service
  enable_service greetd.service
  enable_service bluetooth.service
  enable_service tlp.service
  enable_service NetworkManager.service

  # systemd-oomd viene con systemd: habilitar el manejador de OOM en userspace
  enable_service systemd-oomd.service

  # 2. Docker sin sudo (grupo docker)
  if getent group docker &>/dev/null; then
    if id -nG "$USER" | grep -qw docker; then
      ok "Usuario ya en grupo docker"
    else
      log "Añadiendo $USER al grupo docker (requiere re-login)"
      run maybe_sudo usermod -aG docker "$USER"
    fi
  fi

  # 3. Git global (solo si no está configurado; no interactivo)
  if ! git config --global user.name &>/dev/null; then
    warn "git user.name/email sin configurar. Ejecuta cuando quieras:"
    warn "  git config --global user.name  \"Tu Nombre\""
    warn "  git config --global user.email \"tu@email\""
  fi

  # 4. Node vía fnm (entorno de usuario, no system-wide)
  if command -v fnm &>/dev/null; then
    warn "Node: completa el setup en tu shell:"
    warn "  fnm install --lts && fnm default lts-latest && corepack enable"
  fi

  # 5. Shell por defecto: fish (idempotente)
  local fish_bin
  fish_bin="$(command -v fish || true)"
  if [[ -n "$fish_bin" ]]; then
    # Asegura que fish está en /etc/shells (chsh lo exige)
    if ! grep -qx "$fish_bin" /etc/shells 2>/dev/null; then
      log "Registrando $fish_bin en /etc/shells"
      echo "$fish_bin" | run maybe_sudo tee -a /etc/shells >/dev/null
    fi
    # Cambia el shell solo si no es ya fish
    if [[ "$(getent passwd "$USER" | cut -d: -f7)" != "$fish_bin" ]]; then
      log "Cambiando shell de $USER a fish"
      run maybe_sudo chsh -s "$fish_bin" "$USER"
    else
      ok "Shell ya es fish"
    fi
  else
    warn "fish no encontrado — shell sin cambiar"
  fi

  ok "Post-install completado."
  log "Reinicia o re-loguea para aplicar grupos y el display manager."
}

# Auto-ejecutar solo si se invoca directamente (no al hacer source)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  post_install
fi
