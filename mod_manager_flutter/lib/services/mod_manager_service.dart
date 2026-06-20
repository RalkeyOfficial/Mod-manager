import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/character_info.dart';
import '../models/keybind_info.dart';
import '../models/mod_metadata.dart';
import '../core/constants.dart';
import '../utils/path_helper.dart';
import '../utils/state_providers.dart';
import 'config_service.dart';
import 'mod_metadata_service.dart';
import 'platform_service.dart';
import 'platform_service_factory.dart';
import 'ini_parser_service.dart';

/// Головний сервіс для керування модами через symbolic links
class ModManagerService {
  final ConfigService _configService;
  final PlatformService _platformService;
  final ProviderContainer _container;
  final IniParserService _iniParser;
  final ModMetadataService _metadataService;

  ModManagerService(this._configService, this._container)
      : _platformService = PlatformServiceFactory.getInstance(),
        _iniParser = IniParserService(),
        _metadataService = ModMetadataService();

  String? get modsPath => _configService.modsPath;
  String? get saveModsPath => _configService.saveModsPath;

  Future<(bool, String)> validatePaths() async {
    final mods = modsPath;
    final saveMods = saveModsPath;

    if (mods == null || mods.isEmpty || saveMods == null || saveMods.isEmpty) {
      return (false, 'Шляхи не налаштовані. Будь ласка, налаштуйте їх у Налаштуваннях.');
    }

    final modsDir = Directory(mods);
    if (!await modsDir.exists()) {
      return (false, 'Папка з модами не існує: $mods');
    }

    final saveModsDir = Directory(saveMods);
    if (await saveModsDir.exists()) {
      final stat = await saveModsDir.stat();
      if (stat.type != FileSystemEntityType.directory) {
        return (false, 'Шлях для links існує але не є папкою: $saveMods');
      }
    }

    return (true, '');
  }

  Future<List<String>> scanMods() async {
    try {
      final (valid, _) = await validatePaths();
      if (!valid) return [];

      final modsDir = Directory(modsPath!);
      if (!await modsDir.exists()) return [];

      final mods = <String>[];
      await for (final entity in modsDir.list()) {
        if (entity is Directory) {
          final name = path.basename(entity.path);
          if (!name.startsWith('.') && !name.startsWith('__')) {
            mods.add(name);
          }
        }
      }

      return mods;
    } catch (e) {
      return [];
    }
  }

  Future<List<ModInfo>> getModsInfo() async {
    try {
      final modNames = await scanMods();
      final modsInfo = <ModInfo>[];
      final favoriteSet = _configService.favoriteMods.toSet();

      // Очищуємо символічні посилання на неіснуючі моди
      await _cleanupInvalidLinks();

      for (final modName in modNames) {
        final isActive = await isModActive(modName);
        final modFolder = path.join(modsPath!, modName);

        // Load the in-folder metadata sidecar, migrating legacy storage
        // (config char tag + app-data image) into it on first encounter.
        final metadata = await _loadOrMigrateMetadata(modName, modFolder);

        // Resolve the gallery to absolute paths, dropping any that no longer
        // exist. Fall back to a shipped preview image (Preview.png, etc.).
        final images = <String>[];
        for (final rel in metadata.images) {
          final abs = path.join(modFolder, rel);
          if (await File(abs).exists()) images.add(abs);
        }
        if (images.isEmpty) {
          final preview = await _findModImage(modName);
          if (preview != null) images.add(preview);
        }

        final characterId = (metadata.characterId != null && metadata.characterId!.isNotEmpty)
            ? metadata.characterId!
            : (_configService.modCharacterTags[modName] ?? 'unknown');

        modsInfo.add(
          ModInfo(
            id: modName,
            name: modName,
            characterId: characterId,
            isActive: isActive,
            imagePath: images.isNotEmpty ? images.first : null,
            description: metadata.description,
            sourceUrl: metadata.sourceUrl,
            tags: metadata.tags,
            images: images,
            isFavorite: favoriteSet.contains(modName),
          ),
        );
      }

      return modsInfo;
    } catch (e) {
      return [];
    }
  }

