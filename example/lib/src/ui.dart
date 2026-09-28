import 'dart:async';

import 'package:flutter/widgets.dart';

/// The app's whole palette. Glass brings the colour; the chrome stays out of
/// its way.
abstract final class Tone {
  static const Color primary = Color(0xFFFFFFFF);
  static const Color secondary = Color(0xB3FFFFFF);
  static const Color tertiary = Color(0x73FFFFFF);
  static const Color hairline = Color(0x26FFFFFF);
  static const Color wash = Color(0x14FFFFFF);
  static const Color ground = Color(0xFF07080A);
}

/// Four text styles. Anything else is a smell.
abstract final class Font {
  static const TextStyle display = TextStyle(
    fontFamily: 'Geist',
    fontSize: 34,
    height: 1.05,
    fontWeight: FontWeight.w600,
    letterSpacing: -1.2,
    color: Tone.primary,
  );

  static const TextStyle title = TextStyle(
    fontFamily: 'Geist',
    fontSize: 17,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.3,
    color: Tone.primary,
  );

  static const TextStyle body = TextStyle(
    fontFamily: 'Geist',
    fontSize: 14,
    fontWeight: FontWeight.w500,
    letterSpacing: -0.1,
    color: Tone.secondary,
  );

  static const TextStyle mono = TextStyle(
    fontFamily: 'GeistMono',
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: Tone.tertiary,
    fontFeatures: [FontFeature.tabularFigures()],
  );
}

/// Whether the platform has asked for less motion.
bool reduceMotion(BuildContext context) =>
    MediaQuery.maybeDisableAnimationsOf(context) ?? false;

/// [duration], or nothing at all under Reduce Motion.
Duration motion(BuildContext context, Duration duration) =>
    reduceMotion(context) ? Duration.zero : duration;

/// The spring-ish ease every non-glass transition in the app uses.
const Curve settle = Cubic(0.2, 0.9, 0.25, 1.05);

/// Grows and lifts [child] into place [delay] after it first builds.
///
/// Used once per element on launch and on every scene change, so the
/// screen assembles itself rather than appearing.
///
/// Glass cannot be faded with [Opacity] — the refraction is drawn by the
/// layer's backdrop pass, not by the widget, so an opacity only fades the
/// label on top. What a transform does reach is the shape: `Glass` reads its
/// paint transform every frame, so scaling it up from [scale] is the glass
/// itself materialising, and the content fades in on top of it.
class Arrive extends StatefulWidget {
  const Arrive({
    required this.child,
    this.delay = Duration.zero,
    this.offset = 16,
    this.scale = 0.9,
    super.key,
  });

  final Widget child;
  final Duration delay;
  final double offset;
  final double scale;

  @override
  State<Arrive> createState() => _ArriveState();
}

class _ArriveState extends State<Arrive> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 620),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_controller.status != AnimationStatus.dismissed) {
      return;
    }
    if (reduceMotion(context)) {
      _controller.value = 1;
      return;
    }
    _start = Timer(widget.delay, _controller.forward);
  }

  Timer? _start;

  @override
  void dispose() {
    _start?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      child: widget.child,
      builder: (context, child) {
        final t = settle.transform(_controller.value);
        return Opacity(
          opacity: Curves.easeOut.transform(_controller.value),
          child: Transform.translate(
            offset: Offset(0, (1 - t) * widget.offset),
            child: Transform.scale(
              scale: widget.scale + (1 - widget.scale) * t,
              child: child,
            ),
          ),
        );
      },
    );
  }
}
