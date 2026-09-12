import 'package:flutter/material.dart';

/// Reads `config.json`'s `theme` key, **failing to [ThemeMode.system]**.
///
/// `ThemeMode` rather than an enum of our own: it is exactly the three states
/// the setting offers, and it is the vocabulary `MaterialApp` already speaks.
/// The stored value is the Dart name (`light` | `system` | `dark`), the same
/// convention as `marketplace_sort`.
///
/// Degrading to [ThemeMode.system] is what makes the key safe to have held
/// something else. Builds before this setting existed wrote a palette name
/// (`dark-blue`) under it and read it back nowhere, so the first launch after
/// an upgrade meets a value that was never a mode — and following the desktop
/// is the answer that is wrong in neither direction, since the app arrives the
/// colour everything else on the screen already is.
ThemeMode parseThemeMode(Object? value) {
  if (value is! String) return ThemeMode.system;
  for (final mode in ThemeMode.values) {
    if (mode.name == value) return mode;
  }
  return ThemeMode.system;
}
