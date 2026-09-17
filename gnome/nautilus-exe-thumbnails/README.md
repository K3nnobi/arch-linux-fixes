# Nautilus Windows EXE Thumbnails

Shows the real embedded icon from Windows `.exe` files in Nautilus instead of a generic executable/Wine icon.

## Status

**Confirmed working** on the original Arch Linux + GNOME/Nautilus setup where this fix was created.

The exact Nautilus version was not preserved in the current notes, so this patch deliberately avoids claiming compatibility with every future Nautilus release.

## Problem

Windows executables can appear in Nautilus with a generic icon even when the `.exe` contains its own embedded application icon.

The tested solution used `icoextract`'s `exe-thumbnailer`, registered it as a user thumbnailer, and removed the GTK thumbnail background that made transparent icons look like they had an unwanted checkerboard/background.

## Dependencies

Official repository packages:

```bash
sudo pacman -S --needed python-pillow icoutils
```

AUR package:

```bash
yay -S icoextract
```

`icoextract` provides the `exe-thumbnailer` command used by this patch.

This repository intentionally does **not** install or bootstrap an AUR helper automatically.

Verify before applying:

```bash
command -v exe-thumbnailer
```

## Automatic install

```bash
chmod +x fix.sh
./fix.sh
```

The script:

- verifies Arch Linux;
- installs the official dependencies if needed;
- requires an existing `exe-thumbnailer` command;
- backs up a pre-existing user thumbnailer registration;
- creates `~/.local/share/thumbnailers/exe-thumbnailer.thumbnailer`;
- appends a managed GTK CSS block without overwriting other custom CSS;
- clears the user's thumbnail cache so failed/generic thumbnails can be regenerated;
- does **not** force-close Nautilus.

After applying, close and reopen Nautilus if it is already running.

## Thumbnailer registration

The tested registration is equivalent to:

```ini
[Thumbnailer Entry]
TryExec=exe-thumbnailer
Exec=exe-thumbnailer -s %s %i %o
MimeType=application/x-ms-dos-executable;application/x-msdownload;application/vnd.microsoft.portable-executable;application/x-dosexec;application/x-wine-extension-exe;
```

## Transparent thumbnail CSS

The tested setup also used:

```css
.nautilus-window.view .thumbnail {
    background: none;
    box-shadow: none;
}
```

The installer adds this inside clearly marked managed comments so rollback can remove only this repository's block.

## Manual test

With a Windows executable that contains an embedded icon:

```bash
exe-thumbnailer -s 256 /path/to/program.exe /tmp/exe-test.png
```

If `/tmp/exe-test.png` contains the application's embedded icon, the extractor is functioning.

Then reopen Nautilus and browse to the `.exe` file. Thumbnail generation can take a moment after the cache is cleared.

## Rollback

```bash
chmod +x rollback.sh
./rollback.sh
```

Rollback:

- restores the exact thumbnailer registration that existed before this patch, if one existed;
- otherwise removes only the thumbnailer file created by the patch;
- removes only the managed GTK CSS block;
- clears the thumbnail cache again so Nautilus can regenerate thumbnails under the restored configuration.

It does not uninstall `icoextract`, `python-pillow` or `icoutils` because other applications may depend on them.

## Safety

This patch changes only user-level Nautilus/GTK thumbnail configuration plus the regenerable thumbnail cache. It does not edit system MIME databases, Wine prefixes or Windows executable files.