  /// Loads a mod's metadata sidecar. If none exists yet, migrates legacy
  /// storage (character tag from config.json, pasted image from the app-data
  /// `mod_images/` dir) into the mod folder and writes the sidecar once.
  /// Best-effort: if the folder can't be written, returns the resolved values
  /// in memory so the app still works.
  Future<ModMetadata> _loadOrMigrateMetadata(String modName, String modFolder) async {
    final existing = await _metadataService.read(modFolder);
    if (existing != null) return existing;

    // No sidecar yet — gather legacy data to migrate.
    final legacyChar = _configService.modCharacterTags[modName];
    String? migratedImageRel;
    try {
      final legacyImage = File(path.join(PathHelper.getModImagesPath(), '$modName.png'));
      if (await legacyImage.exists()) {
        migratedImageRel = await _metadataService.importImageFile(modFolder, legacyImage.path);
      }
    } catch (e) {
      // Ignore: app-data image is optional.
    }

    final hasLegacyData = (legacyChar != null && legacyChar.isNotEmpty) || migratedImageRel != null;
    final metadata = ModMetadata(
      characterId: legacyChar,
      images: migratedImageRel != null ? [migratedImageRel] : const [],
    );

    // Only persist when there is something to preserve, so we don't litter
    // every mod folder with empty sidecars.
    if (hasLegacyData) {
      await _metadataService.write(modFolder, metadata);
    }
    return metadata;
  }

  /// Persists editable metadata for a mod into its in-folder sidecar. Image
  /// paths on [mod] that live inside the mod folder are stored relative; paths
  /// outside it are ignored (use [ModMetadataService.importImageFile] first).
  Future<bool> saveModMetadata(ModInfo mod) async {
    try {
      if (modsPath == null) return false;
      final modFolder = path.join(modsPath!, mod.id);

      final relImages = <String>[];
      for (final abs in mod.images) {
        final rel = path.relative(abs, from: modFolder);
        if (!rel.startsWith('..') && !path.isAbsolute(rel)) relImages.add(rel);
      }

      // Build the sidecar directly from the mod so emptied fields (e.g. a
      // cleared URL) are actually removed, rather than copyWith keeping the old
      // value. ModInfo carries every metadata field, so this is a full save.
      final existing = await _metadataService.read(modFolder);
      String? orNull(String? v) => (v == null || v.isEmpty) ? null : v;
      final metadata = ModMetadata(
        schemaVersion: existing?.schemaVersion ?? ModMetadata.currentSchemaVersion,
        description: orNull(mod.description),
        sourceUrl: orNull(mod.sourceUrl),
        tags: mod.tags,
        characterId: (mod.characterId.isEmpty || mod.characterId == 'unknown')
            ? null
            : mod.characterId,
        images: relImages,
      );
      return await _metadataService.write(modFolder, metadata);
    } catch (e) {
      print('ModManagerService: failed to save metadata for ${mod.id}: $e');
      return false;
    }
  }

  /// Sets a mod's character assignment in the in-folder sidecar (rename-safe),
  /// and mirrors it into config.json for backward compatibility.
  Future<bool> setModCharacter(String modName, String characterId) async {
    try {
      // Keep the legacy config copy in sync so older code paths still work.
      await _configService.setModCharacterTag(modName, characterId);

      if (modsPath == null) return false;
      final modFolder = path.join(modsPath!, modName);
      final existing = await _metadataService.read(modFolder) ?? const ModMetadata();
      return await _metadataService.write(
        modFolder,
        existing.copyWith(characterId: characterId),
      );
    } catch (e) {
      print('ModManagerService: failed to set character for $modName: $e');
      return false;
    }
  }

  ModMetadataService get metadataService => _metadataService;

