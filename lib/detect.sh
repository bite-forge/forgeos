#!/usr/bin/env bash
# lib/detect.sh — detección de hardware. Rellena variables de config.sh.

detect_gpu() {
  DETECTED_GPU=()
  local info
  info="$(lspci 2>/dev/null | grep -Ei 'vga|3d|display' || true)"

  if grep -qiE 'amd|ati|radeon' <<<"$info"; then DETECTED_GPU+=("amd"); fi
  if grep -qi  'intel'          <<<"$info"; then DETECTED_GPU+=("intel"); fi
  if grep -qi  'nvidia'         <<<"$info"; then DETECTED_GPU+=("nvidia"); fi

  # Caso híbrido (p.ej. Katana: Intel iGPU + NVIDIA dGPU)
  if [[ " ${DETECTED_GPU[*]} " == *" intel "* && " ${DETECTED_GPU[*]} " == *" nvidia "* ]]; then
    HYBRID_GPU=true
  fi
}

detect_cpu() {
  if grep -qi 'AuthenticAMD' /proc/cpuinfo 2>/dev/null; then
    DETECTED_UCODE="amd-ucode"
  elif grep -qi 'GenuineIntel' /proc/cpuinfo 2>/dev/null; then
    DETECTED_UCODE="intel-ucode"
  else
    DETECTED_UCODE=""
  fi
}

detect_laptop() {
  if compgen -G "/sys/class/power_supply/BAT*" >/dev/null 2>&1; then
    IS_LAPTOP=true
  else
    IS_LAPTOP=false
  fi
}

detect_all() {
  detect_gpu
  detect_cpu
  detect_laptop
}

print_detection() {
  log "Hardware detectado:"
  printf '  GPU:       %s\n' "${DETECTED_GPU[*]:-ninguna detectada}"
  printf '  Microcode: %s\n' "${DETECTED_UCODE:-(desconocido)}"
  printf '  Laptop:    %s\n' "$IS_LAPTOP"
  if [[ "$HYBRID_GPU" == "true" ]]; then
    warn "GPU HÍBRIDA detectada (Intel + NVIDIA)."
    warn "Se instalan ambos perfiles. Config de Hyprland (AQ_DRM_DEVICES, modeset) → Fase 2."
  fi
}
