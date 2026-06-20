# TODO

Planned fixes and improvements for ZZZ Mod Manager.
Suggested order: **3 → 1 → 2** (quick bug fixes), then **4** (foundation), then **5–8**.

## 🐛 Bugs

- [x] **1. Localize the "Add mods" import dialog** ✅ *(committed c1e4707)*
  `_showImportDialog()` (`mod_manager_flutter/lib/screens/mods_screen.dart` ~2315) hardcodes
  Ukrainian strings: title `'Додати моди'`, the drag/paste instructions, the auto-tag tip,
  and the `'Зрозуміло'` button. None go through `loc.t()`, so the EN/UK switch doesn't affect
  them. (It's Ukrainian, not Russian.)
  *Fix:* add keys to `assets/l10n/en.json` + `uk.json`, replace the literals.

- [x] **2. Localize the keybinds modal (Close button + title)** ✅ *(committed c1e4707)*
  `_showKeybindsDialog()` (`mods_screen.dart` ~1026) hardcodes the bottom-right `'Закрити'`
  (Close) button and the `'Keybinds: {name}'` title. Also audit `_showEditKeybindDialog`
  (~832) for hardcoded strings. Route all through `loc.t()` with new en/uk keys.

- [x] **3. Fix keybind parsing dropping case-variant keys (`Key` vs `key`)** ✅
  Root cause: `KeybindInfo.keyValue` (`lib/models/keybind_info.dart`) returns `keys['key']` —
  case-sensitive lowercase. INI sections that write `Key = ...` (e.g. `[KeySwap0]`,
  `[KeySwap1]`) store the value under `'Key'`, so `keyValue` is `null` and the keybind is
  filtered out by the `validKeybinds` filter in `keybinds_widget.dart` and `mods_screen.dart`.
  That's why 4 sections are detected but only 2 show.
  *Fix:* normalize key names case-insensitively — either lowercase keys when storing in
  `IniParserService.parseIniFile`, or make `keyValue` look up case-insensitively. Verify all
  4 example keybinds (SwapBody/Swap/Swap0/Swap1) render. Also reconcile the count:
  `KeybindsBadge` sums `kb.keys.length` (all k=v pairs incl. `condition`/`type`/`$var`), which
  is misleading — count valid keybinds instead.

- [x] **9. Show `VK_`-stripped keybinds (read-only) in the detail dialog** ✅ *(done with #7)*
  `VK_` is the Windows Virtual-Key prefix; end users only recognise `F2` / `DOWN`, not
  `VK_F2` / `VK_DOWN`. Show the friendly, `VK_`-stripped form in the **read-only** mod detail
  dialog (#7).
  *Decision:* the keybinds **edit** popup intentionally keeps the exact `.ini` form (with
  `VK_`) — editing wants accuracy, not prettiness. So stripping is display-only in the detail
  dialog, no write-back/round-trip needed. Add a small formatter (split on whitespace, drop a
  leading `VK_` per token, leave modifiers `ctrl`/`shift`/`alt`/`no_*` as-is) when building #7.
  *Done already:* the right-click action was renamed "Keybinds" → "Edit keybinds" (localized).

## ✨ Features

- [x] **4. Build a persistent per-mod metadata store** ✅ *(in-folder `.zzz-mod-manager/`, with legacy migration)*
  Today `ApiService.updateMod()` (`lib/services/api_service.dart:139`) is a no-op stub
  returning `true` — edits to description never persist, and mods are re-derived from folder
  scans each launch. Add a real metadata store keyed by mod id/folder name (JSON in app-data
  dir, alongside `config.json`, following `ConfigService`'s dual-write pattern). Persist:
  description, tags, source URL, extra image paths. Merge stored metadata into `ModInfo`
  during scan in `ModManagerService`. **Blocks 5–8.**

- [x] **5. Add a source URL field to mods (link to GameBanana / any page)** ✅
  Add `sourceUrl` (or `links`) to `ModInfo` + `toJson`/`fromJson`, persist via the metadata
  store. Add an editable field in the edit dialog and make it clickable (`url_launcher`) from
  the mod card / detail dialog. *Depends on #4.*

- [x] **6. Add extended mod metadata (tags + persisted description)** ✅
  Add a `tags` list to `ModInfo` (model + JSON) and make description editing actually persist
  via the metadata store (currently `updateMod` is a stub). Provide tag add/remove UI in the
  edit/detail dialog. Consider tag-based filtering in the mods list later. *Depends on #4.*

- [x] **7. Add a mod detail dialog** ✅ *(read-only; right-click → Details)*
  New **read-only** dialog opened from a mod card showing all mod info: name, character,
  description, tags, source URL (clickable), keybinds, and the image gallery. The central
  place to review everything (the keybinds *edit* popup stays separate). Show keybinds
  `VK_`-stripped here (see #9). Reuse existing keybind chip rendering. Shell can be built
  first; full content depends on #5/#6/#8.

- [ ] **8. Support multiple images per mod with a gallery**
  Extend `ModInfo` from single `imagePath` to a list of images (keep `imagePath` as the
  first/cover for back-compat). Store extra images in app-data `mod_images/` and persist paths
  in the metadata store. Mods list shows the cover (first image); the detail dialog shows a
  swipeable/scrollable gallery. Add UI to add/remove/reorder images. *Depends on #4 + #7.*