  /// Видаляє символічні посилання на моди, які більше не існують
  Future<void> _cleanupInvalidLinks() async {
    try {
      if (saveModsPath == null) return;

      final saveModsDir = Directory(saveModsPath!);
      if (!await saveModsDir.exists()) return;

      final modNames = await scanMods();
      final validModNames = Set<String>.from(modNames);

      await for (final entity in saveModsDir.list()) {
        if (entity is Link) {
          final linkName = path.basename(entity.path);
          
          // Якщо мод більше не існує в папці модів - видаляємо символічне посилання
          if (!validModNames.contains(linkName)) {
            try {
              await entity.delete();
              await _configService.removeActiveMod(linkName);
            } catch (e) {
              // Ігноруємо помилки при видаленні
            }
          }
        }
      }
    } catch (e) {
      // Ігноруємо помилки
    }
  }

  Future<bool> isModActive(String modName) async {
    try {
      if (saveModsPath == null) return false;

      final linkPath = path.join(saveModsPath!, modName);
      final exists = await FileSystemEntity.type(linkPath) != FileSystemEntityType.notFound;
      if (!exists) return false;

      // Використовуємо platformService для перевірки
      return await _platformService.isModLink(linkPath);
    } catch (e) {
      return false;
    }
  }

  Future<bool> activateMod(String modName) async {
    try {
      final (valid, _) = await validatePaths();
      if (!valid) return false;

      final srcPath = path.join(modsPath!, modName);
      final dstPath = path.join(saveModsPath!, modName);

      final srcDir = Directory(srcPath);
      if (!await srcDir.exists()) return false;

      final saveModsDir = Directory(saveModsPath!);
      if (!await saveModsDir.exists()) {
        await saveModsDir.create(recursive: true);
      }

      // Використовуємо platformService для створення link
      final success = await _platformService.createModLink(srcPath, dstPath);
      if (!success) {
        print('ModManagerService: Не вдалося створити link для $modName');
        return false;
      }

      await _configService.addActiveMod(modName);

      // Автоматично перезавантажуємо моди після активації (якщо увімкнено)
      final autoF10Enabled = _container.read(autoF10ReloadProvider);
      if (autoF10Enabled) {
        await _platformService.sendF10ToGame();
      }

      return true;
    } catch (e) {
      print('ModManagerService: Помилка активації мода: $e');
      return false;
    }
  }

  Future<bool> deactivateMod(String modName) async {
    try {
      if (saveModsPath == null) return false;

      final linkPath = path.join(saveModsPath!, modName);
      final exists = await FileSystemEntity.type(linkPath) != FileSystemEntityType.notFound;
      if (!exists) return false;

      // Використовуємо platformService для видалення link
      final success = await _platformService.removeModLink(linkPath);
      if (!success) {
        print('ModManagerService: Не вдалося видалити link для $modName');
        return false;
      }

      await _configService.removeActiveMod(modName);

      // Автоматично перезавантажуємо моди після деактивації (якщо увімкнено)
      final autoF10Enabled = _container.read(autoF10ReloadProvider);
      if (autoF10Enabled) {
        await _platformService.sendF10ToGame();
      }

      return true;
    } catch (e) {
      print('ModManagerService: Помилка деактивації мода: $e');
      return false;
    }
  }

  Future<bool> toggleMod(String modName) async {
    final isActive = await isModActive(modName);
    return isActive ? await deactivateMod(modName) : await activateMod(modName);
  }

  Future<String?> _findModImage(String modName) async {
    try {
      final modPath = path.join(modsPath!, modName);
      final modDir = Directory(modPath);
      if (!await modDir.exists()) return null;

      for (final imageName in AppConstants.imageFileNames) {
        final imagePath = path.join(modPath, imageName);
        final imageFile = File(imagePath);
        if (await imageFile.exists()) return imagePath;
      }

      return null;
    } catch (e) {
      return null;
    }
  }

