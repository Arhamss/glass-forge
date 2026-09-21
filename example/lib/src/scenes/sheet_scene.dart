import 'package:flutter/widgets.dart';
import 'package:glass_forge/glass_forge.dart';
import 'package:glass_forge_example/src/chrome.dart';
import 'package:glass_forge_example/src/scene.dart';
import 'package:glass_forge_example/src/theme.dart';

/// Apple Maps' sheet, and the reason `GlassPresence` exists.
///
/// Persistent rather than presented: the sheet never leaves the screen, only
/// the height it rests at does, between the three detents the spec quotes —
/// a tenth of the frame, half, and full. Drag it and the floating gap
/// tightens continuously under the finger while the corners grow toward the
/// frame's own, so only the *snap* to a detent is a discrete step.
///
/// The tab row behind it is the actual demonstration. Nothing in
/// `GlassDetentSheet` wires a covered surface's presence for a caller —
/// `GlassScaffold` will, once it exists — so this scene does by hand what
/// that widget is going to automate: drive the tabs' `GlassPresence` from
/// [GlassDetentSheetController.presenceUnder], keyed to the same height that
/// drives the morph, so the tabs are gone before the sheet's own glass ever
/// reaches them. Two backdrop passes over one region is flutter#187820, and
/// a handoff rather than a cross-fade is how this package avoids it.
///
/// Which takes two numbers agreeing, not one: the sheet's floating gap has to
/// clear the row in the first place, or the two are already stacked at Peek
/// and no ramp can help. See [_SheetSceneState._bottomGap].
class SheetScene extends StatefulWidget {
  const SheetScene({required this.info, super.key});

  final SceneInfo info;

  @override
  State<SheetScene> createState() => _SheetSceneState();
}

