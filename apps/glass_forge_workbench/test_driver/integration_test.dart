import 'dart:io';

import 'package:integration_test/integration_test_driver_extended.dart';

/// Saves every screenshot the tour takes under `$TOUR_OUT` (default
/// `build/tour`).
Future<void> main() => integrationDriver(
  onScreenshot: (name, bytes, [args]) async {
    final directory = Platform.environment['TOUR_OUT'] ?? 'build/tour';
    final file = File('$directory/$name.png');
    await file.create(recursive: true);
    await file.writeAsBytes(bytes);
    return true;
  },
);
