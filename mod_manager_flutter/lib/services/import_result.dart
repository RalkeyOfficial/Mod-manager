/// What an import did, and why it did nothing when it did nothing.
///
/// **A null [failure] with nothing imported means a genuine duplicate** — the
/// one reason an import installs nothing that is not a failure. Every other
/// reason carries its own [ImportFailure], so a full disk, an unwritable
/// library or an unset mods folder can never be reported as "you already have
/// this mod", which sends the user looking for a mod that was never installed.
class ImportResult {
  const ImportResult({
    required this.imported,
    this.autoTags = const {},
    this.failure,
    this.requiredBytes,
    this.availableBytes,
  });

  /// Imported nothing, because there was nothing to import.
  const ImportResult.nothing()
      : imported = const [],
        autoTags = const {},
        failure = null,
        requiredBytes = null,
        availableBytes = null;

  const ImportResult.failed(ImportFailure this.failure)
      : imported = const [],
        autoTags = const {},
        requiredBytes = null,
        availableBytes = null;

  /// Refused before copying anything, because the library volume cannot hold it.
  const ImportResult.noSpace({
    required int this.requiredBytes,
    required int this.availableBytes,
  })  : imported = const [],
        autoTags = const {},
        failure = ImportFailure.notEnoughSpace;

  /// The mod folders now in the library, by name.
  final List<String> imported;

  /// Characters detected during the import and already written to disk.
  final Map<String, String> autoTags;

  /// Null when nothing went wrong.
  final ImportFailure? failure;

  /// What the copy needed and what the volume had, for
  /// [ImportFailure.notEnoughSpace] and nothing else.
  final int? requiredBytes;
  final int? availableBytes;
}

/// Why an import installed nothing, where the answer changes what the user does
/// next.
enum ImportFailure {
  /// The library volume cannot hold the files. The numbers say by how much, and
  /// clearing space is the whole fix.
  notEnoughSpace,

  /// No mods folder is configured, so there is nowhere to import to. Settings
  /// is where that is fixed.
  libraryNotConfigured,

  /// The copy itself failed — a permission, a device error, a name the
  /// filesystem refused.
  copyFailed,

  /// Every folder offered was unreadable or gone by the time the copy reached
  /// it, so there was nothing left to install.
  nothingUsable,
}
