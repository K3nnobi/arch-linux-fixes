# NVIDIA Digital Vibrance Autoload

Applies NVIDIA Digital Vibrance automatically after login by using a small `systemd --user` oneshot service.

## Status

**Tested and working** on the original Arch Linux setup where this fix was created:

- Arch Linux
- GNOME / Wayland
- NVIDIA GPU
- `nvibrant`
- tested value: `512`
- delayed startup: `5 seconds`

The delay is intentional: it gives the graphical session and NVIDIA driver time to become available before the vibrance command is executed.

## Dependency

Install `nvibrant` from the AUR first. For example, with an existing AUR helper:

```bash
yay -S nvibrant
```

Some systems may use the `nvibrant-bin` package instead. This repository does **not** bootstrap an AUR helper automatically.

Verify:

```bash
command -v nvibrant
```

Expected executable on the tested setup:

```text
/usr/bin/nvibrant
```

## Intensity

The original tested setup used:

```text
512
```

Reference range used by `nvibrant`:

```text
0    = default / no extra vibrance
1023 = maximum
```

`512` is a tested example, **not a universal recommendation**. Choose a value that looks correct on your own monitor.

## Automatic install

Default tested value:

```bash
chmod +x fix.sh
./fix.sh
```

Custom value:

```bash
./fix.sh 650
```

Accepted range:

```text
0..1023
```

The script:

- verifies Arch Linux;
- verifies that an NVIDIA GPU can be detected;
- requires an existing `nvibrant` executable;
- validates the requested intensity;
- backs up any pre-existing `nvibrant.service` before replacing it;
- creates `~/.config/systemd/user/nvibrant.service`;
- waits 5 seconds after user-session startup;
- runs `/usr/bin/nvibrant <value>`;
- enables the user service;
- records rollback state under `~/.local/state/arch-linux-fixes/nvibrant-autoload/`.

## Generated service

Equivalent configuration:

```ini
[Unit]
Description=Apply NVIDIA Digital Vibrance
After=graphical.target

[Service]
Type=oneshot
ExecStartPre=/bin/sleep 5
ExecStart=/usr/bin/nvibrant 512

[Install]
WantedBy=default.target
```

The actual command path and selected value are written by the installer.

## Verification

```bash
systemctl --user is-enabled nvibrant.service
systemctl --user status nvibrant.service
journalctl --user -u nvibrant.service -b
```

Because this is a `Type=oneshot` service, it does not need to remain running after `nvibrant` has successfully applied the setting.

## Change intensity

Simply run the installer again with another value:

```bash
./fix.sh 700
```

The installer recognizes its own managed service and does not overwrite the original pre-patch backup when changing the value.

## Rollback

```bash
chmod +x rollback.sh
./rollback.sh
```

Rollback disables the managed autoload service and:

- restores the exact `nvibrant.service` that existed before this patch, if one existed;
- otherwise removes only the service created by this repository.

It does **not** uninstall `nvibrant` and does not attempt to guess what the user's previous vibrance value was.

## Safety

This is a per-user configuration. It does not modify `/etc`, the bootloader, the kernel or the NVIDIA driver.

The script intentionally refuses to run when it cannot detect an NVIDIA GPU or when `nvibrant` is missing.
