# Caps Lock No Delay

Fixes the small but annoying delay that can occur after turning Caps Lock off, where the next quickly typed letter may still be uppercase.

## Status

**Tested and working** on:

- Arch Linux
- GNOME Shell 50.4
- Wayland
- `keyd`

The tested result preserved normal Caps Lock behavior and LED state, while the first letter typed immediately after Caps Lock OFF returned to lowercase without the observed delay.

## Problem

Typical sequence:

```text
Caps Lock ON
TYPE TEXT
Caps Lock OFF
immediately type again
```

On the affected setup, the first letter after Caps Lock OFF could still be uppercase when typing very quickly.

## Fix

The solution uses `keyd`, which works below the desktop/session layer and therefore does not depend on X11, `xmodmap`, `xdotool` or GNOME-specific keyboard automation.

The important rule is:

```ini
capslock = macro(capslock)
```

This makes `keyd` generate a controlled full Caps Lock press/release cycle.

The tested configuration also used:

```ini
[global]
macro_timeout = 600000

[ids]
*

[main]
capslock = macro(capslock)
```

## Automatic install

```bash
chmod +x fix.sh
./fix.sh
```

The script:

- verifies Arch Linux;
- installs `keyd` with Pacman if needed;
- preserves an existing `/etc/keyd/default.conf`;
- refuses to overwrite an existing custom Caps Lock mapping;
- adds only managed Arch Linux Fixes blocks;
- enables and starts `keyd`;
- reloads the configuration;
- stores rollback state under `~/.local/state/arch-linux-fixes/caps-lock-no-delay/`.

## Manual verification

```bash
pacman -Q keyd
systemctl is-active keyd
systemctl is-enabled keyd
grep -n 'ARCH_LINUX_FIXES_CAPSLOCK_NODELAY' /etc/keyd/default.conf
```

Then type quickly several times:

```text
CAPS ON
ABC
CAPS OFF
abc
```

## Rollback

```bash
chmod +x rollback.sh
./rollback.sh
```

If a configuration existed before the patch, the rollback script restores that exact saved copy. If the patch created the file from scratch, it removes that managed configuration.

The package itself is intentionally **not uninstalled automatically** during rollback because another configuration may depend on `keyd`.

## Important safety notes

`keyd` is a system input daemon and has access to keyboard/input devices. Do not make `/etc/keyd` world-writable and do not blindly replace existing keyboard remaps.

If the installer detects another rule such as:

```ini
capslock = esc
```

or:

```ini
capslock = control
```

it aborts instead of replacing it.

## Why this approach

This avoids editing internal XKB files under `/usr/share/X11/xkb/`, avoids X11-only tools, works on Wayland, and is straightforward to back up and reverse.
