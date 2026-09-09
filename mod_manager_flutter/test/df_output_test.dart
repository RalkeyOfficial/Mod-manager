import 'package:flutter_test/flutter_test.dart';
import 'package:mod_manager_flutter/utils/df_output.dart';

/// Reading free space out of `df -kP`.
///
/// **A misread column refuses a download that would have fit**, which is the
/// one outcome this feature must not produce — so every shape of `df` output
/// that a real machine can hand back is here, including the ones where naive
/// whitespace splitting shifts the columns.
void main() {
  test('reads the available column', () {
    const output = '''
Filesystem     1024-blocks      Used Available Capacity Mounted on
/dev/nvme0n1p2   982820144 412345678 520474466      45% /
''';

    expect(parseDfAvailableBytes(output), 520474466 * 1024);
  });

  test('a filesystem name with spaces does not shift the columns', () {
    // A network share, a loop device with a label, a bind mount — all real, and
    // all fatal to `split(' ')[3]`.
    const output = '''
Filesystem       1024-blocks     Used Available Capacity Mounted on
//nas/my share     976284416 12345678 963938738       2% /mnt/nas
''';

    expect(parseDfAvailableBytes(output), 963938738 * 1024);
  });

  test('a mount point with spaces does not either', () {
    const output = '''
Filesystem     1024-blocks     Used Available Capacity Mounted on
/dev/sdb1        488384000 48838400 439545600      10% /run/media/me/My Drive
''';

    expect(parseDfAvailableBytes(output), 439545600 * 1024);
  });

  test('the last filesystem wins', () {
    // `df` given several paths, or one that resolves through more than one
    // entry: the answer wanted is the one for the path asked about, which comes
    // last.
    const output = '''
Filesystem     1024-blocks      Used Available Capacity Mounted on
/dev/sda1          1024000    512000    512000      50% /
/dev/sdb1        488384000  48838400 439545600      10% /home
''';

    expect(parseDfAvailableBytes(output), 439545600 * 1024);
  });

  test('a full volume reads as zero rather than as unknown', () {
    // Zero and null are different answers and the caller treats them
    // differently: zero refuses the download, null skips the check.
    const output = '''
Filesystem     1024-blocks      Used Available Capacity Mounted on
/dev/sda1          1024000   1024000         0     100% /
''';

    expect(parseDfAvailableBytes(output), 0);
  });

  test('nothing usable is null', () {
    expect(parseDfAvailableBytes(''), isNull);
    expect(parseDfAvailableBytes('df: /nope: No such file or directory'), isNull);
    expect(
      parseDfAvailableBytes(
          'Filesystem     1024-blocks      Used Available Capacity Mounted on'),
      isNull,
      reason: 'a header alone says nothing about any volume',
    );
  });
}
