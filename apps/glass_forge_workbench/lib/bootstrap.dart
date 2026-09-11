import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:glass_forge_workbench/constants/asset_paths.dart';

/// Phones are portrait-only. Below this shortest side a device is a phone;
/// tablets keep every orientation, which iPad multitasking requires.
const double _tabletShortestSide = 600;

Future<void> bootstrap(FutureOr<Widget> Function() builder) async {
  final binding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: binding);

  // Every screen draws under the system bars and insets its own chrome, so
  // Android 15's enforced edge-to-edge and every older release look the same.
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  final view = binding.platformDispatcher.views.first;
  final shortestSide = view.physicalSize.shortestSide / view.devicePixelRatio;
  if (shortestSide < _tabletShortestSide) {
    await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  }

  // Lifted here, at the root, rather than by whichever screen opens first: a
  // cold start into any other route would otherwise keep the splash forever.
  binding.addPostFrameCallback((_) => FlutterNativeSplash.remove());
  LicenseRegistry.addLicense(_bundledLicenses);
  runApp(await builder());
}

/// Geist is OFL and Phosphor is MIT; both licences require their notice to
/// travel with the app, so they appear on the platform licence page.
Stream<LicenseEntry> _bundledLicenses() async* {
  yield LicenseEntryWithLineBreaks(const [
    'Geist',
    'Geist Mono',
  ], await rootBundle.loadString(AssetPaths.geistLicense));
  yield LicenseEntryWithLineBreaks(const [
    'Phosphor Icons',
  ], await rootBundle.loadString(AssetPaths.phosphorLicense));
}
