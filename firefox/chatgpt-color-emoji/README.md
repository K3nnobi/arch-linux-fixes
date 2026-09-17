# ChatGPT Color Emoji Fix for Firefox on Arch Linux

Fixes a Firefox/Linux font-fallback issue where some emojis inside ChatGPT messages render as monochrome outline glyphs while others render correctly in color.

## Problem

On Arch Linux with Firefox, ChatGPT may display mixed emoji styles in the same sentence.

Example:

```text
😄 😎  -> monochrome / outline
🔥 👍  -> color
```

This can happen even when `Noto Color Emoji` is already installed.

## Cause

Firefox on Linux builds a font fallback chain from the page CSS, web fonts and system fonts. Some normal fonts can contain monochrome glyphs for emoji code points, so Firefox may stop at one of those fonts before reaching `Noto Color Emoji`.

The working solution is to keep the normal ChatGPT text font first, then place `Noto Color Emoji` before the remaining fallback fonts.

Correct order:

```css
"OpenAI Sans", "Noto Color Emoji", "Adwaita Sans", sans-serif
```

Do **not** put `Noto Color Emoji` first. In testing, that caused abnormally large spaces between normal words because the emoji font could also provide the space character.

## Automatic fix

Run:

```bash
chmod +x fix.sh rollback.sh
./fix.sh
```

The script:

- installs `noto-fonts-emoji` if needed
- refreshes the font cache
- detects the default Firefox profile from `profiles.ini`
- enables Firefox custom user styles through `user.js`
- creates or updates a managed block inside `chrome/userContent.css`
- backs up existing Firefox customization files before changing them
- never kills Firefox automatically

Restart Firefox completely after running the patch.

## Manual fix

Install the emoji font:

```bash
sudo pacman -S --needed noto-fonts-emoji
fc-cache -f
```

Enable Firefox custom styles in `about:config`:

```text
toolkit.legacyUserProfileCustomizations.stylesheets = true
```

Inside your Firefox profile, create:

```text
chrome/userContent.css
```

Add:

```css
@-moz-document domain("chatgpt.com"), domain("chat.openai.com") {
    div[data-message-author-role="assistant"],
    div[data-message-author-role="assistant"] *,
    div[data-message-author-role="user"],
    div[data-message-author-role="user"] * {
        font-family: "OpenAI Sans", "Noto Color Emoji", "Adwaita Sans", sans-serif !important;
    }
}
```

Then restart Firefox completely.

## Verification

Open ChatGPT and test a sentence containing mixed emojis:

```text
Test 😄 😎 😂 🤔 🥰 ❤️ 🔥 👍 👌 ✅ 🚀
```

Expected result:

- normal word spacing
- emojis rendered in color
- normal ChatGPT typography preserved

Optional diagnostics:

```bash
fc-match "Noto Color Emoji"
fc-match "sans-serif:charset=1f604"
```

`U+1F604` is the 😄 emoji.

## Rollback

Run:

```bash
./rollback.sh
```

The rollback removes only the block managed by this patch from `userContent.css`. It does not delete unrelated Firefox customizations.

## Tested environment

Confirmed working on:

- Arch Linux
- Firefox
- GNOME / Wayland
- ChatGPT Web
- Noto Color Emoji

## Risk level

**Low** — this patch only installs an official Arch font package and modifies user-level Firefox configuration.

Still, existing files are backed up before modification.

## Notes

The Firefox preference `font.name-list.emoji` can improve general emoji fallback, but it was not sufficient by itself during testing. The `userContent.css` rule above is the confirmed fix for this specific ChatGPT rendering issue.
