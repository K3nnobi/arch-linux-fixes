# GNOME Drag Hover Raise

Adds Windows-like window raising during file drag-and-drop on GNOME/Wayland.

## Status

**Tested and working** on:

- Arch Linux
- GNOME Shell 50.4
- Wayland
- Dash to Dock 105
- Dash to Dock UUID: `dash-to-dock@micxgx.gmail.com`

Confirmed behavior in the tested environment:

- dragging a file over a running app icon in Dash to Dock for about 400 ms raises that app window;
- dragging a file over the visible part of a partially covered window for about 400 ms raises that window;
- the original drag remains active;
- no `xdotool`, `wmctrl` or X11-only automation is used.

## Problem

GNOME does not normally reproduce the Windows behavior where holding a dragged file over a background window automatically brings that window to the front.

This is especially noticeable when dragging from Nautilus into another application.

## What the patch changes

The patch modifies the user-installed Dash to Dock file:

```text
~/.local/share/gnome-shell/extensions/dash-to-dock@micxgx.gmail.com/dash.js
```

It adds two managed behaviors:

1. **Dock icon hover** — detects an external file drag over a running application icon and calls `Main.activateWindow()` after approximately 400 ms.
2. **Visible window hover** — when the pointer is not over the dock, it checks Mutter's window stacking order and frame rectangles to identify the visible window under the pointer, then raises it after approximately 400 ms.

The polling interval is approximately 100 ms.

## Automatic install

```bash
chmod +x fix.sh
./fix.sh
```

The installer is deliberately strict. It:

- supports the tested **Dash to Dock 105** layout only;
- checks the expected source-code anchors instead of relying on fixed line numbers;
- creates an exact backup before modifying `dash.js`;
- stores backup/state outside the extension directory;
- refuses to patch an unsupported or unexpected file layout;
- never logs out the user automatically.

After installation, **log out and back in** to reload GNOME Shell on Wayland.

> Save your work before logging out. A logout closes applications and can discard unsaved work.

## Why the backup is outside the extension folder

Do not create a complete copied extension directory beside the original using a name such as:

```text
dash-to-dock@micxgx.gmail.com.backup
```

GNOME Shell can try to load it as an extension and complain that the directory name does not match the UUID in `metadata.json`.

This patch instead stores its original `dash.js` at:

```text
~/.local/state/arch-linux-fixes/gnome-drag-hover-raise/
```

## File drag detection

The tested patch recognizes file-transfer MIME types including:

```text
text/uri-list
x-special/gnome-icon-list
application/octet-stream
application/vnd.portal.filetransfer
image/*
```

It also checks that the left mouse button remains pressed.

## Limitations

A completely hidden window has no visible area under the pointer, so the geometric window-hover mechanism cannot select it. In that situation, hover the dragged file over the application's Dash to Dock icon instead.

## Updates to Dash to Dock

This is a **version-sensitive compatibility patch**. A Dash to Dock update may replace `dash.js` or change its internal structure.

Do **not** restore an old `dash.js` backup over a newer extension version. The rollback script compares the saved extension version and refuses to restore across a version mismatch.

Future versions should be revalidated before support is added.

## Rollback

```bash
chmod +x rollback.sh
./rollback.sh
```

The rollback restores the exact pre-patch `dash.js` only when the currently installed Dash to Dock version still matches the saved version.

After rollback, log out and back in again.

## Technical core

The window-raising calls are:

```javascript
Main.activateWindow(windows[0]);
```

for the application found through the dock icon, and:

```javascript
Main.activateWindow(targetWindow);
```

for a partially covered window detected under the pointer.

The second mechanism uses:

```javascript
global.display.list_all_windows();
global.display.sort_windows_by_stacking(windows);
win.get_frame_rect();
```

so it works through GNOME Shell/Mutter rather than X11 window-control utilities.
