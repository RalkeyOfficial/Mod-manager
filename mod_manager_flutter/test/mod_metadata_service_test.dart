import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:mod_manager_flutter/models/mod_metadata.dart';
import 'package:mod_manager_flutter/services/mod_metadata_service.dart';

void main() {
  late Directory tmp;
  late ModMetadataService service;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('modmeta_test_');
    service = ModMetadataService();
  });

  tearDown(() {
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  group('ModMetadata model', () {
    test('toJson/fromJson round-trips', () {
      const meta = ModMetadata(
        description: 'A cool mod',
        sourceUrl: 'https://gamebanana.com/mods/123',
        tags: ['nsfw', 'recolor'],
        characterId: 'miyabi',
        images: ['.zzz-mod-manager/images/01.png'],
      );
      final restored = ModMetadata.fromJson(meta.toJson());
      expect(restored.description, meta.description);
      expect(restored.sourceUrl, meta.sourceUrl);
      expect(restored.tags, meta.tags);
      expect(restored.characterId, meta.characterId);
      expect(restored.images, meta.images);
      expect(restored.schemaVersion, ModMetadata.currentSchemaVersion);
    });

    test('isEmpty reflects content', () {
      expect(const ModMetadata().isEmpty, isTrue);
      expect(const ModMetadata(tags: ['x']).isEmpty, isFalse);
      expect(const ModMetadata(characterId: 'anby').isEmpty, isFalse);
    });
  });

  group('ModMetadataService read/write', () {
    test('read returns null when no sidecar exists', () async {
      expect(await service.read(tmp.path), isNull);
    });

    test('write then read round-trips and creates the sidecar path', () async {
      const meta = ModMetadata(description: 'hello', characterId: 'ellen', tags: ['a']);
      final ok = await service.write(tmp.path, meta);
      expect(ok, isTrue);

      final file = File(path.join(tmp.path, '.zzz-mod-manager', 'metadata.json'));
      expect(await file.exists(), isTrue);

      final read = await service.read(tmp.path);
      expect(read, isNotNull);
      expect(read!.description, 'hello');
      expect(read.characterId, 'ellen');
      expect(read.tags, ['a']);
    });

    test('read returns null on corrupt json', () async {
      final dir = Directory(path.join(tmp.path, '.zzz-mod-manager'))..createSync(recursive: true);
      File(path.join(dir.path, 'metadata.json')).writeAsStringSync('{ not valid json');
      expect(await service.read(tmp.path), isNull);
    });
  });

  group('ModMetadataService images', () {
    test('addImageBytes writes into images dir and increments index', () async {
      final rel1 = await service.addImageBytes(tmp.path, [1, 2, 3], extension: 'png');
      final rel2 = await service.addImageBytes(tmp.path, [4, 5, 6], extension: 'png');

      expect(rel1, path.join('.zzz-mod-manager', 'images', '01.png'));
      expect(rel2, path.join('.zzz-mod-manager', 'images', '02.png'));
      expect(await File(path.join(tmp.path, rel1!)).exists(), isTrue);
      expect(await File(path.join(tmp.path, rel2!)).exists(), isTrue);
    });

    test('importImageFile copies an external file into the mod folder', () async {
      final src = File(path.join(tmp.path, 'external.jpg'))..writeAsBytesSync([9, 9, 9]);
      final rel = await service.importImageFile(tmp.path, src.path);
      expect(rel, path.join('.zzz-mod-manager', 'images', '01.jpg'));
      expect(await File(path.join(tmp.path, rel!)).readAsBytes(), [9, 9, 9]);
    });
  });
}
