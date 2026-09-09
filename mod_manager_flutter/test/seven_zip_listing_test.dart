import 'package:flutter_test/flutter_test.dart';
import 'package:mod_manager_flutter/utils/seven_zip_listing.dart';

/// Reading an archive's unpacked size out of `7z l -slt`.
///
/// The number refuses installs, so the two ways it can be wrong are both here:
/// counting the wrong `Size` line — `Packed Size` is what the archive already
/// holds, `Physical Size` is the archive itself — and reading nothing as zero,
/// which would refuse everything.
void main() {
  /// Real `7z l -slt` output, trimmed to the shape that matters: a header block
  /// naming the archive, then one block per entry.
  const listing = '''
7-Zip 26.03 (x64) : Copyright (c) 1999-2026 Igor Pavlov : 2026-09-03

Listing archive: Mod.7z

--
Path = Mod.7z
Type = 7z
Physical Size = 100229
Headers Size = 189

----------
Path = mod
Size = 0
Packed Size = 0
Attributes = D drwxr-xr-x

Path = mod/a.ini
Size = 30
Packed Size = 100040
Attributes = A -rw-r--r--

Path = mod/big.dds
Size = 100000
Packed Size = 0
Attributes = A -rw-r--r--
''';

  test('sums the unpacked sizes of the entries', () {
    expect(parseSevenZipUnpackedBytes(listing), 100030);
  });

  test('the archive\'s own physical size is not one of them', () {
    // `Physical Size = 100229` is the file on disk. Counting it would refuse an
    // unpack over space the archive is already using.
    expect(parseSevenZipUnpackedBytes(listing), isNot(100229));
    expect(parseSevenZipUnpackedBytes(listing), lessThan(100229 + 100030));
  });

  test('packed sizes are not counted', () {
    // 100040 is larger than the file it holds — 7-Zip reports a solid block's
    // packed size against its first entry. Counting these would inflate the
    // requirement past anything real.
    expect(parseSevenZipUnpackedBytes(listing), isNot(200070));
  });

  test('a listing with no entries is unknown, not zero', () {
    // Zero would sail through the check as "needs nothing"; null skips it. Both
    // proceed, so this is about the log and the next reader rather than the
    // outcome — but a listing that could not be read is not a claim that the
    // archive is empty.
    expect(parseSevenZipUnpackedBytes(''), isNull);
    expect(
      parseSevenZipUnpackedBytes('''
--
Path = Mod.7z
Type = 7z
Physical Size = 100229
'''),
      isNull,
    );
  });

  test('a directory-only archive contributes nothing', () {
    expect(
      parseSevenZipUnpackedBytes('''
Path = mod
Size = 0
Packed Size = 0
'''),
      0,
    );
  });

  test('windows line endings parse', () {
    // 7-Zip on Windows prints CRLF, and `\\s*\$` is what tolerates the `\\r`.
    expect(
      parseSevenZipUnpackedBytes('Path = a.ini\r\nSize = 42\r\n'),
      42,
    );
  });
}
