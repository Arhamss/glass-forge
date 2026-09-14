import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:glass_forge/src/tier/glass_tier_engine.dart';
import 'package:glass_forge/src/tier/tier_profile.dart';
import 'package:glass_forge/src/tier/tier_resolver.dart';

/// Makes a resolved tier available to every `GlassLayer` beneath it.
///
/// Wrap this around an app — above the navigator, so one engine serves every
/// route — and glass layers adopt the tier automatically. Without it, nothing
/// changes: layers behave exactly as they did before there was a tier engine,
/// which is the point. The engine starts a frame-timings callback and two
/// platform channels, and an app that never asked for adaptive tiering should
/// not silently acquire them.
///
/// A layer's own `tier:` argument still wins over whatever is resolved here.
class GlassTierScope extends StatefulWidget {
  /// Creates a scope.
  ///
  /// [engine] lets a host own the engine — to pin a tier from a settings
  /// screen, or to read the diagnostics — in which case the host also
  /// disposes it. With no [engine], one is created and disposed here.
  const GlassTierScope({
    required this.child,
    this.engine,
    this.requested,
    super.key,
  });

  /// The subtree that adopts the resolved tier.
  final Widget child;

  /// An engine to adopt rather than create.
  final GlassTierEngine? engine;

  /// A tier to pin, for a scope that owns its engine.
  ///
  /// Ignored when [engine] is supplied — an engine that belongs to someone
  /// else takes its instructions from them, and having two writers of the
  /// same pin is how a settings screen and a widget tree end up fighting.
  final GlassTier? requested;

  /// The resolved tier in scope, or null if there is none.
  static ResolvedTier? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<_InheritedResolvedTier>()
        ?.resolved;
  }

  /// The resolved tier in scope.
  ///
  /// Throws when there is no [GlassTierScope] above [context]. Use
  /// [maybeOf] where absence is a normal case — which it is for `GlassLayer`,
  /// since tiering is opt-in.
  static ResolvedTier of(BuildContext context) {
    final resolved = maybeOf(context);
    if (resolved == null) {
      throw FlutterError(
        'GlassTierScope.of() was called with a context that has no '
        'GlassTierScope ancestor.\n'
        'Wrap the part of the tree that needs a resolved tier in a '
        'GlassTierScope, or use GlassTierScope.maybeOf() if having no scope '
        'is expected.',
      );
    }
    return resolved;
  }

  @override
  State<GlassTierScope> createState() => _GlassTierScopeState();
}

class _GlassTierScopeState extends State<GlassTierScope> {
  GlassTierEngine? _owned;
  late GlassTierEngine _engine;

  @override
  void initState() {
    super.initState();
    _attach();
  }

  @override
  void didUpdateWidget(GlassTierScope oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.engine != widget.engine) {
      _detach();
      _attach();
      return;
    }
    if (_owned != null && oldWidget.requested != widget.requested) {
      _owned!.requested = widget.requested;
    }
  }

  void _attach() {
    final provided = widget.engine;
    if (provided != null) {
      _owned = null;
      _engine = provided;
    } else {
      _engine = _owned = GlassTierEngine(requested: widget.requested);
      // Starting is fire-and-forget: every signal's value is already valid
      // before it starts (unknown thermal, healthy frames, the accessibility
      // bitmask Flutter already has), so the first build renders a real tier
      // rather than waiting on a platform channel.
      unawaited(_owned!.start());
    }
    _engine.addListener(_onTierChanged);
  }

  void _detach() {
    _engine.removeListener(_onTierChanged);
    _owned?.dispose();
    _owned = null;
  }

  void _onTierChanged() => setState(() {});

  @override
  void dispose() {
    _detach();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _InheritedResolvedTier(
      resolved: _engine.value,
      child: widget.child,
    );
  }
}

class _InheritedResolvedTier extends InheritedWidget {
  const _InheritedResolvedTier({required this.resolved, required super.child});

  final ResolvedTier resolved;

  /// Rebuilds dependents only when the rendered outcome moves.
  ///
  /// A [ResolvedTier] also carries the evidence behind the verdict, and that
  /// evidence changes far more often than the verdict does — a device warming
  /// from nominal to fair, a watchdog stepping somewhere a ceiling already
  /// sat below. Every `GlassLayer` in the app is a dependent, so comparing
  /// whole resolved tiers here would rebuild all of them for a thermal
  /// reading that changes nothing about what they draw.
  @override
  bool updateShouldNotify(_InheritedResolvedTier oldWidget) =>
      oldWidget.resolved.tier != resolved.tier ||
      oldWidget.resolved.profile != resolved.profile;
}