  /// Ручне перезавантаження модів (натискання F10)
  Future<bool> reloadMods() async {
    return await _platformService.sendF10ToGame();
  }

  /// Показує інструкції налаштування F10 сервісу
  void showF10SetupInstructions() {
    _platformService.showSetupInstructions();
  }

  /// Встановлює залежності для F10 сервісу
  Future<void> installF10Dependencies() async {
    await _platformService.checkDependencies();
  }

  Future<void> _safeRemove(String filePath) async {
    try {
      // Використовуємо platformService для видалення links
      final isLink = await _platformService.isModLink(filePath);
      
      if (isLink) {
        await _platformService.removeModLink(filePath);
        return;
      }
      
      // Якщо це не link, видаляємо звичайним способом
      final entity = await FileSystemEntity.type(filePath);
      if (entity == FileSystemEntityType.directory) {
        await Directory(filePath).delete(recursive: true);
      } else if (entity == FileSystemEntityType.file) {
        await File(filePath).delete();
      }
    } catch (e) {
      print('ModManagerService: Помилка _safeRemove: $e');
    }
  }

  /// Імпортує нові моди з вказаних папок
  /// Повертає список імпортованих модів та їх автоматично визначених тегів персонажів
  Future<(List<String>, Map<String, String>)> importMods(List<String> folderPaths) async {
    try {
      final (valid, _) = await validatePaths();
      if (!valid) return (<String>[], <String, String>{});

      final importedMods = <String>[];
      final autoTags = <String, String>{};
      final modsDir = Directory(modsPath!);

      if (!await modsDir.exists()) {
        await modsDir.create(recursive: true);
      }

      for (final folderPath in folderPaths) {
        final sourceDir = Directory(folderPath);
        if (!await sourceDir.exists()) continue;

        final modName = path.basename(folderPath);
        final targetPath = path.join(modsPath!, modName);
        final targetDir = Directory(targetPath);

        // Якщо мод вже існує, пропускаємо
        if (await targetDir.exists()) {
          continue;
        }

        // Копіюємо папку з модом
        await _copyDirectory(sourceDir, targetDir);
        importedMods.add(modName);

        // Автоматично визначаємо тег персонажа з назви папки
        final detectedChar = await _detectCharacterFromName(modName);
        if (detectedChar != null) {
          autoTags[modName] = detectedChar;
        }
      }

      return (importedMods, autoTags);
    } catch (e) {
      return (<String>[], <String, String>{});
    }
  }

