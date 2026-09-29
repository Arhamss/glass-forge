import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart' show MaterialPageRoute, Scaffold;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:glass_forge/glass_forge.dart';
import 'package:glass_forge_example/src/backdrop.dart';
import 'package:glass_forge_example/src/glyphs.dart';
import 'package:glass_forge_example/src/playground.dart';
import 'package:glass_forge_example/src/presets.dart';
import 'package:glass_forge_example/src/scenes/kit.dart';
import 'package:glass_forge_example/src/scenes/lens.dart';
import 'package:glass_forge_example/src/scenes/liquid.dart';
import 'package:glass_forge_example/src/settings.dart';
import 'package:glass_forge_example/src/tuner.dart';
import 'package:glass_forge_example/src/ui.dart';

/// No colour on the glyphs: the bar tints them through its `IconTheme`,
/// bright for the selected tab and dimmed for the rest.
const List<GlassTab> _tabs = [
  GlassTab(icon: Glyph(Glyphs.lens, size: 22), label: 'Lens'),
  GlassTab(icon: Glyph(Glyphs.liquid, size: 22), label: 'Liquid'),
  GlassTab(icon: Glyph(Glyphs.kit, size: 22), label: 'Kit'),
];

/// How wide the bar is: a comfortable thumb's width per tab, about 96
/// points each, not the whole screen.
const double _barWidth = 288;

const List<String> _captions = [
  'Pick it up and move it. Tap to change shape.',
  'Drops that melt together. Pull the big one.',
  'The same glass, doing a day job.',
];

/// The one screen.
///
/// **One `GlassLayer` for everything.** It captures the photograph once and
/// every `Glass` below registers into it. The layer's material is the one
/// the tuner edits, so every scene — and the photo button, and the toast —
/// changes together. Only the chrome — the tab bar, the sheet, the photo
/// button and the toast — wears materials of its own, because it has to
/// stay readable whatever the tuner is set to.
class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> with TickerProviderStateMixin {
  static const double _peek = 136;
  static const double _open = 0.58;

  late final GlassDetentSheetController _sheet = GlassDetentSheetController(
    vsync: this,
  );

  // Held for the sheet's lifetime: a presence animation drives one backdrop
  // pass by identity, so a fresh one per build would be a fresh pass.
  late final Animation<double> _barPresence = _sheet.presenceUnder(
    start: _peek,
    end: _peek + 70,
  );

  /// The tab that is selected, and the scene actually on screen. They
  /// differ for the moment the old scene takes to shrink away.
  int _scene = 0;
  int _shown = 0;

  late final AnimationController _swap = AnimationController(
    vsync: this,
    value: 1,
    duration: const Duration(milliseconds: 420),
    reverseDuration: const Duration(milliseconds: 180),
  );

  late final Animation<double> _swapScale = Tween<double>(begin: 0.05, end: 1)
      .animate(
        CurvedAnimation(
          parent: _swap,
          curve: Curves.easeOutBack,
          reverseCurve: Curves.easeInCubic,
        ),
      );

  Future<void> _select(int index) async {
    setState(() => _scene = index);
    if (reduceMotion(context)) {
      setState(() => _shown = index);
      return;
    }
    await _swap.reverse();
    if (!mounted) {
      return;
    }
    // Whatever is selected *now*: a second tap during the shrink wins.
    setState(() => _shown = _scene);
    await _swap.forward();
  }

  String? _toast;
  Timer? _toastTimer;

  void _showToast(String message) {
    unawaited(HapticFeedback.mediumImpact());
    _toastTimer?.cancel();
    setState(() => _toast = message);
    _toastTimer = Timer(const Duration(milliseconds: 1800), () {
      if (mounted) {
        setState(() => _toast = null);
      }
    });
  }

