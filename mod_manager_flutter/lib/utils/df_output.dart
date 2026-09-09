/// Reading free space out of `df`.
///
/// Its own file, and pure, because the parse is the whole risk: the numbers
/// decide whether a download is refused, and a misread column would refuse a
/// transfer that fits — while the process call around it cannot be tested
/// without a real filesystem.
library;

/// Free bytes from the output of `df -kP <path>`, or null if it says nothing
/// usable.
///
/// **The columns are found by shape rather than by index.** POSIX guarantees
/// the order — blocks, used, available, capacity — but not that the first
/// column is one word: a device path, a network share (`//host/share`) or a
/// bind mount can carry spaces, and splitting on whitespace then shifts every
/// column left. So this matches the four numeric columns as a run, anchored on
/// the `%` that only capacity has:
///
/// ```
/// Filesystem     1024-blocks      Used Available Capacity Mounted on
/// /dev/nvme0n1p2   982820144  412345678 520474466      45% /
/// ```
///
/// Reads the **last** matching line, so a `df` given a path that resolves
/// through more than one entry answers for the filesystem the path is actually
/// on rather than for whatever came first.
///
/// `-k` fixes the block size at 1 KiB rather than trusting the environment:
/// `df` honours `BLOCKSIZE`/`DF_BLOCK_SIZE`, so a user with that set would
/// otherwise have their free space read as a different unit entirely.
int? parseDfAvailableBytes(String output) {
  final pattern = RegExp(r'\s(\d+)\s+(\d+)\s+(\d+)\s+\d+%');

  int? availableKiB;
  for (final line in output.split('\n')) {
    final match = pattern.firstMatch(line);
    if (match != null) availableKiB = int.tryParse(match.group(3)!);
  }

  if (availableKiB == null) return null;
  return availableKiB * 1024;
}