  /// Визначає персонажа з назви моду
  Future<String?> _detectCharacterFromName(String modName) async {
    final nameLower = modName.toLowerCase();
    
    // Спробуємо знайти персонажа в INI файлах моду
    try {
      final modsPath = _configService.modsPath;
      if (modsPath == null || modsPath.isEmpty) {
        // Якщо шлях не налаштовано, просто шукаємо в назві
      } else {
        final modPath = path.join(modsPath, modName);
        final modDir = Directory(modPath);
      
      if (await modDir.exists()) {
        // Шукаємо INI файли
        final iniFiles = await modDir
            .list(recursive: true)
            .where((entity) => 
                entity is File && 
                path.extension(entity.path).toLowerCase() == '.ini')
            .cast<File>()
            .toList();
        
        for (final iniFile in iniFiles) {
          try {
            final content = await iniFile.readAsString();
            final contentLower = content.toLowerCase();
            
            // Шукаємо в Header або секціях INI
            final charFromIni = _findCharacterInText(contentLower);
            if (charFromIni != null) {
              print('ModManager: Виявлено персонажа "$charFromIni" в INI файлі ${path.basename(iniFile.path)} моду "$modName"');
              return charFromIni;
            }
          } catch (e) {
            // Ігноруємо помилки читання окремих файлів
          }
        }
        
        // Також перевіряємо імена папок всередині моду
        final subdirs = await modDir
            .list(recursive: false)
            .where((entity) => entity is Directory)
            .cast<Directory>()
            .toList();
        
        for (final subdir in subdirs) {
          final subdirName = path.basename(subdir.path).toLowerCase();
          final charFromSubdir = _findCharacterInText(subdirName);
          if (charFromSubdir != null) {
            print('ModManager: Виявлено персонажа "$charFromSubdir" в папці "$subdirName" моду "$modName"');
            return charFromSubdir;
          }
        }
      }
      }
    } catch (e) {
      print('ModManager: Помилка пошуку в файлах моду "$modName": $e');
    }
    
    // Мапа персонажів з альтернативними іменами для кращого розпізнавання
    final characterAliases = <String, List<String>>{
      'alice': ['alice'],
      'anby': ['anby'],
      'anton': ['anton'],
      'astra': ['astra', 'astrayao', 'astra yao'],
      'belle': ['belle'],
      'ben': ['ben', 'bigger', 'ben bigger'],
      'billy': ['billy', 'billyherinkton', 'billy kid'],
      'burnice': ['burnice', 'burnice white'],
      'caesar': ['caesar', 'caesar king'],
      'corin': ['corin', 'corin wickes'],
      'ellen': ['ellen', 'ellen joe'],
      'evelyn': ['evelyn'],
      'grace': ['grace', 'grace howard'],
      'harumasa': ['harumasa', 'asaba harumasa'],
      'hugo': ['hugo'],
      'jane': ['jane', 'janedoe', 'jane doe'],
      'jufufu': ['jufufu', 'ju fufu'],
      'koleda': ['koleda', 'koleda belobog'],
      'lighter': ['lighter', 'lighter lorenz'],
      'lucy': ['lucy', 'lucy kushinada'],
      'lycaon': ['lycaon', 'von lycaon', 'vonlycaon'],
      'miyabi': ['miyabi', 'hoshimi miyabi'],
      'nekomata': ['nekomata', 'nekomiya mana'],
      'nicole': ['nicole', 'nicole demara'],
      'orphie': ['orphie', 'orphiemagus', 'orphie magus'],
      'panyinhu': ['panyinhu', 'pan yinhu'],
      'piper': ['piper', 'piper wheel'],
      'pulchra': ['pulchra'],
      'quinqiy': ['quinqiy', 'qingyi'],
      'rina': ['rina', 'alexandrina'],
      'seed': ['seed'],
      'seth': ['seth', 'seth lowell'],
      'solder0anby': ['solder0anby', 'soldier 0', 'soldier0'],
      'solder11': ['solder11', 'soldier 11', 'soldier11'],
      'soukaku': ['soukaku'],
      'trigger': ['trigger'],
      'vivian': ['vivian'],
      'wise': ['wise'],
      'yanagi': ['yanagi', 'tsukishiro yanagi'],
      'yixuan': ['yixuan'],
      'yuzuha': ['yuzuha'],
      'zhuyuan': ['zhuyuan', 'zhu yuan'],
    };

    // Спочатку шукаємо повні збіги для точності
    for (final entry in characterAliases.entries) {
      final charId = entry.key;
      final aliases = entry.value;
      
      for (final alias in aliases) {
        // Шукаємо як окреме слово з границями
        final pattern = RegExp(r'\b' + RegExp.escape(alias) + r'\b', caseSensitive: false);
        if (pattern.hasMatch(nameLower)) {
          print('ModManager: Виявлено персонажа "$charId" (збіг: "$alias") в "$modName"');
          return charId;
        }
      }
    }
    
    // Якщо не знайшли повну збіг, шукаємо часткові збіги (як раніше)
    for (final entry in characterAliases.entries) {
      final charId = entry.key;
      final aliases = entry.value;
      
      for (final alias in aliases) {
        if (nameLower.contains(alias)) {
          print('ModManager: Виявлено персонажа "$charId" (частковий збіг: "$alias") в "$modName"');
          return charId;
        }
      }
    }

    print('ModManager: Не вдалося визначити персонажа для "$modName"');
    return null;
  }
  
