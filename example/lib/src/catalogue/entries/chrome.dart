import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:glass_forge/glass_forge.dart';
import 'package:glass_forge_example/src/backdrop_info.dart';
import 'package:glass_forge_example/src/catalogue/catalogue_entry.dart';
import 'package:glass_forge_example/src/theme.dart';

/// The Chrome group: the detent sheet, the three ways of saying where it
/// rests, the controller that drives it and the physics that lets one
/// gesture cross from the sheet into the list inside it.
///
/// Four entries. Three of them put a working sheet on screen, which takes a
/// screen — so they share [_Frame], a fixed box with the window's own insets
/// taken off it. A sheet measures itself against the height it is given and
/// subtracts `MediaQuery.paddingOf(context).top` from it, so a specimen that
/// inherited the real status-bar inset would be a different sheet on every
/// device the catalogue runs on, and the numbers printed in its snippet
/// would be true of none of them.
///
/// Which a reader has to be told, because the frame is the difference
/// between what those numbers mean here and what they would mean in an app.
/// Nothing in a `///` reaches the app — a [CatalogueEntry] has no prose
/// field beyond `purpose` — so the three snippets open with [_frameNote].
final List<CatalogueEntry> chromeEntries = <CatalogueEntry>[
  _glassDetentSheet,
  _glassDetent,
  _glassDetentSheetController,
  _glassSheetScrollPhysics,
];

double _asDouble(Knob<Object?> knob) => knob.value! as double;

// ---------------------------------------------------------------------------
// The miniature screen every sheet specimen rests in
// ---------------------------------------------------------------------------

/// How wide the miniature screen is.
const double _frameWidth = 208;

/// How tall it is — the height every fractional detent below is a fraction
/// of, and therefore the number that makes the snippets' arithmetic real.
const double _frameHeight = 248;

/// How tall the tab row behind the sheet is.
const double _barHeight = 36;

/// How far the floating sheet is inset from the frame's bottom edge in the
/// `GlassDetentSheet` entry.
///
/// Larger than [_barHeight], and that is the whole design: the sheet's
/// bottom edge floats `bottomGap * (1 - progress)` above the frame's bottom
/// while the tab row owns the bottom [_barHeight] of it, so a gap no bigger
/// than the row puts the two on top of each other at the lowest detent —
/// before any drag has started, with no presence ramp able to rescue it.
const double _bottomGap = 48;

/// How far a floating sheet is inset from the frame's side edges.
const double _sideGap = 10;

/// The corner radius while floating.
const double _floatingRadius = 18;

/// The corner radius when flush.
///
/// Nominally the display's own radius, which is what
/// `GlassDetentSheet.flushRadius` means and why its default is 55 — the
/// number a modern iPhone uses. This screen is 208 points wide, so 55 would
/// round its corners nearly to circles; the entry says what its own display
/// is rather than accepting a guess made for a different one.
const double _flushRadius = 24;

/// The sheet's `progress` at which the shrinking bottom gap sets its bottom
/// edge down exactly on the tab row's top edge: `bottomGap * (1 - progress)`
/// reaching [_barHeight]. The tabs must be gone by here.
const double _contact = 1 - _barHeight / _bottomGap;

/// Where the ramp starts: six points of gap earlier, so the tabs reach
/// presence 0 with daylight still between the two surfaces rather than on
/// the same frame they meet.
const double _clearance = 1 - (_barHeight + 6) / _bottomGap;

/// The photograph the whole catalogue sits over, and the two colours
/// measured off it.
///
/// `GlassSurface` adapts a surface to keep its labels readable, and nothing
/// in the package samples the backdrop for you — so the tab row is handed
/// the colour measured under a thin bar and the sheet the one measured under
/// a panel. Two samples rather than one, for the reason
/// [BackdropInfo.barBackdrop] gives: a bar and a panel cover different bands
/// of the same picture.
final BackdropInfo _backdrop = backdropFor(catalogueBackdropPhoto);

