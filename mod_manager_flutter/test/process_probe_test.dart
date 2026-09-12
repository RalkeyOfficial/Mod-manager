@TestOn('linux')
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mod_manager_flutter/utils/process_probe.dart';

/// The probe's cap, and saying when it was hit.
///
/// **A capped result still looks like a successful one** — exit code 0, parseable
/// output, no error — so anything that sums or counts what a tool printed reads a
/// number that is too small unless it checks [ProbeResult.truncated]. That is how
/// an archive listing comes to say an install fits when it does not.
///
/// `seq` rather than a scripted fake: the cap exists because of how a real pipe
/// behaves, and a child that fills its buffer and blocks is exactly what a fake
/// cannot reproduce.
void main() {
  test('output past the cap is reported as truncated', () async {
    final result =
        await const ProcessProbe(maxBytes: 1024).run('seq', ['1', '100000']);

    expect(result, isNotNull);
    expect(result!.exitCode, 0, reason: 'the tool itself succeeded');
    expect(result.truncated, isTrue);
  });

  test('the child still exits, so draining continues past the cap', () async {
    // The reason the cap keeps reading and only stops *keeping*: a child that
    // fills the pipe buffer blocks on write, and a probe that stopped reading
    // would hang forever on the tool it was meant to time out.
    final result = await const ProcessProbe(
      maxBytes: 64,
      timeout: Duration(seconds: 5),
    ).run('seq', ['1', '200000']);

    expect(result!.timedOut, isFalse);
    expect(result.exitCode, 0);
  });

  test('output within the cap is not truncated, and is complete', () async {
    final result =
        await const ProcessProbe(maxBytes: 1 << 20).run('seq', ['1', '10']);

    expect(result!.truncated, isFalse);
    expect(result.stdout.trim().split('\n'), hasLength(10));
  });

  test('a tool that is not there is null rather than an exception', () async {
    expect(await const ProcessProbe().run('definitely-not-a-tool', const []),
        isNull);
  });
}