class _SheetSceneState extends State<SheetScene>
    with SingleTickerProviderStateMixin {
  late final _controller = GlassDetentSheetController(vsync: this);

  static const _detents = <GlassDetent>[
    GlassDetent.fraction(0.1),
    GlassDetent.fraction(0.5),
    GlassDetent.fraction(1),
  ];

  static const _detentNames = ['Peek', 'Half', 'Full'];
  static const _tabNames = ['Explore', 'Saved', 'Me'];

  /// How tall the tab row is.
  static const _barHeight = 52.0;

  /// How far the floating sheet is inset from the frame's edges.
  ///
  /// Larger than [_barHeight], and that is the whole design: the sheet's
  /// bottom edge floats `gap * (1 - progress)` above the frame's bottom while
  /// the tab row owns the bottom [_barHeight] of it, so a gap no bigger than
  /// the row puts the two on top of each other at Peek — before any drag has
  /// started, with no presence ramp able to rescue it. The spec's "floating
  /// with a visible gap at the low detent" presumes the gap clears whatever
  /// it is floating over, and this is that number said out loud.
  static const _bottomGap = 64.0;

  /// The sheet's `progress` at which the shrinking gap sets its bottom edge
  /// down exactly on the tab row's top edge: `gap * (1 - progress)` reaching
  /// [_barHeight]. The tabs must be gone by here.
  static const double _contact = 1 - _barHeight / _bottomGap;

  /// Where the ramp starts: eight points of gap earlier, so the tabs reach
  /// presence 0 with daylight still between the two surfaces rather than on
  /// the same frame they meet.
  static const double _clearance = 1 - (_barHeight + 8) / _bottomGap;

  /// [_detents]' lowest fraction, and the span the sheet's `progress` is
  /// measured across — the two numbers the ramp above is stated in.
  static const double _lowestFraction = 0.1;
  static const double _spanFraction = 1.0 - _lowestFraction;

  int _detent = 0;
  int _tab = 0;

  /// The available height [_tabsPresence] was last built against.
  double? _rampFor;
  late Animation<double> _tabsPresence;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Builds the tab row's presence ramp against [available] — which the
  /// caller must already have reduced by the top safe-area inset, exactly
  /// as `GlassDetentSheet` itself does before resolving its detents
  /// (`constraints.maxHeight - MediaQuery.paddingOf(context).top`). Passing
  /// the raw `LayoutBuilder` height instead leaves this ramp's `end`
  /// strictly above the sheet's real top-detent height on any device with a
  /// top inset — a status bar, a Dynamic Island — so presence would still
  /// read nonzero once the sheet is fully flush: both surfaces rendering at
  /// once, which is exactly the flutter#187820 artifact this scene exists
  /// to disprove.
  ///
  /// Built once per [available] rather than on every build: the ramp is an
  /// `Animation`, and `GlassPresence` holds it by identity, so a fresh one
  /// every frame would rebuild the tab row's backdrop pass every frame
  /// instead of moving a value through the one pass already warm.
  ///
  /// The ramp is stated in the heights at which the *gap* closes onto the tab
  /// row — [_clearance] to [_contact] — not in some fraction of the way to
  /// the top detent. It has to be: the sheet's glass arrives at the row long
  /// before the sheet is anywhere near full, because the gap that was holding
  /// it clear shrinks with `progress`. A ramp that waited for the sheet to be
  /// three-quarters of the frame tall would leave both surfaces rendering
  /// over the same pixels from Peek onward, which is the flutter#187820
  /// artifact this scene exists to disprove. The package pins the same
  /// derivation in `test/src/chrome/sheet_presence_handoff_test.dart`.
  void _syncPresenceRamp(double available) {
    if (_rampFor == available) {
      return;
    }
    _rampFor = available;
    final lowest = available * _lowestFraction;
    final span = available * _spanFraction;
    _tabsPresence = _controller.presenceUnder(
      start: lowest + _clearance * span,
      end: lowest + _contact * span,
    );
  }

  @override
  Widget build(BuildContext context) {
    return SceneShell(
      backdrop: widget.info.panelBackdrop,
      specimen: SizedBox.expand(
        child: LayoutBuilder(
          builder: (context, constraints) {
            // The same subtraction `GlassDetentSheet` makes internally
            // before resolving its own detents — see `_syncPresenceRamp`.
            final topInset = MediaQuery.paddingOf(context).top;
            _syncPresenceRamp(constraints.maxHeight - topInset);
            return Stack(
              fit: StackFit.expand,
              children: [
                // The page's own chrome, behind the sheet — exactly what a
                // `GlassScaffold` bottom bar would be. It has nowhere else
                // to be but here: the sheet floats over the same region a
                // real bottom bar would occupy, which is the whole reason a
                // handoff is needed at all.
                Align(
                  alignment: Alignment.bottomCenter,
                  child: AnimatedBuilder(
                    animation: _tabsPresence,
                    builder: (context, child) {
                      // `GlassPresence` ramps the *glass* — refraction,
                      // frost, tint — and says so: it is explicitly not an
                      // `Opacity`, because a half-faded refraction is still
                      // a full backdrop read. What it does not touch is the
                      // bar's own content, and a row of labels left at full
                      // strength over a sheet that has covered them reads as
                      // a rendering failure even though the handoff beneath
                      // it worked perfectly. So the labels fade on the same
                      // animation, and at zero the bar leaves the tree
                      // entirely rather than lingering as a shadow with
                      // nothing inside it.
                      if (_tabsPresence.value <= 0) {
                        return const SizedBox.shrink();
                      }
                      return GlassPresence(
                        presence: _tabsPresence,
                        child: SizedBox(height: _barHeight, child: child),
                      );
                    },
                    child: GlassSurface.navigationBar(
                      backdrop: widget.info.barBackdrop,
                      child: Padding(
                        padding: const EdgeInsets.all(6),
                        child: FadeTransition(
                          opacity: _tabsPresence,
                          child: SegmentedControl<int>(
                            options: const [0, 1, 2],
                            selected: _tab,
                            onChanged: (value) => setState(() => _tab = value),
                            labelOf: (value) => _tabNames[value],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                GlassDetentSheet(
                  detents: _detents,
                  controller: _controller,
                  // Sides stay at the widget's own default. Only the
                  // bottom inset has a job here — clearing the tab row —
                  // and until `bottomGap` existed, buying that clearance
                  // through the shared `gap` cost this sheet 104 points of
                  // width to solve a problem the sides never had.
                  bottomGap: _bottomGap,
                  backdrop: widget.info.panelBackdrop,
                  semanticLabel: 'Nearby places',
                  onDetentChanged: (index) => setState(() => _detent = index),
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    itemCount: _places.length,
                    separatorBuilder: (context, _) =>
                        Container(height: 1, color: context.inkHairline),
                    itemBuilder: (context, index) => _PlaceRow(_places[index]),
                  ),
                ),
              ],
            );
          },
        ),
      ),
      controls: SegmentedControl<int>(
        options: const [0, 1, 2],
        selected: _detent,
        onChanged: (index) => _controller.animateToDetent(index),
        labelOf: (index) => _detentNames[index],
      ),
      code: 'controller.animateToDetent($_detent)',
    );
  }
}

/// One row in the sheet's list — a place and how far it is.
typedef _Place = ({String name, String distance});

const _places = <_Place>[
  (name: 'Harbor steps', distance: '80 m'),
  (name: 'Old quarter', distance: '210 m'),
  (name: 'Clifftop path', distance: '350 m'),
  (name: 'Ferry dock', distance: '0.6 km'),
  (name: 'Lighthouse point', distance: '0.9 km'),
  (name: 'Boat rental', distance: '1.1 km'),
  (name: 'Piazza del Mare', distance: '1.3 km'),
  (name: 'Market street', distance: '1.4 km'),
  (name: 'Bell tower', distance: '1.6 km'),
  (name: 'Tide pools', distance: '1.9 km'),
  (name: 'Trailhead', distance: '2.2 km'),
  (name: 'Belvedere', distance: '2.6 km'),
];

class _PlaceRow extends StatelessWidget {
  const _PlaceRow(this.place);

  final _Place place;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
      child: Row(
        children: [
          Expanded(child: Text(place.name, style: context.label)),
          Text(
            place.distance,
            style: context.mono.copyWith(color: context.inkTertiary),
          ),
        ],
      ),
    );
  }
}
