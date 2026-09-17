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

## Repository layout

```text
arch-linux-fixes/
├── assets/
│   └── logo.png
├── firefox/
│   └── chatgpt-color-emoji/
│       ├── README.md
│       ├── fix.sh
│       └── rollback.sh
└── README.md
```

More categories will be added as fixes are tested and documented.

## Safety

Always read a patch README before running its script. Fixes that require `sudo`, modify `/etc`, affect bootloaders, kernels, drivers, filesystems or system services should be treated with extra care.

The scripts in this repository are intended to be transparent: you should be able to inspect exactly what will change before running them.

## Tested environment

The first fixes in this repository are being developed and tested primarily on:

- Arch Linux
- GNOME / Wayland
- Firefox

Individual patch pages contain their own tested-environment details.

## AI assistance

This project is developed, tested and documented with assistance from **ChatGPT by OpenAI**.

The final implementation and real-system testing are performed by the repository maintainer.

## Disclaimer

These fixes are community-maintained and are not official Arch Linux, Mozilla, OpenAI or GNOME support resources. Review scripts before executing them and keep backups of important data.
