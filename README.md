# ForgeOS

Distro Arch enfocada en desarrollo web. Un núcleo (manifiesto de paquetes + dotfiles)
consumido por capas de entrega progresivas. Bootstrap desde un Arch limpio con un comando.

> Doc canon completo: `forgeos.md`. Esto es solo el repo de la Capa 1.

## Uso rápido

```bash
git clone <repo> forgeos && cd forgeos

# Ver qué haría, sin tocar nada (SIEMPRE primero):
./install.sh --desktop --dry-run

# Instalar:
./install.sh --desktop
```

## Modos

| Modo | Incluye |
|---|---|
| `--minimal` | core |
| `--dev` | core + dev + AUR |
| `--desktop` | core + dev + desktop + AUR (default) |
| `--full` | core + dev + desktop + optional + AUR |

## Opciones

`--dry-run` · `--yes` · `--noconfirm` · `--no-aur` · `--mirrors` · `--help`

## Estructura

- `profiles/` — manifiestos de paquetes (core, dev, desktop, aur, optional)
- `hardware/` — perfiles por GPU/CPU/laptop (auto-detectados)
- `lib/` — librerías modulares (config, utils, detect, packages, dotfiles)
- `scripts/` — post-install y validador (ejecutables standalone)
- `dotfiles/` — configs propias con `stow` (Fase 2)

## Validar paquetes

```bash
./scripts/validate-packages.sh
```

## Hardware

Auto-detección de GPU (AMD/Intel/NVIDIA, incluido híbrido), CPU (microcode) y laptop (tlp).
Ver `docs/hardware-support.md`.
