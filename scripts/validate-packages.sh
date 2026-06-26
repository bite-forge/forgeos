#!/usr/bin/env bash
# scripts/validate-packages.sh — valida que todos los paquetes existen.
# Repos: pacman -Si | AUR: paru -Si (si paru está). Salida != 0 si falta alguno.
set -euo pipefail

if [[ -z "${REPO_DIR:-}" ]]; then
  REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
  source "$REPO_DIR/lib/config.sh"
  source "$REPO_DIR/lib/utils.sh"
fi
source "$REPO_DIR/lib/packages.sh"

validate_packages() {
  local repo_files=(
    "$PROFILES_DIR/core.txt"
    "$PROFILES_DIR/dev.txt"
    "$PROFILES_DIR/desktop.txt"
    "$PROFILES_DIR/optional.txt"
    "$HARDWARE_DIR/gpu/amd.txt"
    "$HARDWARE_DIR/gpu/intel.txt"
    "$HARDWARE_DIR/gpu/nvidia.txt"
    "$HARDWARE_DIR/laptop.txt"
  )
  local aur_file="$PROFILES_DIR/aur.txt"

  local missing_repo=() missing_aur=() pkg

  log "Validando paquetes de repos oficiales…"
  collect_packages "${repo_files[@]}"
  for pkg in "${PACKAGES[@]}"; do
    if ! pacman -Si "$pkg" &>/dev/null; then
      missing_repo+=("$pkg")
    fi
  done

  log "Validando paquetes AUR…"
  collect_packages "$aur_file"
  if command -v paru &>/dev/null; then
    for pkg in "${PACKAGES[@]}"; do
      paru -Si "$pkg" &>/dev/null || missing_aur+=("$pkg")
    done
  else
    warn "paru no instalado — AUR sin validar: ${PACKAGES[*]}"
  fi

  echo
  if ((${#missing_repo[@]} == 0)); then
    ok "Repos: todos los paquetes existen"
  else
    error "Repos: NO encontrados → ${missing_repo[*]}"
  fi
  if ((${#missing_aur[@]} == 0)); then
    ok "AUR: sin faltantes detectados"
  else
    error "AUR: NO encontrados → ${missing_aur[*]}"
  fi

  ((${#missing_repo[@]} + ${#missing_aur[@]} == 0))
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  validate_packages
fi
