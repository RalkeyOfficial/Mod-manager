/// Portable, per-mod metadata stored inside the mod's own folder
/// (`<mod>/.zzz-mod-manager/metadata.json`) so it travels with the mod when it
/// is shared or renamed. This is the source of truth for everything intrinsic
/// to a mod; per-install state (active link, favorite) stays in config.json.
class ModMetadata {
  /// Schema version, so the on-disk format can evolve without breaking old files.
  final int schemaVersion;

  /// Free-form description.
  final String? description;

  /// Link to the mod's source page (GameBanana or any URL).
  final String? sourceUrl;

  /// Arbitrary user tags.
  final List<String> tags;

  /// Character this mod is assigned to (moved here from config.json).
  final String? characterId;

  /// Image paths **relative to the mod folder root** (e.g.
  /// `.zzz-mod-manager/images/01.png`, or a shipped `Preview.png`). The first
  /// entry is treated as the cover.
  final List<String> images;

  static const int currentSchemaVersion = 1;

  const ModMetadata({
    this.schemaVersion = currentSchemaVersion,
    this.description,
    this.sourceUrl,
    this.tags = const [],
    this.characterId,
    this.images = const [],
  });

  /// True when there is nothing worth persisting.
  bool get isEmpty =>
      (description == null || description!.isEmpty) &&
      (sourceUrl == null || sourceUrl!.isEmpty) &&
      tags.isEmpty &&
      (characterId == null || characterId!.isEmpty) &&
      images.isEmpty;

  factory ModMetadata.fromJson(Map<String, dynamic> json) {
    return ModMetadata(
      schemaVersion: json['schema_version'] as int? ?? currentSchemaVersion,
      description: json['description'] as String?,
      sourceUrl: json['source_url'] as String?,
      tags: (json['tags'] as List?)?.map((e) => e.toString()).toList() ?? const [],
      characterId: json['character_id'] as String?,
      images: (json['images'] as List?)?.map((e) => e.toString()).toList() ?? const [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'schema_version': schemaVersion,
      if (description != null) 'description': description,
      if (sourceUrl != null) 'source_url': sourceUrl,
      'tags': tags,
      if (characterId != null) 'character_id': characterId,
      'images': images,
    };
  }

  ModMetadata copyWith({
    int? schemaVersion,
    String? description,
    String? sourceUrl,
    List<String>? tags,
    String? characterId,
    List<String>? images,
  }) {
    return ModMetadata(
      schemaVersion: schemaVersion ?? this.schemaVersion,
      description: description ?? this.description,
      sourceUrl: sourceUrl ?? this.sourceUrl,
      tags: tags ?? this.tags,
      characterId: characterId ?? this.characterId,
      images: images ?? this.images,
    );
  }
}
