import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mod_manager_flutter/models/character_info.dart';
import 'package:mod_manager_flutter/models/origin_enums.dart';
import 'package:mod_manager_flutter/utils/state_providers.dart';

import 'support/origin_shorthand.dart';
import 'support/temp_library.dart';

/// **The library belongs to no screen.**
///
/// Every test here reads it from a bare container — no widget, no Mods tab, no
/// `State` alive anywhere. That is the property being pinned: the tabs are keyed
/// children of a switcher with no keep-alive, so a library owned by the Mods
/// tab's `State` is unreachable and unrefreshable for as long as the user is
/// looking at anything else, which is when installs happen.
void main() {
  late TempLibrary temp;

  setUp(() async {
    temp = await TempLibrary.create(prefix: 'zzz_library_provider_');
  });

  /// A mod folder with one `.ini`, which is enough for the scan to see it.
  void installMod(String name) {
    temp.createMod(name);
    temp.write(name, '$name.ini', '[TextureOverrideBody]\nps-t0 = R\n');
  }

  ProviderContainer container() {
    final container = ProviderContainer(overrides: temp.overrides);
    addTearDown(container.dispose);
    return container;
  }

  test('the first read scans the library, with nothing mounted', () async {
    installMod('Ellen School');
    installMod('Miyabi Kimono');

    final mods = await container().read(libraryProvider.future);

    expect(mods.map((m) => m.id), containsAll(['Ellen School', 'Miyabi Kimono']));
  });

  test('a rescan picks up a mod installed since', () async {
    installMod('Ellen School');
    final ref = container();
    await ref.read(libraryProvider.future);

    installMod('Miyabi Kimono');
    await ref.read(libraryProvider.notifier).rescan();

    expect(ref.read(modsProvider).map((m) => m.id), contains('Miyabi Kimono'));
  });

  test('a rescan that finds nothing new keeps the list it has', () async {
    // What stops the grid being torn down and rebuilt after every toggle,
    // rename and import — each of which triggers a scan that usually finds one
    // mod changed, or none.
    installMod('Ellen School');
    final ref = container();
    final before = await ref.read(libraryProvider.future);

    await ref.read(libraryProvider.notifier).rescan();

    expect(ref.read(modsProvider), same(before),
        reason: 'an unchanged rescan must not publish a new list');
  });

  test('a change to one mod does publish a new list', () async {
    installMod('Ellen School');
    final ref = container();
    final before = await ref.read(libraryProvider.future);

    installMod('Miyabi Kimono');
    await ref.read(libraryProvider.notifier).rescan();

    expect(ref.read(modsProvider), isNot(same(before)));
  });

  test('the installed index answers from the same scan', () async {
    // Derived rather than scanning again: the marketplace's "in library" badges
    // and the Mods tab's grid are two views of one read, so they cannot
    // disagree about what is installed.
    installMod('Ellen School');
    await temp.writeOrigin(
      'Ellen School',
      originFixture(
        modId: 4242,
        modIdConfidence: OriginConfidence.exact,
        provenance: OriginProvenance.downloaded,
      ),
    );
    final ref = container();

    final index = await ref.read(installedModsIndexProvider.future);

    expect(index.installsOfMod(4242), ['Ellen School']);
  });

  test('a mod deleted outside the app is gone after a rescan', () async {
    installMod('Ellen School');
    final ref = container();
    await ref.read(libraryProvider.future);

    temp.deleteMod('Ellen School');
    await ref.read(libraryProvider.notifier).rescan();

    expect(ref.read(modsProvider), isEmpty);
  });

  test('put replaces the library without touching the disk', () async {
    // The seam the targeted editorial actions use: a rename knows exactly what
    // it did, so it says so rather than paying for a walk of every folder.
    installMod('Ellen School');
    final ref = container();
    await ref.read(libraryProvider.future);

    ref.read(libraryProvider.notifier).put([
      ModInfo(
        id: 'Renamed',
        name: 'Renamed',
        characterId: 'ellen',
        isActive: false,
      ),
    ]);

    expect(ref.read(modsProvider).single.id, 'Renamed');
    expect(temp.modFolder('Ellen School').existsSync(), isTrue,
        reason: 'put is an in-memory publish, not a write');
  });
}
