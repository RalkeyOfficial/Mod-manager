@TestOn('linux')
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mod_manager_flutter/services/platform_service_linux.dart';

/// The one test here that actually spawns `df`.
///
/// Everything else about the preflight is tested against a stub, which proves
/// the arithmetic and proves nothing about the command: a wrong flag, a `df`
/// that is not on `PATH`, or output this parser cannot read would all show up
/// as "free space unknown" and silently switch the check off for every user.
/// So this asks the real service about a real directory.
///
/// It asserts a *range* rather than a number, because the number is the
/// machine's and moves between runs.
void main() {
  test('reads a plausible free space for a real directory', () async {
    final free = await LinuxPlatformService().freeSpaceBytes(
      Directory.systemTemp.path,
    );

    expect(free, isNotNull, reason: 'df is present on any Linux CI or desktop');
    expect(free, greaterThan(0));
    // A sanity ceiling rather than a real limit: 1 EiB would mean the units are
    // being read as bytes when they are KiB, which is the mistake that matters.
    expect(free, lessThan(1 << 60));
  });

  test('a path that does not exist is unknown rather than zero', () async {
    // Zero would refuse every download; null skips the check. The difference is
    // the whole contract of the method.
    final free = await LinuxPlatformService()
        .freeSpaceBytes('/nonexistent-${DateTime.now().microsecondsSinceEpoch}');

    expect(free, isNull);
  });
}