/// The fixed box a sheet specimen rests in, with the window's insets off it.
///
/// Not a wrapper around anything this package exports — there is no glass
/// here, and every `Glass`, `GlassSurface` and `GlassDetentSheet` below is
/// the reader's own. This is the screen they sit on, and it exists only so
/// that the height a fraction detent resolves against is [_frameHeight] on
/// every device rather than [_frameHeight] minus whatever the status bar
/// happened to cost.
class _Frame extends StatelessWidget {
  const _Frame({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _frameWidth,
      height: _frameHeight,
      child: MediaQuery.removePadding(
        context: context,
        removeTop: true,
        removeBottom: true,
        child: child,
      ),
    );
  }
}

/// A colour as the Dart literal a snippet would quote.
///
/// Derived from the value rather than typed beside it, exactly as the
/// Adaptation and Design system groups derive theirs: every colour in this
/// file comes out of [backdrops], and a hand-written hex is one edit away
/// from describing a photograph nobody is looking at.
String _hex(Color color) =>
    '0x${color.toARGB32().toRadixString(16).toUpperCase().padLeft(8, '0')}';

/// What `GlassDetentSheet.flushRadius` is when a caller leaves it alone.
///
/// Read off a sheet rather than typed as 55: [_frameNote] tells the reader
/// there is a default and what it is for, and a number typed into that
/// sentence would go on saying 55 after the package moved.
final double _packageFlushRadius = GlassDetentSheet(
  detents: const <GlassDetent>[
    GlassDetent.fraction(0.5),
    GlassDetent.fraction(1),
  ],
  child: const SizedBox.shrink(),
).flushRadius;

/// The line every snippet built around a [_Frame] opens with.
///
/// The frame is the one thing on these three pages that is not the reader's
/// own code, and it changes what every number below it means: a detent
/// fraction here is a fraction of [_frameHeight], and a gap here is a gap
/// in a box that size. Left in a doc comment, a reader would copy the
/// arithmetic and apply it to a screen it was never done against.
///
/// The corner radii are the sharper half of the same problem. Every sheet
/// below states its own [_flushRadius] because the package's default is a
/// display's radius and this frame is not a display — so the note says the
/// default is there and what it is for, rather than leaving a reader to
/// wonder why the snippet names a number their own sheet would not need.
final String _frameNote =
    '// This specimen stands in a ${_frameHeight.toStringAsFixed(0)}-point '
    'tall frame with the\n'
    '// window insets already off it, so every fraction, gap and\n'
    '// radius below is sized to that rather than to a screen. A\n'
    '// real sheet resolves its detents against the height it is\n'
    '// given, less MediaQuery.paddingOf(context).top, and leaves\n'
    '// flushRadius at its default '
    '${_packageFlushRadius.toStringAsFixed(0)} — the corner radius of\n'
    '// a modern display, which this frame is not.\n';

// ---------------------------------------------------------------------------
// What the sheets carry
// ---------------------------------------------------------------------------

/// One row in a sheet's list — a place and how far it is.
typedef _Place = ({String name, String distance});

const List<_Place> _places = <_Place>[
  (name: 'Harbor steps', distance: '80 m'),
  (name: 'Old quarter', distance: '210 m'),
  (name: 'Clifftop path', distance: '350 m'),
  (name: 'Ferry dock', distance: '0.6 km'),
  (name: 'Lighthouse point', distance: '0.9 km'),
  (name: 'Boat rental', distance: '1.1 km'),
];

/// The list every sheet here carries.
///
/// [physics] is left null by everything except the `GlassSheetScrollPhysics`
/// entry, which is the whole of that entry's knob — a scrollable inside a
/// sheet is meant to leave it null and take
/// [GlassSheetScrollPhysics] from the sheet's own `ScrollConfiguration`.
Widget _placesList({ScrollPhysics? physics}) {
  return ListView.separated(
    physics: physics,
    padding: EdgeInsets.zero,
    itemCount: _places.length,
    separatorBuilder: (context, _) =>
        Container(height: 1, color: context.inkHairline),
    itemBuilder: (context, index) => _PlaceRow(_places[index]),
  );
}

