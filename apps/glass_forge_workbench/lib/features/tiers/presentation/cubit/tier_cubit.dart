import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:glass_forge/glass_forge.dart';
import 'package:glass_forge_workbench/features/tiers/presentation/cubit/tier_state.dart';
import 'package:glass_forge_workbench/utils/enums/glass_backdrop.dart';

/// Owns a [GlassTierEngine] and republishes its verdict as state.
///
/// The engine is a plain listenable, so it belongs here rather than in the
/// widget tree: a `GlassTierScope` that created its own would give the
/// screen no way to pin a tier or read the evidence, which is the entire
/// subject of this screen.
class TierCubit extends Cubit<TierState> {
  /// Creates the cubit.
  ///
  /// [engine] lets a test supply fixed signals. Anything created here is
  /// disposed here; anything passed in is left to its owner.
  factory TierCubit({GlassTierEngine? engine}) =>
      TierCubit._(engine ?? GlassTierEngine(), ownsEngine: engine == null);

  TierCubit._(GlassTierEngine engine, {required bool ownsEngine})
    : _engine = engine,
      _ownsEngine = ownsEngine,
      super(TierState(resolved: engine.value)) {
    _engine.addListener(_onEngineChanged);
  }

  final GlassTierEngine _engine;
  final bool _ownsEngine;

  /// The engine, for the `GlassTierScope` that hands its verdict to the
  /// glass on the stage.
  GlassTierEngine get engine => _engine;

  /// Starts the four signals.
  ///
  /// Safe to call on an injected engine that is already running — the
  /// engine ignores a second start.
  void init() => unawaited(_engine.start());

  /// Pins a tier, or clears the pin when [tier] is null.
  void forceTier(GlassTier? tier) => _engine.requested = tier;

  /// Picks the backdrop the specimen is judged over.
  void setBackdrop(GlassBackdrop backdrop) =>
      emit(state.copyWith(backdrop: backdrop));

  void _onEngineChanged() => emit(state.copyWith(resolved: _engine.value));

  @override
  Future<void> close() {
    _engine.removeListener(_onEngineChanged);
    if (_ownsEngine) {
      _engine.dispose();
    }
    return super.close();
  }
}
