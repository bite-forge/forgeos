# Soporte de hardware — ForgeOS

`lib/detect.sh` selecciona perfiles según el hardware real.

## Detección

| Componente | Método | Resultado |
|---|---|---|
| GPU | `lspci \| grep -Ei 'vga\|3d\|display'` | carga `hardware/gpu/{amd,intel,nvidia}.txt` |
| CPU | `/proc/cpuinfo` | `amd-ucode` o `intel-ucode` |
| Laptop | `/sys/class/power_supply/BAT*` | carga `hardware/laptop.txt` |

## Matriz perfiles × máquinas

| Máquina | GPU | Perfil(es) | Estado |
|---|---|---|---|
| Katana (MSI, i7 12th) | Intel iGPU + RTX 4060 | intel + nvidia (HÍBRIDO) | banco de pruebas |
| WS2 (ThinkPad T14s) | AMD (Radeon) | amd | target final |

## Caso híbrido (Katana)

Intel iGPU primaria + NVIDIA dGPU para offload (PRIME render offload).
Pendiente de Fase 2 (config Hyprland):

- `env = AQ_DRM_DEVICES,<card-intel>:<card-nvidia>` (iGPU primero)
- Módulos initramfs: `nvidia nvidia_modeset nvidia_uvm nvidia_drm`
- Param kernel: `nvidia_drm.modeset=1`
- `lib32-nvidia-utils` requiere `[multilib]` (lo habilita `install.sh`)