class _PlaceRow extends StatelessWidget {
  const _PlaceRow(this.place);

  final _Place place;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              place.name,
              style: context.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            place.distance,
            style: context.mono.copyWith(color: context.inkTertiary),
          ),
        ],
      ),
    );
  }
}

/// The tab row's own content.
///
/// Every colour comes off the enclosing surface's label colour through
/// [SurfaceInk]. A `GlassSurface.navigationBar` is thin enough to flip its
/// whole scheme against a bright backdrop, and a row of hard-coded white
/// labels would then be white on white.
class _TabLabels extends StatelessWidget {
  const _TabLabels();

  static const List<String> _names = <String>['Explore', 'Saved', 'Me'];

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        for (var i = 0; i < _names.length; i++)
          Text(
            _names[i],
            style: context.caption.copyWith(
              color: i == 0 ? context.ink : context.inkTertiary,
            ),
          ),
      ],
    );
  }
}

/// The glass bar the sheet hands off from, and the one thing in this file
/// that subscribes to the ramp itself.
///
/// [GlassPresence] alone would not need a subscriber — it hands the
/// animation down to the render objects, which repaint without anyone
/// rebuilding. Two things here do:
///
/// * **The labels fade with the glass.** `GlassPresence` ramps the *glass*
///   — refraction, frost, tint — and says so: it is explicitly not an
///   `Opacity`, because a half-faded refraction is still a full backdrop
///   read. A row of labels left at full strength under a sheet that has
///   covered them reads as a rendering failure even though the handoff
///   beneath it worked perfectly.
/// * **At zero the bar leaves the tree**, rather than lingering as a
///   surface with nothing inside it.
///
/// Its own listener rather than an `AnimatedBuilder`, because of *where*
/// the controller publishes from. `GlassDetentSheet` resolves its detents
/// inside its own `LayoutBuilder` and calls
/// `GlassDetentSheetController.setDetents` from there, which notifies — and
/// this bar is that sheet's sibling, not its descendant, so a synchronous
/// `setState` from inside that build is exactly the "called during build"
/// error. Deferring only that case to the end of the frame is the same
/// technique the Composition group's overlap demo uses for the paint-time
/// warning it captures. Every other publish — a drag, a spring tick —
/// arrives in a phase where rebuilding is legal and is taken immediately,
/// so nothing about the ramp lags a frame while it is moving.
class _TabRow extends StatefulWidget {
  const _TabRow({required this.presence});

  /// How present this bar should be, from
  /// [GlassDetentSheetController.presenceUnder].
  final Animation<double> presence;

  @override
  State<_TabRow> createState() => _TabRowState();
}

class _TabRowState extends State<_TabRow> {
  late double _value = widget.presence.value;

  @override
  void initState() {
    super.initState();
    widget.presence.addListener(_onPresenceChanged);
  }

