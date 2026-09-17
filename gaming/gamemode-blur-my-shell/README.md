# GameMode + Blur My Shell

Temporarily disables **Blur My Shell** while GameMode is active and restores it when the final GameMode client exits.

## Status

**Experimental / recovered from a real ArchMind implementation.**

This integration originally shipped in **ArchMind 1.5.11**. Its automated test suite covered configuration, idempotence, preservation of existing GameMode hooks, disabling the extension and restoring it afterward.

However, the original release notes explicitly stated that final confirmation in a real GNOME session with Blur My Shell enabled was still pending. For that reason this repository does **not** label it as fully real-session validated yet.

A dedicated `test.sh` is included so the behavior can be verified safely on the target machine before relying on it for games.

## What it does

When a game activates GameMode:

```text
Game starts
    ↓
GameMode becomes active
    ↓
Blur My Shell is disabled
    ↓
Game runs without the GNOME blur effect
    ↓
Final GameMode client exits
    ↓
Blur My Shell is restored only if it was enabled before
```

The goal is to reduce compositor work and avoid blur-related artifacts while gaming.

## Requirements

- Arch Linux
- GNOME Shell
- Blur My Shell (`blur-my-shell@aunetx`)
- `gamemode`
- `lib32-gamemode` for 32-bit/Steam compatibility
- `gnome-extensions`
- `flock` from `util-linux`

The installer can install `gamemode` and `lib32-gamemode` through Pacman. If `lib32-gamemode` is unavailable, make sure the Arch `multilib` repository is enabled.

## Install

```bash
chmod +x fix.sh gamemode-blur.sh test.sh rollback.sh
./fix.sh
```

The installer:

- runs as the normal user;
- installs GameMode packages when needed;
- copies the runtime hook to `~/.local/bin/arch-linux-fixes-gamemode-blur`;
- adds a managed `[custom]` block to `~/.config/gamemode.ini`;
- preserves unrelated GameMode settings and custom hooks;
- creates a default extension policy containing `blur-my-shell@aunetx`;
- stores pre-patch backups/state under `~/.local/state/arch-linux-fixes/gamemode-blur/`;
- never logs out, kills GNOME Shell or starts a game automatically.

## Steam

For games that do not already request GameMode themselves, add this to Steam launch options:

```text
gamemoderun %command%
```

GameMode also works with games/launchers that integrate it natively.

## Managed GameMode block

The patch appends a block equivalent to:

```ini
; BEGIN ARCH-LINUX-FIXES GAMEMODE BLUR
[custom]
start='/home/USER/.local/bin/arch-linux-fixes-gamemode-blur' start
end='/home/USER/.local/bin/arch-linux-fixes-gamemode-blur' end
; END ARCH-LINUX-FIXES GAMEMODE BLUR
```

The path is generated for the current user. Existing unrelated settings are preserved.

## Why duplicate `start` / `end` hooks are preserved

GameMode supports lists of custom start/end scripts. The original ArchMind implementation intentionally added its own managed entries without deleting other custom hooks.

The patch therefore removes/replaces only its own marked block and an exact legacy prototype path from the older ArchMind experiment.

## State restoration

The hook writes runtime state under:

```text
$XDG_RUNTIME_DIR/arch-linux-fixes-gamemode-blur/
```

Only extensions that were actually enabled before GameMode started are written to that state file.

That means:

- if Blur My Shell was enabled, it is disabled and later restored;
- if Blur My Shell was already disabled, it stays disabled;
- duplicate `start` calls do not erase the saved restoration state;
- if restoration fails, the state is kept so `recover` can be attempted again.

Manual recovery:

```bash
~/.local/bin/arch-linux-fixes-gamemode-blur recover
```

## Verify before gaming

Close any currently running GameMode-enabled game first, make sure Blur My Shell is enabled, then run:

```bash
./test.sh
```

The test launches:

```bash
gamemoderun sleep 4
```

and verifies that Blur My Shell becomes disabled while GameMode is active and becomes enabled again afterward.

Expected result:

```text
[ OK ] Blur My Shell disabled during GameMode and restored afterward.
```

If either transition fails, the test attempts a recovery and reports the failure instead of claiming success.

## Extension policy

The default policy file is:

```text
~/.config/arch-linux-fixes/gamemode-blur/extensions.conf
```

It contains Blur My Shell by default:

```text
blur-my-shell@aunetx
```

Additional GNOME extension UUIDs may be added one per line if you deliberately want them suspended during GameMode.

Invalid UUID-like entries are ignored by the hook.

## Check current state

```bash
~/.local/bin/arch-linux-fixes-gamemode-blur status
```

You can also inspect GameMode itself:

```bash
gamemoded -s
```

## Rollback

```bash
./rollback.sh
```

Rollback:

- attempts to restore any extension state still pending;
- removes only the managed GameMode block;
- restores a pre-existing file at the helper path if one existed before installation;
- otherwise removes only the helper created by this patch;
- removes only the managed default policy block;
- keeps `gamemode` and `lib32-gamemode` installed because other games or tools may depend on them.

It does not overwrite unrelated GameMode changes made after installation.

## Important notes

GameMode activates for any process that requests it, not only games. If you run a non-game program through `gamemoderun`, this hook will also temporarily suspend the configured extensions.

The CPU governor warning sometimes shown by `gamemoded -t` is independent of this integration. This patch does not force a governor, change power limits, overclock the GPU or alter fan control.

## Upstream references

- GameMode: https://github.com/FeralInteractive/gamemode
- Example GameMode configuration: https://github.com/FeralInteractive/gamemode/blob/master/example/gamemode.ini
- Blur My Shell: https://github.com/aunetx/blur-my-shell
