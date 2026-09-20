import 'package:flutter/material.dart' show showLicensePage;
import 'package:flutter/widgets.dart';
import 'package:glass_forge/glass_forge.dart';
import 'package:glass_forge_example/src/chrome.dart';
import 'package:glass_forge_example/src/scene.dart';
import 'package:glass_forge_example/src/theme.dart';

/// The design system, and the engine that decides how much of it renders.
///
/// Three roles are on screen at once here, and each one resolves its own
/// material from the same tokens: a **card** in the content layer, two
/// **controls**, and the **sheet** holding the tier picker. The **navigation
/// bar** at the bottom of the screen is the fourth. Every one of them is a
/// different size, and size is what decides how much adaptation a role gets —
/// the two 44-point controls are thin enough to flip their whole scheme
/// against the backdrop, while the card is not and can only thicken its tint.
///
/// The **scrim** is the fifth role and the one that cannot share a screen, so
/// it takes the screen: raising it removes every other surface first.
class SystemScene extends StatefulWidget {
  const SystemScene({
    required this.info,
    required this.requested,
    required this.onDim,
    super.key,
  });

  final SceneInfo info;
  final ValueNotifier<GlassTier?> requested;
  final VoidCallback onDim;

  @override
  State<SystemScene> createState() => _SystemSceneState();
}

class _SystemSceneState extends State<SystemScene> {
  /// The rungs worth putting in front of someone.
  ///
  /// `balanced` is left out because it differs from `full` only by
  /// dispersion, which is three shader taps and almost nothing to look at;
  /// `off` is left out because it is not a performance rung at all, but the
  /// honest answer on a backend where the shader cannot run.
  static const _choices = <GlassTier?>[
    null,
    GlassTier.full,
    GlassTier.reduced,
    GlassTier.flat,
  ];

  @override
  Widget build(BuildContext context) {
    final resolved = GlassTierScope.of(context);
    final requested = widget.requested.value;

    return SceneShell(
      backdrop: widget.info.panelBackdrop,
      specimen: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _TierCard(resolved: resolved, backdrop: widget.info.panelBackdrop),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _ControlButton(
                  label: 'Dim the screen',
                  backdrop: widget.info.panelBackdrop,
                  onTap: widget.onDim,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _ControlButton(
                  label: 'Licences',
                  backdrop: widget.info.panelBackdrop,
                  onTap: () => showLicensePage(
                    context: context,
                    applicationName: 'glass_forge',
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
      controls: SegmentedControl<GlassTier?>(
        options: _choices,
        selected: _choices.contains(requested) ? requested : null,
        onChanged: (tier) => setState(() => widget.requested.value = tier),
        labelOf: (tier) => tier == null ? 'Auto' : _capitalise(tier.name),
      ),
      code: requested == null
          ? 'GlassTierScope(requested: null)'
          : 'GlassTierScope(requested: GlassTier.${requested.name})',
    );
  }
}

String _capitalise(String value) => value[0].toUpperCase() + value.substring(1);

/// What the engine decided, and what it decided it from.
///
/// `ResolvedTier.describe()` reports the whole derivation, not just the
/// verdict: the ceiling each of the four signals imposed, and how many rungs
/// the frame watchdog asked for on top. A tier that turns out lower than
/// expected is then a question with an answer rather than a mystery.
class _TierCard extends StatelessWidget {
  const _TierCard({required this.resolved, required this.backdrop});

  final ResolvedTier resolved;
  final Color backdrop;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // The same call `GlassSurface` makes internally, run here for one
        // extra reason: `labelContrast` is the contrast this role actually
        // achieves over this backdrop, and a promise nobody can read is not
        // a promise.
        final style = GlassTheme.surfaceOf(
          context,
          GlassSurfaceRole.card,
          size: Size(constraints.maxWidth, 190),
          backdrop: backdrop,
        );
        final contrast = style.labelContrast;

        return GlassSurface.card(
          backdrop: backdrop,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Fact('tier', resolved.tier.name),
                _Fact('geometry', resolved.geometry.name),
                _Fact('domes', resolved.dome ? 'kept' : 'flat'),
                _Fact(
                  'label contrast',
                  contrast == null
                      ? 'unmeasured'
                      : '${contrast.toStringAsFixed(1)}:1',
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: ColoredBox(
                    color: context.inkHairline,
                    child: const SizedBox(height: 1, width: double.infinity),
                  ),
                ),
                Text(
                  resolved.describe(),
                  style: context.mono.copyWith(
                    color: context.inkTertiary,
                    height: 17 / 12,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Text(
            label,
            style: context.label.copyWith(color: context.inkSecondary),
          ),
          const Spacer(),
          Text(value, style: context.mono),
        ],
      ),
    );
  }
}

/// A button, as the design system understands one.
///
/// The role that is reliably small, and therefore the one that reliably
/// flips: at 44 points it is thinner than the tallest bar iOS ships, so one
/// luminance reading describes everything behind it and choosing a whole
/// scheme from that reading is safe.
class _ControlButton extends StatelessWidget {
  const _ControlButton({
    required this.label,
    required this.backdrop,
    required this.onTap,
  });

  final String label;
  final Color backdrop;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: InteractiveGlass(
        onTap: onTap,
        child: GlassSurface.control(
          backdrop: backdrop,
          child: Center(
            child: Text(label, style: context.label),
          ),
        ),
      ),
    );
  }
}

/// The dimming layer, and the only surface on screen while it is up.
///
/// A scrim is the one role that does not adapt at all. Its whole job is to be
/// the *same* amount of separation over everything, and one that thinned out
/// over an easy backdrop would let the content behind compete with the thing
/// it exists to separate — exactly where that is most distracting.
class ScrimOverlay extends StatelessWidget {
  const ScrimOverlay({required this.onDismiss, super.key});

  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onDismiss,
      child: GlassSurface.scrim(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 36),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('scrim', style: context.display),
              const SizedBox(height: 10),
              Text(
                'Blurred as hard as the ladder goes, square, flush, and the '
                'only role that never adapts.',
                textAlign: TextAlign.center,
                style: context.body.copyWith(color: context.inkSecondary),
              ),
              const SizedBox(height: 24),
              Text(
                'The tab bar and the panel are gone rather than dimmed. '
                'Glass cannot sample glass, so a surface that covers the '
                'screen has to be the only one on it.',
                textAlign: TextAlign.center,
                style: context.caption.copyWith(color: context.inkTertiary),
              ),
              const SizedBox(height: 28),
              Text(
                'Tap to dismiss',
                style: context.mono.copyWith(color: context.inkTertiary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
