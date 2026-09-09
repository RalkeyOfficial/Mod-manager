import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mod_manager_flutter/services/download/download_exceptions.dart';
import 'package:mod_manager_flutter/services/download/download_request.dart';
import 'package:mod_manager_flutter/services/download/download_service.dart';

import '../support/fake_download_transport.dart';

/// **Refusing a download that provably will not fit, before it starts.**
///
/// GameBanana's `_nFilesize` is the eventual `Content-Length` to the byte, so
/// the requirement is a fact rather than an estimate — which is what makes a
/// refusal legitimate. Everything here is about the two ways that can go wrong:
/// refusing a transfer that *would* have fit, and letting the refusal happen
/// after the wait it exists to save.
void main() {
  late Directory temp;
  late FakeDownloadTransport transport;

  final url = Uri.parse('https://gamebanana.com/dl/1770600');
  final body = List<int>.generate(200, (i) => i % 256);

  DownloadService build({
    required Future<int?> Function(String path) freeSpace,
  }) =>
      DownloadService(
        transport: transport,
        directory: temp,
        progressInterval: const Duration(milliseconds: 10),
        freeSpace: freeSpace,
      );

  DownloadRequest request({int? expectedSize, String name = 'mod.rar'}) =>
      DownloadRequest(
        url: url,
        suggestedFilename: name,
        fileId: 1770600,
        expectedSize: expectedSize,
      );

  setUp(() {
    temp = Directory.systemTemp.createTempSync('free_space_preflight_test_');
    transport = FakeDownloadTransport();
  });

  tearDown(() {
    if (temp.existsSync()) temp.deleteSync(recursive: true);
  });

  test('a file that does not fit is refused, and nothing is requested',
      () async {
    transport.enqueue(url, body: body);

    final service = build(freeSpace: (_) async => 500);

    await expectLater(
      service.start(request(expectedSize: 2000)).done,
      throwsA(isA<InsufficientSpaceException>()
          .having((e) => e.requiredBytes, 'required', 2000)
          .having((e) => e.availableBytes, 'available', 500)),
    );
    expect(transport.callCount, 0,
        reason: 'the point is not waiting for the failure');
    expect(temp.listSync(), isEmpty,
        reason: 'a refused download leaves nothing behind');
  });

  test('a file that fits exactly is allowed', () async {
    // The boundary matters in this direction: refusing a download that fits is
    // the failure mode with no way out for the user.
    transport.enqueue(url, body: body);

    final result = await build(freeSpace: (_) async => 200)
        .start(request(expectedSize: 200))
        .done;

    expect(result.file.existsSync(), isTrue);
  });

  test('what a partial already holds is not asked for twice', () async {
    // A resumed transfer needs the *rest* of the file. Counting the whole size
    // would refuse the resume of a nearly-complete download on a volume with
    // ample room for what is left — and a user with a 1.2 GB archive 95% of the
    // way in is exactly who cannot afford to start over.
    transport.enqueue(url,
        body: body, failAfter: 150, chunkSize: 50, headers: {'etag': '"abc"'});
    await expectLater(
      build(freeSpace: (_) async => 1 << 30).start(request(expectedSize: 200)).done,
      throwsA(isA<Object>()),
    );

    transport.enqueue(
      url,
      body: body.sublist(150),
      statusCode: 206,
      headers: {'content-range': 'bytes 150-199/200', 'etag': '"abc"'},
    );

    final result = await build(freeSpace: (_) async => 60)
        .start(request(expectedSize: 200))
        .done;

    expect(result.resumed, isTrue);
    expect(result.file.readAsBytesSync(), body,
        reason: '50 bytes were still needed, and 60 were free');
  });

  test('an unknown free space lets the transfer run', () async {
    // Dart has no portable free-space API, so "cannot tell" has to mean "carry
    // on and fail honestly if it must" — never a refusal on a guess.
    transport.enqueue(url, body: body);

    final result =
        await build(freeSpace: (_) async => null).start(request(expectedSize: 1 << 30)).done;

    expect(result.file.existsSync(), isTrue);
  });

  test('a file of unknown size is not checked either', () async {
    transport.enqueue(url, body: body);

    var asked = false;
    final result = await build(freeSpace: (_) async {
      asked = true;
      return 0;
    }).start(request()).done;

    expect(result.file.existsSync(), isTrue);
    expect(asked, isFalse, reason: 'nothing to compare a free space against');
  });

  test('a transfer already running counts against the next one', () async {
    // Two at a time write into the same directory, so each fitting on its own
    // is not the question. The first job's remaining bytes are already
    // committed to this volume.
    final second = Uri.parse('https://gamebanana.com/dl/1770601');
    final held = StreamController<List<int>>();
    addTearDown(() => held.close());

    transport.enqueueControlled(url, held, contentLength: 1000);
    transport.enqueue(second, body: body);

    final service = build(freeSpace: (_) async => 1200);
    final first = service.start(request(expectedSize: 1000)).done;

    // The first transfer is open and has written nothing, so it still owes the
    // volume 1000 of the 1200 free.
    await Future<void>.delayed(const Duration(milliseconds: 20));

    await expectLater(
      service
          .start(DownloadRequest(
            url: second,
            suggestedFilename: 'other.rar',
            fileId: 1770601,
            expectedSize: 400,
          ))
          .done,
      throwsA(isA<InsufficientSpaceException>()
          .having((e) => e.requiredBytes, 'required', 1400)),
    );

    held.add(body);
    await held.close();
    await first;
  });
}