  @override
  void didUpdateWidget(covariant _TabRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.presence, widget.presence)) {
      oldWidget.presence.removeListener(_onPresenceChanged);
      widget.presence.addListener(_onPresenceChanged);
      _value = widget.presence.value;
    }
  }

  @override
  void dispose() {
    widget.presence.removeListener(_onPresenceChanged);
    super.dispose();
  }

  void _onPresenceChanged() {
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      // Mid-frame: this is the build and layout pass, which is where the
      // sheet resolves its detents and publishes from. See the class doc.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() => _value = widget.presence.value);
        }
      });
      return;
    }
    setState(() => _value = widget.presence.value);
  }

  @override
  Widget build(BuildContext context) {
    if (_value <= 0) {
      return const SizedBox.shrink();
    }
    return GlassPresence(
      presence: widget.presence,
      child: SizedBox(
        height: _barHeight,
        child: GlassSurface.navigationBar(
          backdrop: _backdrop.barBackdrop,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            // Never outside 0 to 1: `presenceUnder` is a ramp between two
            // heights and clamps at both ends, which is also what lets
            // `Opacity`'s own assertion stand unguarded here.
            child: Opacity(opacity: _value, child: const _TabLabels()),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// GlassDetentSheet
// ---------------------------------------------------------------------------

/// The three rest heights, with the lowest one supplied by the knob.
List<GlassDetent> _detentsForLowest(double lowest) => <GlassDetent>[
  GlassDetent.fraction(lowest),
  const GlassDetent.fraction(0.62),
  const GlassDetent.fraction(1),
];

/// Apple Maps' sheet, and the reason `GlassPresence` exists.
///
/// Persistent rather than presented: the sheet never leaves the screen, only
/// the height it rests at does. Drag it and the floating gap tightens
/// continuously under the finger while the corners grow toward the frame's
/// own, so only the *snap* to a detent is a discrete step.
///
/// **The tab row behind it is the actual demonstration.** Nothing in
/// `GlassDetentSheet` wires a covered surface's presence for a caller —
/// `GlassScaffold` will, once it exists — so this specimen does by hand what
/// that widget is going to automate: it drives the tabs' [GlassPresence]
/// from [GlassDetentSheetController.presenceUnder], keyed to the same height
/// that drives the morph, so the tabs are gone before the sheet's own glass
/// ever reaches them. That handoff is the only thing keeping the tab row and
/// the sheet from both being glass over the same pixels, and two backdrop
/// passes over one region is flutter#187820 — the upper pass samples the
/// lower one's output and white-washes over time.
///
/// Which takes two numbers agreeing, not one: the sheet's floating gap has
/// to clear the row in the first place, or the two are already stacked at
/// the lowest detent and no ramp can help. See [_bottomGap].
class _DetentSheetDemo extends StatefulWidget {
  const _DetentSheetDemo({required this.lowestFraction});

  /// The fraction of the frame the sheet's lowest rest height is, and
  /// therefore what [GlassDetentSheetController.lowest] resolves to.
  final double lowestFraction;

  @override
  State<_DetentSheetDemo> createState() => _DetentSheetDemoState();
}

class _DetentSheetDemoState extends State<_DetentSheetDemo>
    with SingleTickerProviderStateMixin {
  late final GlassDetentSheetController _controller =
      GlassDetentSheetController(vsync: this);

  /// The available height, and the lowest fraction, [_tabsPresence] was
  /// last built against.
  double? _rampFor;
  double? _rampLowest;

  late Animation<double> _tabsPresence;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Builds the tab row's presence ramp against [available].
  ///
  /// Built once per pair of inputs rather than on every build: the ramp is
  /// an `Animation`, and `GlassPresence` holds it by identity, so a fresh
  /// one every frame would rebuild the tab row's backdrop pass every frame
  /// instead of moving a value through the one pass already warm.
  ///
  /// The ramp is stated in the heights at which the *gap* closes onto the
  /// tab row — [_clearance] to [_contact] — not in some fraction of the way
  /// to the top detent. It has to be: the sheet's glass arrives at the row
  /// long before the sheet is anywhere near full, because the gap that was
  /// holding it clear shrinks with `progress`. A ramp that waited for the
  /// sheet to be three-quarters of the frame tall would leave both surfaces
  /// rendering over the same pixels from the lowest detent onward. The
  /// package pins the same derivation in
  /// `test/src/chrome/sheet_presence_handoff_test.dart`.
  void _syncPresenceRamp(double available) {
    if (_rampFor == available && _rampLowest == widget.lowestFraction) {
      return;
    }
    _rampFor = available;
    _rampLowest = widget.lowestFraction;
    final lowest = available * widget.lowestFraction;
    final span = available - lowest;
    _tabsPresence = _controller.presenceUnder(
      start: lowest + _clearance * span,
      end: lowest + _contact * span,
    );
  }

  @override
  Widget build(BuildContext context) {
    return _Frame(
      child: LayoutBuilder(
        builder: (context, constraints) {
          // The insets are already off — see [_Frame] — so this is the same
          // number `GlassDetentSheet` resolves its own detents against.
          _syncPresenceRamp(constraints.maxHeight);
          return Stack(
            fit: StackFit.expand,
            children: [
              // The page's own chrome, behind the sheet — exactly what a
              // `GlassScaffold` bottom bar would be. It has nowhere else to
              // be: the sheet floats over the same region a real bottom bar
              // would occupy, which is the whole reason a handoff is needed.
              Align(
                alignment: Alignment.bottomCenter,
                child: _TabRow(presence: _tabsPresence),
              ),
              GlassDetentSheet(
                detents: _detentsForLowest(widget.lowestFraction),
                controller: _controller,
                // Sides and bottom stated separately. Only the bottom inset
                // has a job here — clearing the tab row — and buying that
                // clearance through the shared `gap` would charge this sheet
                // twice its width to solve a problem the sides never had.
                gap: _sideGap,
                bottomGap: _bottomGap,
                floatingRadius: _floatingRadius,
                flushRadius: _flushRadius,
                backdrop: _backdrop.panelBackdrop,
                semanticLabel: 'Nearby places',
                child: _placesList(),
              ),
            ],
          );
        },
      ),
    );
  }
}

final CatalogueEntry _glassDetentSheet = CatalogueEntry(
  api: 'GlassDetentSheet',
  purpose:
      'A sheet that is always there — only the height it rests at '
      'changes, and the tab row under it hands off rather than stacking.',
  group: 'Chrome',
  knobs: <Knob<Object?>>[
    Knob<double>(name: 'lowest', value: 0.3, min: 0.18, max: 0.5),
  ],
  build: (knobs) => _DetentSheetDemo(lowestFraction: _asDouble(knobs[0])),
  code: (knobs) {
    final lowest = _asDouble(knobs[0]).toStringAsFixed(2);
    return '$_frameNote'
        'Stack(\n'
        '  children: [\n'
        '    // The handoff: the tabs are gone before the sheet\n'
        '    // reaches them, so the two are never both glass over\n'
        '    // the same pixels.\n'
        "    // Neither end is a constant: the bar's own height\n"
        '    // against bottomGap is where both come from. The gap\n'
        '    // shrinks to $_barHeight and sets the sheet down on the bar\n'
        '    // at 1 - $_barHeight / $_bottomGap; the ramp opens six\n'
        '    // points of gap before that. A taller bar, or a bottomGap no\n'
        '    // bigger than the bar, moves or breaks both.\n'
        '    GlassPresence(\n'
        '      presence: controller.presenceUnder(\n'
        '        start: lowest + $_clearance * span,\n'
        '        end: lowest + $_contact * span,\n'
        '      ),\n'
        '      child: GlassSurface.navigationBar(child: tabs),\n'
        '    ),\n'
        '    GlassDetentSheet(\n'
        '      detents: const [\n'
        '        GlassDetent.fraction($lowest),\n'
        '        GlassDetent.fraction(0.62),\n'
        '        GlassDetent.fraction(1),\n'
        '      ],\n'
        '      controller: controller,\n'
        '      gap: $_sideGap,\n'
        '      bottomGap: $_bottomGap,\n'
        '      floatingRadius: $_floatingRadius,\n'
        '      flushRadius: $_flushRadius,\n'
        '      backdrop: const Color(${_hex(_backdrop.panelBackdrop)}),\n'
        "      semanticLabel: 'Nearby places',\n"
        '      child: ListView(children: places),\n'
        '    ),\n'
        '  ],\n'
        ')';
  },
  seeAlso: const <String>[
    'GlassDetent',
    'GlassDetentSheetController',
    'GlassPresence',
  ],
);

// ---------------------------------------------------------------------------
// GlassDetent
// ---------------------------------------------------------------------------

/// What a `content()` detent measures in this entry.
///
/// A number, not a real measurement: `GlassDetentSheet` does not measure its
/// child yet — see `_syncDetents`, which passes `double.infinity` and takes
/// the documented fallback — so an entry that claimed to have measured
/// something would be claiming more than the package does. This is the
/// height a caller's own content would have reported.
const double _detentContentHeight = 96;

/// One kind of detent, its constructor call and the object carried together
/// — one declaration, read by both `build` and `code`.
typedef _DetentKind = ({String constructorCode, String name, GlassDetent d});

final List<_DetentKind> _detentKinds = <_DetentKind>[
  (
    constructorCode: 'GlassDetent.fraction(0.5)',
    name: 'fraction',
    d: const GlassDetent.fraction(0.5),
  ),
  (
    constructorCode: 'GlassDetent.height(180)',
    name: 'height',
    d: const GlassDetent.height(180),
  ),
  (
    constructorCode: 'GlassDetent.content()',
    name: 'content',
    d: const GlassDetent.content(),
  ),
];

/// One kind's resolved height, drawn as glass, with the number under it.
///
/// The column is given a width of its own rather than taking the widest of
/// its children: the two captions are text, text is as wide as the font
/// makes it, and a row of three columns sized by their labels overflows the
/// moment the font changes — which it does, between the app's Geist and the
/// square test font a widget test renders with.
class _ResolvedBar extends StatelessWidget {
  const _ResolvedBar({
    required this.kind,
    required this.height,
    super.key,
  });

  final _DetentKind kind;
  final double height;

  static const double _columnWidth = 76;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _columnWidth,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 56,
            height: height,
            child: const Glass(
              shape: GlassRoundedRectangle(
                radius: BorderRadius.all(Radius.circular(12)),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            kind.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.caption.copyWith(color: context.inkSecondary),
          ),
          Text(
            '${height.toStringAsFixed(0)} px',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.mono.copyWith(color: context.inkTertiary),
          ),
        ],
      ),
    );
  }
}

/// **Why three bars rather than a sheet.**
///
/// The three kinds exist because the three questions a caller has are
/// different — "a tenth of the screen", "exactly 200 points", "however tall
/// its contents are" — and the only way to see that difference is to
/// resolve all three against one changing height and watch which of them
/// moves. Put them in a sheet instead and the reader sees one height at a
/// time and has to hold the other two in their head.
///
/// So the knob is `available`, the argument [GlassDetent.resolve] takes, and
/// each bar is exactly as tall as that kind says it should be. The fraction
/// scales with it; the fixed height ignores it until it is taller than what
/// is left, because [GlassDetent.resolve] promises a height never taller
/// than `available` and every kind clamps to keep it; the content one does
/// not move at all.
final CatalogueEntry _glassDetent = CatalogueEntry(
  api: 'GlassDetent',
  purpose:
      'One rest height, said three ways — a fraction of what is '
      'available, a fixed number of pixels, or as tall as the content.',
  group: 'Chrome',
  knobs: <Knob<Object?>>[
    Knob<double>(name: 'available', value: 200, min: 120, max: 240),
  ],
  build: (knobs) {
    final available = _asDouble(knobs[0]);
    return SizedBox(
      width: 248,
      height: 232,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final kind in _detentKinds)
            _ResolvedBar(
              key: ValueKey<String>(kind.name),
              kind: kind,
              height: kind.d.resolve(
                available: available,
                contentHeight: _detentContentHeight,
              ),
            ),
        ],
      ),
    );
  },
  code: (knobs) {
    final available = _asDouble(knobs[0]).toStringAsFixed(1);
    return '<GlassDetent>[\n'
        '  const GlassDetent.fraction(0.5),\n'
        '  const GlassDetent.height(180),\n'
        '  const GlassDetent.content(),\n'
        '].map(\n'
        '  (detent) => detent.resolve(\n'
        '    available: $available,\n'
        '    // A real GlassDetentSheet has nothing measuring its\n'
        '    // child yet and passes double.infinity here, so inside\n'
        '    // one a content() detent resolves to available, not to\n'
        '    // this number.\n'
        '    contentHeight: $_detentContentHeight,\n'
        '  ),\n'
        ')';
  },
  seeAlso: const <String>['GlassDetentSheet', 'GlassDetentSheetController'],
);

