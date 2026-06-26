#!/usr/bin/env bash
# lib/config.sh — variables globales de ForgeOS
# Sourced por install.sh y por los scripts/ standalone.

# Raíz del repo (resuelta desde la ubicación de este archivo)
: "${REPO_DIR:=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
PROFILES_DIR="$REPO_DIR/profiles"
HARDWARE_DIR="$REPO_DIR/hardware"
DOTFILES_DIR="$REPO_DIR/dotfiles"
SCRIPTS_DIR="$REPO_DIR/scripts"
LIB_DIR="$REPO_DIR/lib"

# Flags / modo (overridables por entorno o install.sh)
: "${MODE:=desktop}"          # minimal | dev | desktop | full
: "${DRY_RUN:=false}"
: "${ASSUME_YES:=false}"
: "${SKIP_AUR:=false}"
: "${DO_MIRRORS:=false}"
: "${NOCONFIRM:=false}"

# Log
: "${LOG_FILE:=/tmp/forgeos-$(date +%Y%m%d-%H%M%S).log}"

# Colores (solo si stdout es TTY)
if [[ -t 1 ]]; then
  C_RESET=$'\033[0m'; C_RED=$'\033[31m'; C_GREEN=$'\033[32m'
  C_YELLOW=$'\033[33m'; C_BLUE=$'\033[34m'; C_DIM=$'\033[2m'
else
  C_RESET=''; C_RED=''; C_GREEN=''; C_YELLOW=''; C_BLUE=''; C_DIM=''
fi

# Arrays/vars que rellena la detección
DETECTED_GPU=()
DETECTED_UCODE=""
IS_LAPTOP=false
HYBRID_GPU=false
