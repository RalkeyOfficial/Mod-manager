import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mod_manager_flutter/models/character_info.dart';
import 'package:mod_manager_flutter/utils/state_providers.dart';

/// A library held in memory, for a test whose subject is not the scan.
///
/// `libraryProvider` reads the library off disk through `ApiService`, which
/// `flutter_test_config.dart` makes throw — so a test about a *filter*, a
/// *count* or a *dialog* hands the list in here instead of installing a
/// [TempLibrary](temp_library.dart) it has no use for. A test about the scan
/// itself wants the real thing over a temp directory.
///
/// **The build is synchronous**, which is what a `container.read` in a plain
/// `test` needs: an `AsyncNotifier` whose `build` returns a value rather than a
/// `Future` lands in `AsyncData` immediately, so `modsProvider` is the list and
/// not the empty placeholder it shows while a real scan runs.
Override libraryOf(List<ModInfo> mods) =>
    libraryProvider.overrideWith(() => _HeldLibrary(mods));

class _HeldLibrary extends LibraryNotifier {
  _HeldLibrary(this._mods);

  final List<ModInfo> _mods;

  @override
  FutureOr<List<ModInfo>> build() => _mods;

  /// A rescan would reach the disk, which is the one thing this override exists
  /// to avoid. The list is whatever the test said it is.
  @override
  Future<void> rescan() async {}
}