  /// Допоміжний метод для пошуку персонажа в тексті
  String? _findCharacterInText(String text) {
    final textLower = text.toLowerCase();
    
    final characterAliases = <String, List<String>>{
      'alice': ['alice'],
      'anby': ['anby'],
      'anton': ['anton'],
      'astra': ['astra', 'astrayao', 'astra yao'],
      'belle': ['belle'],
      'ben': ['ben', 'bigger', 'ben bigger'],
      'billy': ['billy', 'billyherinkton', 'billy kid'],
      'burnice': ['burnice', 'burnice white'],
      'caesar': ['caesar', 'caesar king'],
      'corin': ['corin', 'corin wickes'],
      'ellen': ['ellen', 'ellen joe'],
      'evelyn': ['evelyn'],
      'grace': ['grace', 'grace howard'],
      'harumasa': ['harumasa', 'asaba harumasa'],
      'hugo': ['hugo'],
      'jane': ['jane', 'janedoe', 'jane doe'],
      'jufufu': ['jufufu', 'ju fufu'],
      'koleda': ['koleda', 'koleda belobog'],
      'lighter': ['lighter', 'lighter lorenz'],
      'lucy': ['lucy', 'lucy kushinada'],
      'lycaon': ['lycaon', 'von lycaon', 'vonlycaon'],
      'miyabi': ['miyabi', 'hoshimi miyabi'],
      'nekomata': ['nekomata', 'nekomiya mana'],
      'nicole': ['nicole', 'nicole demara'],
      'orphie': ['orphie', 'orphiemagus', 'orphie magus'],
      'panyinhu': ['panyinhu', 'pan yinhu'],
      'piper': ['piper', 'piper wheel'],
      'pulchra': ['pulchra'],
      'quinqiy': ['quinqiy', 'qingyi'],
      'rina': ['rina', 'alexandrina'],
      'seed': ['seed'],
      'seth': ['seth', 'seth lowell'],
      'solder0anby': ['solder0anby', 'soldier 0', 'soldier0'],
      'solder11': ['solder11', 'soldier 11', 'soldier11'],
      'soukaku': ['soukaku'],
      'trigger': ['trigger'],
      'vivian': ['vivian'],
      'wise': ['wise'],
      'yanagi': ['yanagi', 'tsukishiro yanagi'],
      'yixuan': ['yixuan'],
      'yuzuha': ['yuzuha'],
      'zhuyuan': ['zhuyuan', 'zhu yuan'],
    };
    
    // Спочатку шукаємо повні збіги
    for (final entry in characterAliases.entries) {
      final charId = entry.key;
      final aliases = entry.value;
      
      for (final alias in aliases) {
        final pattern = RegExp(r'\b' + RegExp.escape(alias) + r'\b', caseSensitive: false);
        if (pattern.hasMatch(textLower)) {
          return charId;
        }
      }
    }
    
    // Часткові збіги
    for (final entry in characterAliases.entries) {
      final charId = entry.key;
      final aliases = entry.value;
      
      for (final alias in aliases) {
        if (textLower.contains(alias)) {
          return charId;
        }
      }
    }
    
    return null;
  }

