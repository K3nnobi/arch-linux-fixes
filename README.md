<p align="center">
  <img src="assets/logo.png" alt="Arch Linux Fixes logo" width="240">
</p>

<h1 align="center">Arch Linux Fixes</h1>

<p align="center">
  Practical fixes, patches and troubleshooting notes for real problems encountered while using Arch Linux.
</p>

<p align="center">
  <strong>Diagnose. Fix. Understand. Roll back safely.</strong>
</p>

---

The goal of this repository is simple: document the **problem**, explain the **cause**, provide a **manual fix**, offer an **automatic script when appropriate**, and include a **safe rollback path**.

## Philosophy

- Real issues reproduced on actual Arch Linux systems
- Small, focused fixes instead of giant post-install scripts
- Clear explanation of what each patch changes
- Backups before modifying user configuration
- Idempotent scripts whenever possible
- Rollback instructions for every fix that changes configuration
- No silent destructive actions

## Fixes

### Firefox

- [ChatGPT Color Emoji Fix](firefox/chatgpt-color-emoji/README.md) — fixes mixed monochrome/color emoji rendering in ChatGPT while preserving normal text spacing and typography.

### GNOME / Wayland

- [Caps Lock No Delay](gnome/caps-lock-no-delay/README.md) — removes the observed delay when turning Caps Lock off quickly by using a safe `keyd` mapping.
- [GNOME Drag Hover Raise](gnome/drag-hover-raise/README.md) — raises application windows while dragging files over Dash to Dock icons or visible portions of partially covered windows.
- [Blur My Shell — Rounded Dynamic Blur Corners](gnome/blur-my-shell-rounded-corners/README.md) — installs the `gnome-rounded-blur` compatibility library so dynamic Blur My Shell effects can follow rounded GNOME corners instead of showing square blur edges.
- [Nautilus Windows EXE Thumbnails](gnome/nautilus-exe-thumbnails/README.md) — displays embedded Windows executable icons as Nautilus thumbnails and removes the unwanted transparent-thumbnail background.

### Gaming

- [GameMode + Blur My Shell](gaming/gamemode-blur-my-shell/README.md) — experimental integration recovered from ArchMind 1.5.11 that temporarily suspends Blur My Shell while GameMode is active and restores only the extensions that were enabled before the game started.

### NVIDIA

- [NVIDIA Digital Vibrance Autoload](nvidia/nvibrant-autoload/README.md) — reapplies a chosen `nvibrant` intensity automatically after login through a delayed `systemd --user` service.

### Boot

- [Plymouth + GRUB Clean Boot](boot/plymouth-grub-clean-boot/README.md) — confirmed clean graphical boot procedure for GRUB + traditional `mkinitcpio`/`udev`; published as a manual high-risk guide rather than unsafe one-click automation.

## Repository layout

```text
arch-linux-fixes/
├── assets/
│   └── logo.png
├── boot/
│   └── plymouth-grub-clean-boot/
│       └── README.md
├── firefox/
│   └── chatgpt-color-emoji/
│       ├── README.md
│       ├── fix.sh
│       └── rollback.sh
├── gaming/
│   └── gamemode-blur-my-shell/
│       ├── README.md
│       ├── fix.sh
│       ├── gamemode-blur.sh
│       ├── test.sh
│       └── rollback.sh
├── gnome/
│   ├── blur-my-shell-rounded-corners/
│   │   ├── README.md
│   │   ├── fix.sh
│   │   └── rollback.sh
│   ├── caps-lock-no-delay/
│   │   ├── README.md
│   │   ├── fix.sh
│   │   └── rollback.sh
│   ├── drag-hover-raise/
│   │   ├── README.md
│   │   ├── fix.sh
│   │   └── rollback.sh
│   └── nautilus-exe-thumbnails/
│       ├── README.md
│       ├── fix.sh
│       └── rollback.sh
├── nvidia/
│   └── nvibrant-autoload/
│       ├── README.md
│       ├── fix.sh
│       └── rollback.sh
└── README.md
```

More categories will be added as fixes are tested and documented.

## Safety

Always read a patch README before running its script. Fixes that require `sudo`, modify `/etc`, affect bootloaders, kernels, drivers, filesystems or system services should be treated with extra care.

The scripts in this repository are intended to be transparent: you should be able to inspect exactly what will change before running them.

Version-sensitive patches intentionally abort when the detected software version or file structure is outside the environment that was actually tested.

Experimental patches are labeled explicitly when automated validation exists but final real-session testing has not been recorded.

High-risk boot fixes may be documented without an automatic installer until a standalone implementation can safely validate and roll back every supported layout.

## Tested environment

The first fixes in this repository are being developed and tested primarily on:

- Arch Linux
- GNOME / Wayland
- Firefox
- NVIDIA where explicitly stated by an individual patch

Individual patch pages contain their own tested-environment details and limitations.

## AI assistance

This project is developed, tested and documented with assistance from **ChatGPT by OpenAI**.

The final implementation and real-system testing are performed by the repository maintainer.

## Disclaimer

These fixes are community-maintained and are not official Arch Linux, Mozilla, OpenAI, NVIDIA or GNOME support resources. Review scripts before executing them and keep backups of important data.