// ---------------------------------------------------------------------------
// GlassDetentSheetController
// ---------------------------------------------------------------------------

/// The names this entry's knob offers, in detent order.
const List<String> _detentNames = <String>['Peek', 'Half', 'Full'];

/// The fixed three rest heights the controller entry drives between.
const List<GlassDetent> _threeDetents = <GlassDetent>[
  GlassDetent.fraction(0.3),
  GlassDetent.fraction(0.62),
  GlassDetent.fraction(1),
];

/// A sheet driven from outside, by nothing but
/// [GlassDetentSheetController.animateToDetent].
///
/// The controller is created here rather than left to the sheet, which is
/// the only difference between this entry and the last one: a
/// `GlassDetentSheet` makes its own when none is passed, and one it made is
/// one nothing outside it can reach. Owning it is what lets a knob, a deep
/// link or a button somewhere else on the page move the sheet.
///
/// The knob is applied in `didUpdateWidget` rather than in `build`, because
/// `animateToDetent` is a command and `build` is not allowed to be one — it
/// runs again for reasons that have nothing to do with the knob (a theme
/// change, a parent rebuilding) and each of those would restart the spring.
class _DetentControllerDemo extends StatefulWidget {
  const _DetentControllerDemo({required this.detent});

  /// Which of [_threeDetents] the sheet is being sent to.
  final int detent;

