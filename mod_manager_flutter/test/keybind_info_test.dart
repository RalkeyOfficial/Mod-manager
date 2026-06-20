import 'package:flutter_test/flutter_test.dart';
import 'package:mod_manager_flutter/models/keybind_info.dart';

void main() {
  group('KeybindInfo.keyValue (case-insensitive lookup)', () {
    test('resolves lowercase "key"', () {
      final kb = KeybindInfo(section: 'KeySwap', keys: {'key': 'ctrl VK_UP'});
      expect(kb.keyValue, 'ctrl VK_UP');
    });

    test('resolves capitalised "Key" (the bug: was dropped before)', () {
      final kb = KeybindInfo(section: 'KeySwap0', keys: {'Key': 'alt VK_UP'});
      expect(kb.keyValue, 'alt VK_UP');
    });

    test('all four sections from the bug report resolve a key value', () {
      final keybinds = [
        KeybindInfo(section: 'KeySwapBody', keys: {'key': 'ctrl shift no_alt VK_UP'}),
        KeybindInfo(section: 'KeySwap', keys: {'key': 'ctrl no_shift no_alt VK_UP'}),
        KeybindInfo(section: 'KeySwap0', keys: {'Key': 'no_ctrl no_shift alt VK_UP'}),
        KeybindInfo(section: 'KeySwap1', keys: {'Key': 'ctrl no_shift no_alt VK_DOWN'}),
      ];
      final valid = keybinds.where((kb) => kb.keyValue != null && kb.keyValue!.isNotEmpty);
      expect(valid.length, 4);
    });

    test('returns null when no key field is present', () {
      final kb = KeybindInfo(section: 'KeySwap', keys: {'condition': r'$active == 1'});
      expect(kb.keyValue, isNull);
    });
  });
}
