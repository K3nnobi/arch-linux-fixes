# Blur My Shell — Rounded Dynamic Blur Corners

Fixes the square-corner problem that can appear when **Blur My Shell** uses dynamic blur on rounded GNOME surfaces/windows.

This is the same solution previously integrated into ArchMind as `gnome-rounded-blur` support.

## What this actually fixes

Blur My Shell can apply dynamic background blur, but the normal GNOME Shell blur effect does not always provide the corner mask needed to make that blur follow rounded corners correctly.

The `gnome-rounded-blur` compatibility library provides a `Blur.BlurEffect` implementation with `corner_radius` support. Blur My Shell can detect that library and use it for rounded dynamic blur.

Upstream Blur My Shell currently documents this library as the compatibility solution for rounded dynamic blur corners.

## Historical ArchMind implementation

The original ArchMind GNOME appearance module installed:

```bash
yay -S --needed gnome-rounded-blur
```

and checked Blur My Shell's detection key:

```text
/org/gnome/shell/extensions/blur-my-shell/rounded-blur-found
```

A successful detection returns:

```text
true
```

The ArchMind module also warned that after a GNOME Shell/Mutter update the package may need to be rebuilt:

```bash
yay -S --rebuild gnome-rounded-blur
```

## Requirements

- Arch Linux or an Arch-based system
- GNOME Shell
- Blur My Shell installed
- an AUR helper (`yay` or `paru`)

Blur My Shell extension UUID:

```text
blur-my-shell@aunetx
```

## Install

```bash
chmod +x fix.sh
./fix.sh
```

The script:

- verifies Arch Linux;
- verifies GNOME Shell;
- checks whether Blur My Shell is installed;
- uses an already-installed `yay` or `paru`;
- installs `gnome-rounded-blur` from the AUR;
- records whether the package already existed before this patch;
- checks Blur My Shell's `rounded-blur-found` state;
- never logs out the user automatically.

After installation, **log out and back in** so GNOME Shell can load the library.

Then verify:

```bash
./fix.sh --check
```

Expected result:

```text
rounded-blur-found=true
```

## After GNOME Shell or Mutter updates

This library is built against GNOME/Mutter internals. Upstream Blur My Shell explicitly warns that it must be rebuilt whenever GNOME Shell or Mutter is updated.

Run:

```bash
./fix.sh --rebuild
```

or, with `yay` directly:

```bash
yay -S --rebuild gnome-rounded-blur
```

Then log out and back in.

## Blur My Shell settings

This library does not enable application blur by itself. It only supplies the rounded-corner-capable blur implementation.

In Blur My Shell, configure the component/window blur normally and use dynamic blur where rounded dynamic blur is desired.

If Blur My Shell still reports that rounded blur support was not found after installation:

1. log out of GNOME and log back in;
2. run `./fix.sh --check`;
3. rebuild `gnome-rounded-blur` if GNOME Shell or Mutter was recently updated.

## Performance and artifact warning

Dynamic blur is more expensive than static blur. Blur My Shell's own documentation also notes that GNOME's dynamic Gaussian blur can produce visual artifacts in some situations.

Do not enable aggressive artifact-handling modes blindly on low-end hardware: some modes trade artifacts for higher compositor cost.

## Rollback

```bash
chmod +x rollback.sh
./rollback.sh
```

The rollback script removes `gnome-rounded-blur` only when this repository recorded that the package was not installed before the patch.

If the package already existed before running `fix.sh`, rollback leaves it untouched.

After removal, log out and back in so GNOME Shell reloads without the compatibility library.

## Why this is separate from Rounded Window Corners extensions

This fix is specifically for the **blur mask**. It does not replace GNOME themes or general rounded-window-corner extensions.

Its purpose is to make Blur My Shell's dynamic blur itself respect a corner radius instead of visibly extending into square corners.

## Upstream references

- Blur My Shell: https://github.com/aunetx/blur-my-shell
- Blur My Shell rounded blur guide: https://github.com/aunetx/blur-my-shell/blob/master/scripts/GUIDE.md
- GNOME Rounded Blur library: https://github.com/kancko/gnome-rounded-blur