  @override
  State<_DetentControllerDemo> createState() => _DetentControllerDemoState();
}

class _DetentControllerDemoState extends State<_DetentControllerDemo>
    with SingleTickerProviderStateMixin {
  late final GlassDetentSheetController _controller =
      GlassDetentSheetController(vsync: this);

  @override
  void didUpdateWidget(covariant _DetentControllerDemo oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.detent != widget.detent) {
      _controller.animateToDetent(widget.detent);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _Frame(
      child: GlassDetentSheet(
        detents: _threeDetents,
        controller: _controller,
        // Where the sheet opens, for the first frame only — the detents are
        // resolved inside the sheet's own `LayoutBuilder`, so there is
        // nowhere to animate to until then and `animateToDetent` called
        // before that is a documented no-op.
        initialDetent: widget.detent,
        gap: _sideGap,
        floatingRadius: _floatingRadius,
        flushRadius: _flushRadius,
        backdrop: _backdrop.panelBackdrop,
        semanticLabel: 'Nearby places',
        child: _placesList(),
      ),
    );
  }
}

final CatalogueEntry _glassDetentSheetController = CatalogueEntry(
  api: 'GlassDetentSheetController',
  purpose:
      "The sheet's height as an Animation of pixels — drive it from "
      'outside, and read the covered chrome off the same value.',
  group: 'Chrome',
  knobs: <Knob<Object?>>[
    Knob<String>(
      name: 'animateToDetent',
      value: _detentNames.first,
      options: _detentNames,
    ),
  ],
  build: (knobs) {
    final index = _detentNames.indexOf(knobs[0].value! as String);
    return _DetentControllerDemo(detent: index);
  },
  code: (knobs) {
    final name = knobs[0].value! as String;
    final index = _detentNames.indexOf(name);
    return '$_frameNote'
        'final controller = GlassDetentSheetController(vsync: this);\n'
        '\n'
        'GlassDetentSheet(\n'
        '  detents: const [\n'
        '    GlassDetent.fraction(0.3),\n'
        '    GlassDetent.fraction(0.62),\n'
        '    GlassDetent.fraction(1),\n'
        '  ],\n'
        '  controller: controller,\n'
        '  // Where it opens. The sheet resolves its detents inside\n'
        '  // its own LayoutBuilder, so animateToDetent before that\n'
        '  // first frame is a documented no-op.\n'
        '  initialDetent: $index,\n'
        '  gap: $_sideGap,\n'
        '  floatingRadius: $_floatingRadius,\n'
        '  flushRadius: $_flushRadius,\n'
        '  backdrop: const Color(${_hex(_backdrop.panelBackdrop)}),\n'
        "  semanticLabel: 'Nearby places',\n"
        '  child: ListView(children: places),\n'
        ');\n'
        '\n'
        '// Afterwards, from anywhere holding the controller:\n'
        'controller.animateToDetent($index); // $name';
  },
  seeAlso: const <String>[
    'GlassDetentSheet',
    'GlassDetent',
    'GlassPresence',
  ],
);

