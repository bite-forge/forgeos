# ForgeOS — Ajustes post-instalación

Ajustes recomendados tras una instalación limpia. No los automatiza el
instalador (algunos tocan el cmdline del kernel, demasiado crítico para
parchear a ciegas). Aplícalos a mano según la máquina.

> Cuando exista la Capa 2 (archinstall automation), el cmdline base se
> generará con estos parámetros de forma controlada.

---

## 1. Arranque limpio (cmdline quiet)

Por defecto, los logs de systemd/kernel se mezclan visualmente con tuigreet
(ambos en vt 1). Para un arranque silencioso de distro:

Edita el cmdline del kernel:

```bash
sudo nano /etc/kernel/cmdline
```

Añade al final de la línea (sin borrar lo existente, que es específico de
la máquina — cryptdevice, root, etc.):

```
quiet loglevel=3 rd.udev.log_level=3 vt.global_cursor_default=0
```

Regenera la UKI:

```bash
sudo mkinitcpio -P
```

Reinicia. El arranque será silencioso y tuigreet aparecerá limpio.

**Alternativa/complemento:** mover greetd a un VT dedicado (vt 7) en
`/etc/greetd/config.toml` (`vt = 7`), libre de logs de arranque.

---

## 2. Scale del monitor

El instalador genera `~/.config/forgeos/monitors.conf` con el default
universal (`,preferred,auto,1`), que funciona a resolución nativa sin escalado.

Si tu panel necesita escalado (paneles pequeños de alta densidad), descomenta
la línea sugerida en ese archivo y ajusta el último valor:

```
# 1.0 = sin escala | 1.25 = 125% | 1.5 = 150%
monitor = eDP-1, 1920x1080@60, 0x0, 1.25
```

Aplica con `hyprctl reload` o relog.

---

## 3. Firewall (ufw)

`ufw` se instala pero NO se habilita ni configura automáticamente (habilitarlo
a ciegas puede cortar WireGuard/SSH). Configúralo a conciencia:

```bash
# ejemplo base workstation — ajusta a tus necesidades
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow 51820/udp   # WireGuard, si aplica
sudo ufw enable
```

---

## 4. Snapshots btrfs (snapper)

`snapper` y `btrfs-progs` se instalan pero snapper no se configura. Para
snapshots automáticos del root:

```bash
sudo snapper -c root create-config /
sudo systemctl enable --now snapper-timeline.timer
sudo systemctl enable --now snapper-cleanup.timer
```

---

## 5. Node (fnm)

El instalador avisa pero no completa el setup de Node. En tu shell:

```bash
fnm install --lts
fnm default lts-latest
corepack enable
```

---

## 6. Git global

Configura identidad git si no lo está:

```bash
git config --global user.name  "Tu Nombre"
git config --global user.email "tu@email"
```

---

## 7. Servicios que requieren re-login

Tras la instalación, re-loguea o reinicia para aplicar:
- Grupo `docker` (docker sin sudo)
- Shell por defecto (fish)
- Display manager (greetd)

---

## 8. Hyprlock — compatibilidad de versión

`hyprlock.conf` puede usar opciones que varían entre versiones. Si al lanzar
`hyprlock` ves errores `config option <X> does not exist`, esa opción cambió
en tu versión. hyprlock ignora las inválidas y arranca igual, pero conviene
limpiarlas. Verifica opciones válidas con la doc de tu versión instalada.

---

*ForgeOS — ajustes post-instalación. Se integrarán en Capa 2 (archinstall).*
