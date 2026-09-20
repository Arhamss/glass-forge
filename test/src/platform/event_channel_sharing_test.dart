import 'package:flutter_test/flutter_test.dart';
import 'package:glass_forge/src/platform/glass_forge_method_channel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'one native listen per channel however many consumers subscribe',
    () async {
      // Flutter allows exactly one active stream per EventChannel, and every
      // `receiveBroadcastStream()` call builds a *new* one. Two of them means
      // two listen/cancel pairs on a single native channel, and the second
      // cancel finds nothing to cancel: the host throws
      // "No active stream to cancel". It surfaces from the cancel handler, not
      // from the stream, so a consumer cannot catch it — it just fails their
      // test. Reported from an integration run that pumped its app twice.
      MethodChannelGlassForge.debugResetStreams();
      addTearDown(MethodChannelGlassForge.debugResetStreams);
      final platform = MethodChannelGlassForge();
      var listens = 0;
      var cancels = 0;

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockStreamHandler(
            platform.reduceTransparencyChannel,
            MockStreamHandler.inline(
              onListen: (_, _) => listens++,
              onCancel: (_) => cancels++,
            ),
          );
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockStreamHandler(platform.reduceTransparencyChannel, null),
      );

      final first = platform.reduceTransparencyChanges().listen((_) {});
      final second = platform.reduceTransparencyChanges().listen((_) {});
      await pumpEventQueue();

      expect(listens, 1, reason: 'the host was asked to open $listens streams');

      await first.cancel();
      await second.cancel();
      await pumpEventQueue();

      expect(
        cancels,
        1,
        reason:
            'the host got $cancels cancels for $listens streams; the '
            'surplus is what throws "No active stream to cancel"',
      );
    },
  );
}