// ---------------------------------------------------------------------------
// GlassSheetScrollPhysics
// ---------------------------------------------------------------------------

/// **What the knob moves, and why that is the honest demonstration.**
///
/// `GlassSheetScrollPhysics` is never constructed by a caller.
/// `GlassDetentSheet` builds one and installs it on every scrollable inside
/// it through a `ScrollConfiguration`, so a list in a sheet already has it
/// and a list outside one has no sheet to hand a gesture to. There is no
/// parameter to move.
///
/// What there is, is the one way to lose it, and it is written down in the
/// class's own doc comment: **a scrollable that names its own `physics` opts
/// out.** `Scrollable` resolves `widget.physics!.applyTo(ambient)`, which
/// makes the caller's choice the *parent* of this one — so a
/// `ListView(physics: BouncingScrollPhysics())` inside a sheet ends up with
/// these physics below `BouncingScrollPhysics`, whose own
/// `applyPhysicsToUserOffset` computes a result without delegating down. The
/// handoff then never runs, silently, and the sheet sits still while the
/// list scrolls inside it.
///
/// So the knob is that `physics` argument. Left null, a drag on the list
/// below the top detent carries the sheet; set to anything, the same drag
/// scrolls the list and the sheet never hears about it. That is a failure
/// mode a reader will otherwise meet for the first time in their own app.
final CatalogueEntry _glassSheetScrollPhysics = CatalogueEntry(
  api: 'GlassSheetScrollPhysics',
  purpose:
      'One gesture crosses from the sheet to the list inside it and '
      'back, with no lifted finger — unless the list names its own.',
  group: 'Chrome',
  knobs: <Knob<Object?>>[
    Knob<String>(
      name: 'physics',
      value: 'inherited',
      options: const <String>['inherited', 'overridden'],
    ),
  ],
  build: (knobs) {
    final overridden = knobs[0].value! as String == 'overridden';
    return _Frame(
      child: GlassDetentSheet(
        detents: const <GlassDetent>[
          GlassDetent.fraction(0.45),
          GlassDetent.fraction(1),
        ],
        gap: _sideGap,
        floatingRadius: _floatingRadius,
        flushRadius: _flushRadius,
        backdrop: _backdrop.panelBackdrop,
        semanticLabel: 'Nearby places',
        child: _placesList(
          physics: overridden ? const BouncingScrollPhysics() : null,
        ),
      ),
    );
  },
  code: (knobs) {
    final overridden = knobs[0].value! as String == 'overridden';
    final physics = overridden ? 'const BouncingScrollPhysics()' : 'null';
    return '$_frameNote'
        'GlassDetentSheet(\n'
        '  detents: const [\n'
        '    GlassDetent.fraction(0.45),\n'
        '    GlassDetent.fraction(1),\n'
        '  ],\n'
        '  gap: $_sideGap,\n'
        '  floatingRadius: $_floatingRadius,\n'
        '  flushRadius: $_flushRadius,\n'
        '  backdrop: const Color(${_hex(_backdrop.panelBackdrop)}),\n'
        "  semanticLabel: 'Nearby places',\n"
        '  // The sheet installs GlassSheetScrollPhysics on every\n'
        '  // scrollable inside it, through a ScrollConfiguration.\n'
        '  // A list that names its own physics becomes their\n'
        '  // parent and never delegates, so the handoff stops.\n'
        '  child: ListView(\n'
        '    physics: $physics,\n'
        '    children: places,\n'
        '  ),\n'
        ')';
  },
  seeAlso: const <String>['GlassDetentSheet', 'GlassDetentSheetController'],
);
