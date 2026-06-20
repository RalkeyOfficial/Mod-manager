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

- `CLAUDE.md` — guidance for working in this repo (architecture, dev workflow).
- `TODO.md` — roadmap of planned bug fixes and features.
- `CHANGELOG.md` — this file.
