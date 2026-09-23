import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glass_forge/src/platform/glass_forge_method_channel.dart';

/// Runs [body] with every [FlutterErrorDetails] collected rather than
/// presented, and returns them.
///
/// One `FlutterErrorDetails` at a time, deliberately: `takeException` folds
/// everything a single operation reported into one synthetic string and
/// discards the originals, and the failure this file is about arrives twice —
/// once per event channel.
Future<List<FlutterErrorDetails>> _errorsFrom(
  Future<void> Function() body,
) async {
  final errors = <FlutterErrorDetails>[];
  final reportToTest = FlutterError.onError;
  FlutterError.onError = errors.add;
  try {
    await body();
  } finally {
    FlutterError.onError = reportToTest;
  }
  return errors;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(MethodChannelGlassForge.debugResetStreams);
  tearDown(MethodChannelGlassForge.debugResetStreams);

  test(
    'a host with no plugin registered says nothing, loudly or quietly',
    () async {
      // No mock handler on either channel, which is what Windows and Linux
      // look like from Dart: no plugin registered, so the `listen` that
      // activates the stream comes back a MissingPluginException.
      //
      // Flutter raises that from inside the broadcast controller's `onListen`,
      // through `FlutterError.reportError` rather than by adding it to the
      // stream, so it is invisible to both a `try` around
      // `receiveBroadcastStream()` and a `handleError` on its result. It is
      // raised again from `onCancel`, so two channels opened and closed is
      // four red errors on a platform whose honest answer is that it has
      // nothing to say.
      final platform = MethodChannelGlassForge();
      final fromStreams = <Object>[];

      final errors = await _errorsFrom(() async {
        final reduce = platform.reduceTransparencyChanges().listen(
          (_) {},
          onError: fromStreams.add,
        );
        final thermal = platform.thermalStateChanges().listen(
          (_) {},
          onError: fromStreams.add,
        );
        await pumpEventQueue();
        await reduce.cancel();
        await thermal.cancel();
        await pumpEventQueue();
      });

      expect(
        errors.map((details) => details.exceptionAsString()).toList(),
        isEmpty,
      );
      expect(fromStreams, isEmpty);
    },
  );

  test(
    'a host that fails inside its stream handler is still reported',
    () async {
      // The other half of the claim above: the silence is for a host that
      // never registered, not for one that registered and then broke.
      final platform = MethodChannelGlassForge();
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            ..setMockStreamHandler(
              platform.thermalChannel,
              MockStreamHandler.inline(
                onListen: (_, _) =>
                    throw PlatformException(code: 'unavailable'),
              ),
            );
      addTearDown(
        () => messenger.setMockStreamHandler(platform.thermalChannel, null),
      );

      final errors = await _errorsFrom(() async {
        final thermal = platform.thermalStateChanges().listen((_) {});
        await pumpEventQueue();
        await thermal.cancel();
        await pumpEventQueue();
      });

      expect(
        errors
            .map((details) => details.exception)
            .whereType<PlatformException>(),
        isNotEmpty,
        reason: 'a broken host must not be silenced along with an absent one',
      );
    },
  );

  test('an event the host sends still arrives', () async {
    // The guard on open-coding `receiveBroadcastStream`: the envelope decode
    // and the message handler are ours now, so something has to prove they
    // still carry a value end to end.
    final platform = MethodChannelGlassForge();
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          ..setMockStreamHandler(
            platform.reduceTransparencyChannel,
            MockStreamHandler.inline(onListen: (_, sink) => sink.success(true)),
          );
    addTearDown(
      () => messenger.setMockStreamHandler(
        platform.reduceTransparencyChannel,
        null,
      ),
    );

    await expectLater(
      platform.reduceTransparencyChanges().first,
      completion(isTrue),
    );
  });
}
