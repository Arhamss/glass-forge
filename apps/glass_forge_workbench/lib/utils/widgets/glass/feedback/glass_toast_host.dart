import 'dart:async';

import 'package:glass_forge/glass_forge.dart';
import 'package:glass_forge_workbench/exports.dart';
import 'package:glass_forge_workbench/utils/helpers/reduce_motion.dart';
import 'package:glass_forge_workbench/utils/widgets/glass/house_glass.dart';
import 'package:glass_forge_workbench/utils/widgets/glass/zones/glass_priority.dart';
import 'package:glass_forge_workbench/utils/widgets/glass/zones/kit_glass_layer.dart';
import 'package:glass_forge_workbench/utils/widgets/primitives/app_svg_icon.dart';

/// One toast's whole life: it drops in under the status bar, waits, and
/// slides back up, then calls [onDismissed] so its overlay entry can go.
///
/// Built by `showGlassToast`, which owns the overlay entry.
class GlassToastHost extends StatefulWidget {
  const GlassToastHost({
    required this.message,
    required this.onDismissed,
    this.icon,
    super.key,
  });

  final String message;

  /// An asset path, drawn in the accent.
  final String? icon;
  final VoidCallback onDismissed;

  static const double height = 52;

  @override
  State<GlassToastHost> createState() => _GlassToastHostState();
}

class _GlassToastHostState extends State<GlassToastHost>
    with SingleTickerProviderStateMixin {
  // Long enough to read a short line; the exit is quicker than the entrance
  // because by then the message has been read.
  static const _hold = Duration(milliseconds: 2400);
  static const _exit = Duration(milliseconds: 240);

  static const double _maxWidth = 420;
  static const double _radius = 26;
  static const double _iconSize = 20;

  // How far above its resting place the toast starts and ends, past the top
  // inset: clear of the screen with its shadow, at any allowed text size.
  static const double _offscreen = 120;

  // A swipe up this far, or this fast, sends it away; anything less and it
  // settles back.
  static const double _dismissDistance = 32;
  static const double _dismissVelocity = 300;

  static const _shape = GlassSuperellipse(
    radius: BorderRadius.all(Radius.circular(_radius)),
  );

  // 1 is resting in place, 0 is fully off the top. A drag writes to it
  // directly, so the toast follows the finger one to one.
  late final AnimationController _presence = AnimationController(
    vsync: this,
    duration: AppMotion.sheet,
    reverseDuration: _exit,
  );

  Timer? _holdTimer;
  bool _entered = false;
  bool _leaving = false;
  bool _reduceMotion = false;
  double _travel = _offscreen;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = context.reduceMotion;
    _travel = MediaQuery.paddingOf(context).top + AppSpacing.s8 + _offscreen;
    if (_entered) return;
    _entered = true;
    _settle();
  }

  @override
  void dispose() {
    _holdTimer?.cancel();
    _presence.dispose();
    super.dispose();
  }

  // Brings the toast to rest, then starts the wait before it leaves.
  void _settle() {
    if (_reduceMotion) {
      _presence.value = 1;
      _startHold();
      return;
    }
    unawaited(
      _presence
          .animateTo(1, curve: Curves.easeOutCubic)
          .then((_) => _startHold()),
    );
  }

  void _startHold() {
    _holdTimer?.cancel();
    _holdTimer = Timer(_hold, _leave);
  }

  void _leave() {
    if (_leaving) return;
    _leaving = true;
    _holdTimer?.cancel();
    if (_reduceMotion || _presence.value == 0) {
      _presence.value = 0;
      widget.onDismissed();
      return;
    }
    unawaited(
      _presence
          .animateBack(0, curve: Curves.easeInCubic)
          .then((_) => widget.onDismissed()),
    );
  }

  void _onDragStart(DragStartDetails details) {
    if (_leaving) return;
    _holdTimer?.cancel();
    _presence.stop();
  }

  void _onDragUpdate(DragUpdateDetails details) {
    if (_leaving) return;
    final delta = details.primaryDelta ?? 0;
    _presence.value = (_presence.value + delta / _travel).clamp(0, 1);
  }

  void _onDragEnd(DragEndDetails details) {
    if (_leaving) return;
    final velocity = details.primaryVelocity ?? 0;
    final lifted = (1 - _presence.value) * _travel;
    if (velocity < -_dismissVelocity || lifted > _dismissDistance) {
      _leave();
    } else {
      _settle();
    }
  }

  void _onDragCancel() {
    if (!_leaving) _settle();
  }

  @override
  Widget build(BuildContext context) {
    final icon = widget.icon;
    return Align(
      alignment: AlignmentDirectional.topCenter,
      child: Padding(
        padding: EdgeInsetsDirectional.only(
          top: MediaQuery.paddingOf(context).top + AppSpacing.s8,
          start: AppSpacing.s16,
          end: AppSpacing.s16,
        ),
        // Moved, never faded: an opacity layer over the backdrop pass breaks
        // it on device.
        child: AnimatedBuilder(
          animation: _presence,
          builder: (context, child) => Transform.translate(
            offset: Offset(0, -(1 - _presence.value) * _travel),
            child: child,
          ),
          child: Semantics(
            container: true,
            onDismiss: _leave,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              excludeFromSemantics: true,
              onVerticalDragStart: _onDragStart,
              onVerticalDragUpdate: _onDragUpdate,
              onVerticalDragEnd: _onDragEnd,
              onVerticalDragCancel: _onDragCancel,
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: _maxWidth,
                  minHeight: GlassToastHost.height,
                ),
                child: DecoratedBox(
                  // Painted before the glass, so the glass bends it too and
                  // the toast reads as floating over the screen.
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(_radius),
                    boxShadow: const [
                      BoxShadow(
                        color: AppColors.glassShadow,
                        blurRadius: 28,
                        offset: Offset(0, 10),
                        spreadRadius: -6,
                      ),
                    ],
                  ),
                  child: KitGlassLayer(
                    material: HouseGlass.overlayOf(context),
                    priority: GlassPriority.overlay,
                    shape: _shape,
                    child: ColoredBox(
                      color: AppColors.glassMessageScrim,
                      child: MediaQuery.withClampedTextScaling(
                        maxScaleFactor: 1.3,
                        child: Padding(
                          padding: const EdgeInsetsDirectional.symmetric(
                            horizontal: AppSpacing.s20,
                            vertical: AppSpacing.s8,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (icon != null) ...[
                                AppSvgIcon(
                                  icon,
                                  size: _iconSize,
                                  color: AppColors.accent,
                                ),
                                const SizedBox(width: AppSpacing.s12),
                              ],
                              Flexible(
                                // The root overlay sits outside every
                                // Material, so the app's fallback text style
                                // would otherwise show through.
                                child: DefaultTextStyle(
                                  style: context.callout,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  child: Text(widget.message),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
