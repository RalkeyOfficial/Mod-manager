import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mod_manager_flutter/utils/state_providers.dart';
import 'package:mod_manager_flutter/utils/theme_setting.dart';

/// The theme choice, from the stored string to the colour on screen.
///
/// Two halves that are easy to get separately right and jointly wrong: what a
/// stored value means, and what the app draws for a choice of *system*, which
/// is an answer the setting does not hold and the desktop does.
void main() {
  group('the stored value', () {
    test('reads back each of the three choices', () {
      expect(parseThemeMode('light'), ThemeMode.light);
      expect(parseThemeMode('system'), ThemeMode.system);
      expect(parseThemeMode('dark'), ThemeMode.dark);
    });

    test('a palette name from an older config is not a mode', () {
      // The key is older than the setting, so the first launch after an
      // upgrade meets this and has to arrive somewhere sensible.
      expect(parseThemeMode('dark-blue'), ThemeMode.system);
    });

    test('an unset or unreadable value follows the desktop', () {
      expect(parseThemeMode(''), ThemeMode.system);
      expect(parseThemeMode(null), ThemeMode.system);
      expect(parseThemeMode(3), ThemeMode.system);
    });

    test('what is written is what is read back', () {
      // The writer stores `mode.name`; this is the pairing that keeps it honest
      // if either side is ever renamed.
      for (final mode in ThemeMode.values) {
        expect(parseThemeMode(mode.name), mode);
      }
    });
  });

  group('what the app draws', () {
    ProviderContainer containerOn(Brightness desktop) {
      final container = ProviderContainer(
        overrides: [
          platformBrightnessProvider.overrideWith((ref) => desktop),
        ],
      );
      addTearDown(container.dispose);
      return container;
    }

    test('starts on the desktop, both ways', () {
      expect(containerOn(Brightness.dark).read(isDarkModeProvider), isTrue);
      expect(containerOn(Brightness.light).read(isDarkModeProvider), isFalse);
    });

    test('a choice overrides the desktop, both ways', () {
      final container = containerOn(Brightness.dark);

      container.read(themeModeProvider.notifier).state = ThemeMode.light;
      expect(container.read(isDarkModeProvider), isFalse);

      container.read(themeModeProvider.notifier).state = ThemeMode.dark;
      expect(container.read(isDarkModeProvider), isTrue);
    });

    test('on system, the desktop changing changes the app', () {
      // The reason *system* is a third state rather than "dark off": a desktop
      // that switches at sunset has to take the app with it.
      final container = containerOn(Brightness.light);
      expect(container.read(isDarkModeProvider), isFalse);

      container.read(platformBrightnessProvider.notifier).state =
          Brightness.dark;
      expect(container.read(isDarkModeProvider), isTrue);
    });

    test('on a choice, the desktop changing changes nothing', () {
      final container = containerOn(Brightness.light);
      container.read(themeModeProvider.notifier).state = ThemeMode.dark;

      container.read(platformBrightnessProvider.notifier).state =
          Brightness.dark;
      expect(container.read(isDarkModeProvider), isTrue);

      container.read(platformBrightnessProvider.notifier).state =
          Brightness.light;
      expect(container.read(isDarkModeProvider), isTrue);
    });
  });
}
