# Changelog

This file describes the **net set of changes relative to the upstream clone** —
i.e. how this working copy currently differs from the point it was cloned, *not*
a chronological history. If a change is later reverted, its entry is removed or
amended rather than recording the revert as a new entry. Keep entries grouped by
type (Added / Changed / Fixed / Removed).

## Fixed

- Character portraits now resolve by their asset filename, so characters whose
  image differs from their id (e.g. Billy → `billy_herinkton.png`) show the real
  portrait instead of a person placeholder — in the sidebar, the edit-dialog
  picker, and the details view.
- Scrollbar crash when scrolling around a mods-tab switch ("ScrollController
  attached to more than one ScrollPosition"). The mods list shared a single
  scroll controller across the tab-change animation, so the outgoing and
  incoming lists were briefly attached to the same controller — which the
  desktop scrollbar forbids. Each list now owns its own scroll controller.
- Performance: saving a mod edit is now near-instant. Previously every save ran
  a full keybind rescan that re-parsed **every** mod's `.ini` files from disk —
  and re-parsed the same mod several times (it appears in the Favorites, ALL,
  and character groups) — taking 1–2s with the dialog blocked open until it
  finished. Keybinds are now cached per mod (parsed at most once, reused across
  reloads; invalidated when a keybind is edited or on manual refresh), and the
  Save flow persists and closes first, refreshing the list afterwards instead of
  blocking on it. Also removed the verbose per-file console logging.
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

- Mod card redesign: removed the redundant character badge (the character is
  already conveyed by the sidebar/title). Clicking the card still toggles the
  mod, with its on/off state shown as a toggle switch (replacing the old ✓/✕
  badge, where the ✕ misread as "delete"); an info (ⓘ) button opens the
  read-only details dialog, and a source-link
  (↗) button (shown only when a URL is set) opens it in the browser. The footer
  shows the mod name plus a short strip of tag chips (first few + "+N"). Deeper
  metadata (images, description, keybinds) lives in the details view rather than
  cluttering the card.
- Mod card hover: the card now scales from its centre with a small straight-up
  lift, instead of growing from the top-left corner toward the top-right. The
  mods grid also got vertical padding so the hover effect on the top row is no
  longer clipped at the top edge.
- Keybinds: the right-click "Keybinds" action is now "Edit keybinds" (and is
  localized), reflecting that the popup is for editing. Key combinations there
  are shown in their exact `.ini` form (including the `VK_` prefix) for editing
  accuracy; the friendly `VK_`-stripped form is reserved for the upcoming
  read-only mod detail dialog.

## Added

- Mods can now be assigned to **non-character categories** — UI, Texture, Audio
  and Misc — alongside the character roster. Assign one in the edit dialog (the
  picker now groups **Characters** and **Categories**); a category with mods gets
  its own sidebar entry, its own section in the grouped ALL view, and an icon in
  the details dialog. The picker no longer defaults an unassigned mod to the
  first character — it shows "No category" instead. Categories are stored in the
  same place as character assignments, so nothing migrates; an older build that
  doesn't know a category id just shows it by its raw id until upgraded.
- The **ALL** tab now groups its mods into per-character sections, each under a
  `▾ ── Character (count) ───` separator header that doubles as the section
  label. Groups follow the roster order, mods with no recognised character fall
  into a trailing "Other" group, the active sort orders cards within each group,
  and filtering hides groups that end up empty. Each header is clickable to
  **collapse/expand** its section (chevron indicates state). Other tabs stay a
  single flat grid.
- A toolbar above the mods grid to **sort and filter** the current view, all on
  one row: a search box (matches mod name), a sort menu (Default / Name A–Z /
  Name Z–A), a **tags** dropdown (checkbox list of the tags present in the view,
  with an Any/All match-mode toggle and a count badge), and a **favorites-only**
  toggle. Filters combine; a "Clear filters" button appears under the search
  (and on the "no matches" screen) to reset them all at once; and the "Add" card
  is hidden while filtering. Tag selections persist across views but only apply
  to tags present in the current view (and the badge counts only those), so a
  tag selected elsewhere never silently empties the list.
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