  /// Автоматично визначає та встановлює теги для всіх модів
  /// Повертає кількість модів з визначеними тегами
  Future<Map<String, String>> autoTagAllMods() async {
    try {
      final modNames = await scanMods();
      final autoTags = <String, String>{};

      for (final modName in modNames) {
        // Skip mods that already have a character. The in-folder sidecar wins
        // (so a shared mod's tag isn't clobbered), then the legacy config tag.
        final modFolder = path.join(modsPath!, modName);
        final existingMeta = await _metadataService.read(modFolder);
        final existingTag = (existingMeta?.characterId != null && existingMeta!.characterId!.isNotEmpty)
            ? existingMeta.characterId
            : _configService.modCharacterTags[modName];
        if (existingTag != null && existingTag != 'unknown') {
          continue;
        }

        // Автоматично визначаємо тег з назви
        final detectedChar = await _detectCharacterFromName(modName);
        if (detectedChar != null) {
          // Writes the in-folder sidecar and mirrors to config.json.
          await setModCharacter(modName, detectedChar);
          autoTags[modName] = detectedChar;
        }
      }

      return autoTags;
    } catch (e) {
      return {};
    }
  }

  /// Рекурсивно копіює директорію
  Future<void> _copyDirectory(Directory source, Directory destination) async {
    await destination.create(recursive: true);
    
    await for (final entity in source.list(recursive: false)) {
      if (entity is Directory) {
        final newDirectory = Directory(path.join(
          destination.path,
          path.basename(entity.path),
        ));
        await _copyDirectory(entity, newDirectory);
      } else if (entity is File) {
        final newFile = File(path.join(
          destination.path,
          path.basename(entity.path),
        ));
        await entity.copy(newFile.path);
      }
    }
  }

  /// Зчитує keybinds для конкретного персонажа (моду)
  /// characterId - назва папки персонажа в modsPath
  Future<CharacterKeybinds?> getCharacterKeybinds(String characterId) async {
    try {
      if (modsPath == null) return null;

      final characterPath = path.join(modsPath!, characterId);
      final characterDir = Directory(characterPath);
      
      if (!await characterDir.exists()) return null;

      return await _iniParser.parseCharacterDirectory(characterId, characterPath);
    } catch (e) {
      print('ModManagerService: Помилка зчитування keybinds для $characterId: $e');
      return null;
    }
  }

  /// Зчитує keybinds для всіх персонажів в modsPath
  /// Повертає мапу characterId -> CharacterKeybinds
  Future<Map<String, CharacterKeybinds>> getAllCharactersKeybinds() async {
    try {
      if (modsPath == null) return {};
      
      return await _iniParser.parseAllCharacters(modsPath!);
    } catch (e) {
      print('ModManagerService: Помилка зчитування keybinds для всіх персонажів: $e');
      return {};
    }
  }

  /// Завантажує keybinds для конкретного моду
  /// modId - назва папки моду в modsPath
  Future<List<KeybindInfo>?> getModKeybinds(String modId) async {
    try {
      if (modsPath == null) return null;
      final modPath = path.join(modsPath!, modId);
      final keybindsData = await _iniParser.parseCharacterDirectory(modId, modPath);
      return keybindsData?.keybinds;
    } catch (e) {
      print('ModManagerService: Помилка завантаження keybinds для моду $modId: $e');
      return null;
    }
  }

  /// Оновлює інформацію про персонажів, додаючи keybinds до модів
  /// Приймає список персонажів і додає keybinds до кожного моду
  Future<List<CharacterInfo>> enrichCharactersWithKeybinds(
    List<CharacterInfo> characters,
  ) async {
    try {
      print('ModManagerService: Завантаження keybinds для модів...');
      
      final updatedCharacters = <CharacterInfo>[];
      
      for (final character in characters) {
        final updatedMods = <ModInfo>[];
        
        for (final mod in character.skins) {
          final keybinds = await getModKeybinds(mod.id);
          if (keybinds != null && keybinds.isNotEmpty) {
            print('ModManagerService: Знайдено ${keybinds.length} keybinds для моду ${mod.id}');
            updatedMods.add(mod.copyWith(keybinds: keybinds));
          } else {
            updatedMods.add(mod);
          }
        }
        
        updatedCharacters.add(character.copyWith(skins: updatedMods));
      }
      
      return updatedCharacters;
    } catch (e) {
      print('ModManagerService: Помилка збагачення модів keybinds: $e');
      return characters;
    }
  }
}