  @override
  void dispose() {
    _toastTimer?.cancel();
    _swap.dispose();
    _sheet.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final playground = PlaygroundScope.of(context);
    final padding = MediaQuery.paddingOf(context);
    final barBottom = padding.bottom + 8;
    final sheetGap = barBottom + GlassTabBar.height + 10;
    final headerHeight = padding.top + 96;

    final scene = switch (_shown) {
      0 => const LensScene(),
      1 => const LiquidScene(),
      _ => const KitScene(),
    };

    final content = Stack(
      children: [
        // The scene lives between the header and whatever is highest at the
        // bottom — the tab bar, or the sheet once it rises past it — and
        // shrinks to fit as that space closes, so the glass being tuned is
        // never hidden under the tuner.
        AnimatedBuilder(
          animation: _sheet,
          builder: (context, child) {
            final bottom = math.max(
              barBottom + GlassTabBar.height,
              _sheetTop(padding.bottom, sheetGap),
            );
            return Positioned(
              top: headerHeight,
              bottom: bottom + 8,
              left: 0,
              right: 0,
              child: child!,
            );
          },
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Padding(
                padding: const EdgeInsets.all(20),
                // Out, then in — never both at once. Two scenes on screen
                // together share a pass, and shapes close together draw as
                // one cluster of at most eight: the Kit's buttons and the
                // Liquid's drops overlapping mid-swap would leave some of
                // them undrawn for the length of the transition. Scale, not
                // fade: a fade reaches only the labels, while a transform
                // reaches the glass itself.
                child: ScaleTransition(
                  scale: _swapScale,
                  child: FadeTransition(
                    opacity: _swap,
                    child: KeyedSubtree(key: ValueKey(_shown), child: scene),
                  ),
                ),
              ),
            ),
          ),
        ),
        Positioned(
          top: padding.top + 14,
          left: 24,
          right: 20,
          // Steps aside for the toast, which takes its place rather than
          // landing on top of its text.
          child: AnimatedOpacity(
            opacity: _toast == null ? 1 : 0,
            duration: motion(context, const Duration(milliseconds: 220)),
            curve: Curves.easeOut,
            child: _Header(caption: _captions[_scene]),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: Center(
            child: SizedBox(
              // The bar keeps its own margin clear of the screen's edges.
              width: _barWidth + GlassTabBar.margin.horizontal,
              // It builds the safe area in, keeping at least 8 below it;
              // above a home indicator, 8 more lifts it clear of the line.
              child: Padding(
                padding: EdgeInsets.only(bottom: padding.bottom > 0 ? 8 : 0),
                // Fades out before the rising sheet reaches it: two
                // backdrop passes over the same pixels is the one thing
                // glass must not do (flutter#187820). The bar reads its
                // presence from here and hands it to its lens as well.
                child: GlassPresence(
                  presence: _barPresence,
                  child: Arrive(
                    delay: const Duration(milliseconds: 200),
                    child: GlassTabBar(
                      material: chromeMaterial,
                      tabs: _tabs,
                      currentIndex: _scene,
                      onTap: (i) {
                        if (i != _scene) {
                          unawaited(_select(i));
                        }
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        GlassDetentSheet(
          controller: _sheet,
          detents: const [
            GlassDetent.height(_peek),
            GlassDetent.fraction(_open),
          ],
          bottomGap: sheetGap,
          material: sheetMaterial,
          semanticLabel: 'Material tuner',
          child: Tuner(onCopied: () => _showToast('Copied as Dart')),
        ),
        Positioned(
          top: padding.top + 8,
          left: 0,
          right: 0,
          child: Center(child: _Toast(message: _toast)),
        ),
      ],
    );

    return Scaffold(
      backgroundColor: Tone.ground,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Backdrop(photo: playground.photo),
          // Presets morph; sliders track the finger with no lag.
          TweenAnimationBuilder<GlassMaterial>(
            tween: GlassMaterialTween(end: playground.material),
            duration: playground.morph
                ? motion(context, const Duration(milliseconds: 700))
                : Duration.zero,
            curve: Curves.easeInOutCubic,
            child: content,
            builder: (context, material, child) =>
                GlassLayer(material: material, child: child!),
          ),
        ],
      ),
    );
  }

  /// Where the sheet's top edge is, measured up from the screen's bottom.
  ///
  /// The sheet's height plus the insets below it, which close to nothing
  /// as it rises from its lowest detent to its highest.
  double _sheetTop(double safeBottom, double gap) {
    final lowest = _sheet.lowest;
    final span = _sheet.top - lowest;
    final progress = span <= 0
        ? 1.0
        : ((_sheet.value - lowest) / span).clamp(0.0, 1.0);
    return _sheet.value + (gap + safeBottom) * (1 - progress);
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.caption});

  final String caption;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Arrive(
                child: Text('Glass Forge', style: Font.display),
              ),
              const SizedBox(height: 6),
              AnimatedSwitcher(
                duration: motion(context, const Duration(milliseconds: 300)),
                transitionBuilder: (child, animation) => FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween(
                      begin: const Offset(0, 0.4),
                      end: Offset.zero,
                    ).animate(animation),
                    child: child,
                  ),
                ),
                layoutBuilder: (current, previous) => Stack(
                  alignment: Alignment.topLeft,
                  children: [...previous, ?current],
                ),
                child: Text(caption, key: ValueKey(caption), style: Font.body),
              ),
            ],
          ),
        ),
        Arrive(
          delay: const Duration(milliseconds: 90),
          scale: 0.3,
          child: GlassButton.icon(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (context) => const SettingsScreen(),
              ),
            ),
            icon: const Glyph(Glyphs.settings, size: 22, color: Tone.primary),
            semanticLabel: 'Settings',
          ),
        ),
        const SizedBox(width: 10),
        const Arrive(
          delay: Duration(milliseconds: 120),
          scale: 0.3,
          child: _PhotoButton(),
        ),
      ],
    );
  }
}

/// Swaps the photograph.
class _PhotoButton extends StatelessWidget {
  const _PhotoButton();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Next photo',
      child: InteractiveGlass(
        pressScale: 0.88,
        onTap: () {
          unawaited(HapticFeedback.lightImpact());
          PlaygroundScope.read(context).nextPhoto();
        },
        child: const SizedBox.square(
          dimension: 50,
          // Chrome, so the chrome's material — which also keeps it out of
          // the scene's pass, whose Kit buttons already fill most of the
          // eight shapes a cluster carries.
          child: Glass(
            material: chromeMaterial,
            shape: GlassOval(),
            child: Glyph(
              Glyphs.photo,
              size: 22,
              color: Tone.primary,
            ),
          ),
        ),
      ),
    );
  }
}

/// A glass pill that grows in at the top of the screen and shrinks away.
class _Toast extends StatelessWidget {
  const _Toast({required this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    final text = message;
    return AnimatedSwitcher(
      duration: motion(context, const Duration(milliseconds: 420)),
      switchInCurve: Curves.easeOutBack,
      switchOutCurve: Curves.easeIn,
      transitionBuilder: (child, animation) => ScaleTransition(
        scale: Tween<double>(begin: 0.05, end: 1).animate(animation),
        child: child,
      ),
      child: text == null
          ? const SizedBox.shrink()
          : Glass(
              key: ValueKey(text),
              // Chrome, not the tuned material: a toast has to read over
              // the photo whatever the tuner is set to.
              material: chromeMaterial,
              shape: const GlassRoundedRectangle(
                radius: BorderRadius.all(Radius.circular(22)),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 12,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Glyph(
                      Glyphs.done,
                      size: 18,
                      color: Tone.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(text, style: Font.body.copyWith(color: Tone.primary)),
                  ],
                ),
              ),
            ),
    );
  }
}
