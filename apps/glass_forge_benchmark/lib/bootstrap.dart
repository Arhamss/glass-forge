import 'dart:async';
import 'dart:developer';

import 'package:flutter/widgets.dart';
import 'package:glass_forge_benchmark/core/di/injector.dart';

/// Bootstrap for the benchmark harness.
///
/// Intentionally does less than the standard app bootstrap. Anything that runs
/// before `runApp` — splash preservation, observers that log on every state
/// change, device preview wrappers — lands inside the first frames this app
/// exists to measure. A `BlocObserver` that calls `log()` per change is
/// especially bad: it does synchronous work on the UI thread during exactly
/// the frames under test.
///
/// If you are tempted to add something here, add it to a scenario instead.
Future<void> bootstrap(FutureOr<Widget> Function() builder) async {
  FlutterError.onError = (details) {
    log(details.exceptionAsString(), stackTrace: details.stack);
  };

  WidgetsFlutterBinding.ensureInitialized();
  await Injector.setup();
  runApp(await builder());
}
