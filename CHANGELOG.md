# Changelog

This file describes the **net set of changes relative to the upstream clone** —
i.e. how this working copy currently differs from the point it was cloned, *not*
a chronological history. If a change is later reverted, its entry is removed or
amended rather than recording the revert as a new entry. Keep entries grouped by
type (Added / Changed / Fixed / Removed).

## Fixed

- Localization: the "Add mods" dialog and the keybinds dialogs (view, edit, and
  their result/error messages) now respect the EN/UK language toggle. They
  previously used hardcoded strings — the Add mods dialog was always Ukrainian
  and the keybind-edit dialog was always English — so switching language had no
  effect on them.
- Keybinds: the keybinds modal now lists every bind. Sections whose `.ini` wrote
  `Key =` (capitalised) instead of `key =` were silently dropped, so a mod with
  4 binds only showed 2. Key lookup is now case-insensitive. The character
  keybind count badge now counts actual binds instead of summing every
  key/value line.

## Changed

- Keybinds: the right-click "Keybinds" action is now "Edit keybinds" (and is
  localized), reflecting that the popup is for editing. Key combinations there
  are shown in their exact `.ini` form (including the `VK_` prefix) for editing
  accuracy; the friendly `VK_`-stripped form is reserved for the upcoming
  read-only mod detail dialog.

## Added

- Mods support **multiple images** with a small manager in the Edit dialog:
  **Paste** from the clipboard or **Add files** (multi-select), remove via the
  thumbnail's ✕, and tap a thumbnail to make it the cover. Like the other
  fields, image changes are staged and only take effect on **Save** (Cancel
  discards them — nothing is written or deleted). Removing an image only deletes
  the manager's own copy, never a file the mod shipped with. Images live in the
  mod's own folder; the first is the cover shown in the list, and the details
  dialog shows the full gallery.
- A read-only **mod details dialog** (right-click → Details) showing the image
  gallery, character, description, tags, clickable source link, and keybinds in
  one place. Keybinds here are shown **without the `VK_` prefix** (`VK_UP` → `UP`)
  for readability; the edit popup keeps the exact `.ini` form. An Edit shortcut
  in the header jumps to the editor.
- The mod Edit dialog now edits **description** and **tags** (add via Enter or
  the + button, remove via the chip's ✕), in addition to character and source
  link. All of it persists to the in-folder metadata. Description previously had
  no way to be saved at all.
- Mods can now have a **source link** (GameBanana or any URL). Set it in the
  mod's Edit dialog; when present, the right-click menu gains "Open source page"
  which opens it in your browser. Stored in the in-folder metadata.
- Per-mod metadata is now stored **inside each mod's own folder**
  (`<mod>/.zzz-mod-manager/metadata.json`, with images under `images/`), so it
  travels with the mod when shared and survives folder renames. Holds
  description, source URL, tags, character assignment, and the image gallery.
  Pasted images are now saved into the mod folder instead of app-data.
  On first scan, existing data is migrated in automatically: the character tag
  from `config.json` and any pasted image from the app-data `mod_images/` dir
  (originals are left in place). Favorite and active-link state stay in
  `config.json` (they are per-install, not part of the mod).
- `CLAUDE.md` — guidance for working in this repo (architecture, dev workflow).
- `TODO.md` — roadmap of planned bug fixes and features.
- `CHANGELOG.md` — this file.
