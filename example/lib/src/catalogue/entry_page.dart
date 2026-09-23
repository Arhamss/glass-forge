import 'package:flutter/material.dart'
    show Icons, MaterialRouteTransitionMixin, Scaffold;
import 'package:flutter/widgets.dart';
import 'package:glass_forge/glass_forge.dart';
import 'package:glass_forge_example/src/backdrop.dart';
import 'package:glass_forge_example/src/backdrop_info.dart';
import 'package:glass_forge_example/src/catalogue/catalogue.dart';
import 'package:glass_forge_example/src/catalogue/catalogue_entry.dart';
import 'package:glass_forge_example/src/catalogue/snippet_view.dart';
import 'package:glass_forge_example/src/chrome.dart';
import 'package:glass_forge_example/src/theme.dart';

/// What an index row, or a see-also chip, pushes to reach [entry]'s detail.
///
/// **A handoff, not a cross-fade.** The outgoing page's glass runs its
/// presence to 0 over the *first* half of `animation`/`secondaryAnimation`
/// while the incoming page's presence sits at 0; only once that finishes
/// does the incoming page's presence rise, over the second half. The two
/// are never partly present at once, so there is never a frame with two
/// backdrop passes over the same region — flutter#187820, the bug this
/// package exists to avoid. See [incomingCataloguePresence] and
/// [outgoingCataloguePresence], which this and `CatalogueIndexPage` (via
/// its own `ModalRoute`) build from the same shared [Interval] split.
///
/// [_CatalogueEntryRoute], not a plain `PageRouteBuilder`: the index's own
/// route is a `MaterialPageRoute`, and `MaterialRouteTransitionMixin
/// .canTransitionTo` — the check that decides whether a covered route's
/// `secondaryAnimation` gets proxied to the route being pushed at all —
/// only says yes to a `nextRoute` that is itself a
/// `MaterialRouteTransitionMixin` (or carries a matching
/// `delegatedTransition`). A bare `PageRouteBuilder` is neither, so
/// pushing one leaves the covered route's `secondaryAnimation` pinned at
/// `kAlwaysDismissedAnimation` forever — `outgoingCataloguePresence` would
/// then read a `covered` that never leaves 0, and the index's chrome
/// would never fade at all while the entry page rose over it, exactly the
/// two-passes-at-once failure this whole design exists to prevent. Mixing
/// in `MaterialRouteTransitionMixin` here is what makes the index's
/// `canTransitionTo` check pass.
Route<void> catalogueEntryRoute(CatalogueEntry entry) {
  return _CatalogueEntryRoute(entry: entry);
}

/// A `MaterialPageRoute`-compatible route whose transition is entirely
/// the handoff — see [catalogueEntryRoute] for why it has to be one of
/// these rather than a `PageRouteBuilder`.
class _CatalogueEntryRoute extends PageRoute<void>
    with MaterialRouteTransitionMixin<void> {
  _CatalogueEntryRoute({required this.entry});

  /// What the pushed page shows.
  final CatalogueEntry entry;

  @override
  Widget buildContent(BuildContext context) {
    return CatalogueEntryPage(entry: entry);
  }

  @override
  bool get maintainState => true;

  @override
  Duration get transitionDuration => const Duration(milliseconds: 420);

  @override
  Duration get reverseTransitionDuration => const Duration(milliseconds: 420);

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return GlassPresence(
      presence: incomingCataloguePresence(animation),
      child: child,
    );
  }
}

/// The midpoint every handoff in the catalogue splits at.
///
/// One number shared by [incomingCataloguePresence] and
/// [outgoingCataloguePresence] rather than two independent curves, because
/// the whole safety property rests on their windows meeting exactly here
/// and nowhere else.
const double _handoff = 0.5;

/// The entry page's presence, from its own route's progress.
///
/// 0 for the first half of the push — the outgoing chrome is still the one
/// fading — then ramps 0 to 1 over the second half. Reversed on a pop by
/// the same [Interval], with no separate `reverseCurve` needed: a
/// [CurvedAnimation] applies one curve to whichever way its parent is
/// moving.
Animation<double> incomingCataloguePresence(Animation<double> route) {
  return Tween<double>(begin: 0, end: 1).animate(
    CurvedAnimation(
      parent: route,
      curve: const Interval(_handoff, 1, curve: Curves.easeOutCubic),
    ),
  );
}

/// The covered page's presence, from the entry route's progress over it.
///
/// 1 (its ordinary resting presence) until the push starts, then ramps to 0
/// over the first half — finished well before [incomingCataloguePresence]
/// leaves 0. `CatalogueIndexPage` builds this from its own
/// `ModalRoute.secondaryAnimation`, which is the same `Animation` this
/// route's own `animation` proxies while it is the topmost route — so the
/// two ramps are driven by one shared progress, not two that merely happen
/// to agree.
Animation<double> outgoingCataloguePresence(Animation<double> covered) {
  return Tween<double>(begin: 1, end: 0).animate(
    CurvedAnimation(
      parent: covered,
      curve: const Interval(0, _handoff, curve: Curves.easeInCubic),
    ),
  );
}

/// One capability's detail: the live thing, the knobs that move it, and the
/// Dart that produced what is currently on screen.
///
/// Holds the current [CatalogueEntry], not the widget and the snippet
/// separately — a knob move replaces the whole entry via
/// [CatalogueEntry.withKnob] and both the specimen and [SnippetView]
/// rebuild from that one new list, which is what keeps them unable to
/// disagree. See [CatalogueEntryPageState.setKnob].
///
/// Builds its own [GlassLayer], the same shape `CatalogueIndexPage` does —
/// a self-contained page rather than one that borrows an ambient layer.
/// Its own glass is meant to fade as one, via whatever [GlassPresence] the
/// pushing route supplies above it (see [catalogueEntryRoute]); this page
/// never sets one up for itself; there is none to read when it is built
/// directly, as in a test, which is the correct default — full presence.
///
/// Its `CustomScrollView` carries a local [ScrollConfiguration] turning
/// the overscroll indicator off. That indicator wraps scrollable content
/// in a `Transform` for its stretch effect — the shader path needs
/// Impeller, unavailable in this widget-test environment, so it falls back
/// to a plain one — and that `Transform` is not yet laid out on the frame
/// a `Glass` inside the sliver first registers its geometry:
/// `RenderGlassShape._syncGeometry` walks straight through it via
/// `getTransformTo` and throws. A page-local override rather than relying
/// on `main.dart`'s app-wide one, because this page is built directly in
/// tests under a plain `MaterialApp` that never gets `main.dart`'s
/// `scrollBehavior` — the fix has to travel with the page, not the app.
class CatalogueEntryPage extends StatefulWidget {
  /// Creates the detail page for [entry].
  const CatalogueEntryPage({required this.entry, super.key});

  /// What this page shows, at the knob values it was pushed with.
  final CatalogueEntry entry;

  @override
  State<CatalogueEntryPage> createState() => CatalogueEntryPageState();
}

/// Public — and named without the usual leading underscore — because
/// driving a knob change through the state under test is the point: it
/// exercises the model's own rebuild-both-together guarantee without also
/// exercising a slider's gesture handling, which is a different concern.
class CatalogueEntryPageState extends State<CatalogueEntryPage> {
  late CatalogueEntry _entry;

  /// The bar's own height, independent of the safe-area inset — see
  /// `CatalogueIndexPage._barContentHeight`, which this mirrors.
  static const double _barContentHeight = 56;

  /// The same photograph `CatalogueIndexPage` sits over — see
  /// [catalogueBackdropPhoto].
  static final BackdropInfo _backdrop = backdropFor(catalogueBackdropPhoto);

  @override
  void initState() {
    super.initState();
    _entry = widget.entry;
  }

  @override
  void didUpdateWidget(covariant CatalogueEntryPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.entry, widget.entry)) {
      _entry = widget.entry;
    }
  }

  /// Replaces knob [index] with [value] and rebuilds from the result —
  /// the specimen and the snippet both read [_entry] fresh, so neither can
  /// move without the other.
  void setKnob(int index, Object? value) {
    setState(() => _entry = _entry.withKnob(index, value));
  }

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;
    final barHeight = topInset + _barContentHeight;

    // A Scaffold for the same reason `CatalogueIndexPage` uses one: every
    // label here is drawn straight onto glass or bare photograph, and
    // `MaterialApp` underlines any text outside a `Material`.
    return Scaffold(
      backgroundColor: Tone.ground,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Backdrop(photo: _backdrop.photo),
          GlassLayer(
            material: _backdrop.material,
            child: Stack(
              children: [
                Positioned.fill(
                  // A local override, not a reliance on `main.dart`'s
                  // app-wide one — see the doc comment on
                  // `CatalogueEntryPage` for why a `CustomScrollView` with
                  // glass inside it needs this regardless of what any
                  // ancestor's `MaterialApp` set.
                  child: ScrollConfiguration(
                    behavior: ScrollConfiguration.of(
                      context,
                    ).copyWith(overscroll: false),
                    child: CustomScrollView(
                      slivers: [
                        SliverPadding(
                          padding: EdgeInsets.only(top: barHeight),
                        ),
                        SliverToBoxAdapter(child: _Specimen(entry: _entry)),
                        SliverToBoxAdapter(child: _Header(entry: _entry)),
                        SliverToBoxAdapter(
                          child: _KnobRow(
                            entry: _entry,
                            onKnobChanged: setKnob,
                          ),
                        ),
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                          sliver: SliverToBoxAdapter(
                            child: SnippetView(entry: _entry),
                          ),
                        ),
                        SliverToBoxAdapter(child: _SeeAlso(entry: _entry)),
                        const SliverPadding(
                          padding: EdgeInsets.only(bottom: 24),
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: barHeight,
                  child: _TopBar(
                    group: _entry.group,
                    backdrop: _backdrop.barBackdrop,
                    topInset: topInset,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The bar pinned to the top: a way back, and which group this entry is
/// from — the comp's "‹ Chrome". Edge-to-edge for the same reason
/// `CatalogueIndexPage`'s own bar is: the comp draws its glass running to
/// the top of the frame rather than floating below the safe-area inset.
class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.group,
    required this.backdrop,
    required this.topInset,
  });

  final String group;
  final Color backdrop;
  final double topInset;

  @override
  Widget build(BuildContext context) {
    // The back affordance is painted, not a second `Glass` — one already
    // covers this whole bar, and nesting another inside its child is
    // exactly the composition `Glass.build` refuses to let through (see
    // `_Specimen`'s own doc comment for the longer version of why).
    return GlassSurface.navigationBar(
      backdrop: backdrop,
      child: Padding(
        padding: EdgeInsets.fromLTRB(12, topInset + 8, 20, 8),
        child: Row(
          children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => Navigator.of(context).maybePop(),
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: Icon(
                  Icons.chevron_left_rounded,
                  color: context.ink,
                  size: 24,
                ),
              ),
            ),
            const SizedBox(width: 2),
            Expanded(
              child: Text(
                group,
                style: context.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The live specimen, large, directly over the photograph.
///
/// Bare — no `Glass` or `GlassSurface` wraps it. Apple's own guidance is
/// "always avoid glass on glass", and `Glass.build` enforces it here as
/// more than a style note: wrapping a specimen whose own `build` is itself
/// a `Glass` (which most of this catalogue's specimens are) would nest one
/// piece of glass inside another's child and hit the assertion that says
/// exactly that. The specimen sits on the stage; it does not sit in a
/// frame.
class _Specimen extends StatelessWidget {
  const _Specimen({required this.entry});

  final CatalogueEntry entry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      child: SizedBox(
        height: 260,
        child: Center(child: entry.build(entry.knobs)),
      ),
    );
  }
}

/// The API name in mono, and the one-line purpose under it.
class _Header extends StatelessWidget {
  const _Header({required this.entry});

  final CatalogueEntry entry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            entry.api,
            style: context.mono.copyWith(
              color: context.ink,
              fontSize: 24,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            entry.purpose,
            style: context.body.copyWith(color: context.inkSecondary),
          ),
        ],
      ),
    );
  }
}

/// One painted control per knob — a [ValueSlider] where the knob has a
/// range, a [SegmentedControl] where it has options — each on its own
/// [GlassSurface.control], because `chrome.dart`'s controls are painted
/// onto glass rather than being glass themselves.
class _KnobRow extends StatelessWidget {
  const _KnobRow({required this.entry, required this.onKnobChanged});

  final CatalogueEntry entry;
  final void Function(int index, Object? value) onKnobChanged;

  @override
  Widget build(BuildContext context) {
    if (entry.knobs.isEmpty) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
      child: Column(
        children: [
          for (var i = 0; i < entry.knobs.length; i++) ...[
            if (i != 0) const SizedBox(height: 10),
            GlassSurface.control(child: _controlFor(entry.knobs[i], i)),
          ],
        ],
      ),
    );
  }

  Widget _controlFor(Knob<Object?> knob, int index) {
    if (knob.min != null && knob.max != null) {
      return ValueSlider(
        label: knob.name,
        value: (knob.value! as num).toDouble(),
        min: knob.min!,
        max: knob.max!,
        format: (value) => value.toStringAsFixed(1),
        onChanged: (value) => onKnobChanged(index, value),
      );
    }
    return SegmentedControl<Object?>(
      options: knob.options,
      selected: knob.value,
      // The knob names its own options. A control that invented labels
      // here would have nothing to go on but the value's type, which for
      // a record is a debug dump — see [Knob.labelFor].
      labelOf: knob.labelFor,
      onChanged: (value) => onKnobChanged(index, value),
    );
  }
}

/// "SEE ALSO", and one name per entry in [CatalogueEntry.seeAlso].
///
/// A name that resolves to a real entry is a [PillButton] and pushes to it
/// with the same [catalogueEntryRoute] an index row uses — the catalogue is
/// not only index-to-detail, an entry can hand off to another entry the
/// same way. A name with no entry is still worth printing, because it is
/// still a real symbol the reader can go and look up; it is drawn as plain
/// text instead, so the row never offers a tap it cannot honour. See
/// [_SeeAlsoChip].
///
/// [WrapCrossAlignment.center] because the two treatments are different
/// heights: a pill carries its own padding and an unpilled name does not,
/// and aligning them at the top would step every plain name up out of its
/// row.
class _SeeAlso extends StatelessWidget {
  const _SeeAlso({required this.entry});

  final CatalogueEntry entry;

  @override
  Widget build(BuildContext context) {
    if (entry.seeAlso.isEmpty) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'SEE ALSO',
            style: context.caption.copyWith(
              color: context.inkTertiary,
              fontWeight: FontWeight.w600,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              for (final api in entry.seeAlso) _SeeAlsoChip(api: api),
            ],
          ),
        ],
      ),
    );
  }
}

/// One see-also name, in whichever of the two treatments it has earned.
///
/// **A pill only when there is an entry to open.** Eight of the names this
/// catalogue cross-references — `GlassShape`, `GlassSurfaces`,
/// `GlassTintRamp`, `GlassTints`, `AccessibilitySignalSource`,
/// `FrameWatchdog`, `ThermalSignal`, `RenderCapabilities` — are real
/// exported symbols that the plan deliberately spends no entry on. They are
/// worth naming anyway, so they stay; what they cannot do is wear the same
/// pill as a name that navigates, which is what they used to do while
/// carrying a null `onTap`. A control that looks pressable and does nothing
/// reads as a broken app, not as a missing page.
///
/// The unpilled treatment is the same pair [SegmentedControl] already uses
/// for the half of itself that is not selected: no fill, and
/// [SurfaceInk.inkTertiary] rather than the full label colour. Both steps
/// resolve off the enclosing surface, so the distinction survives a bar
/// that flipped its scheme.
///
/// **A pill says "there is an entry", not "this is a class".** Two entries
/// are named for a subject rather than a symbol — `Material knobs` and
/// `Cross-pass overlap` — because no single class names the eight fields
/// that shape a `GlassMaterial`, or an illegal composition. `Material
/// knobs` is a see-also target, and it gets a pill like any other, because
/// the one thing the pill promises is a page, and there is one. A third
/// treatment for concept entries would split the row along an axis the
/// reader is not asking about and blunt the only distinction it does make.
/// Nor does a pill imply a symbol typographically: every chip is set in
/// [AppText.label], the app's sans, where an actual API name is set in
/// [AppText.mono].
///
/// Painted either way, never glass — a row of chips this small would each
/// cost their own backdrop pass for no visual gain, since none of them need
/// to refract anything.
class _SeeAlsoChip extends StatelessWidget {
  const _SeeAlsoChip({required this.api});

  final String api;

  @override
  Widget build(BuildContext context) {
    final target = findEntryByApi(api);
    if (target == null) {
      return Padding(
        // The pill's own vertical padding, so a run of plain names sets at
        // the same rhythm as a run of pills rather than closing up.
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        child: Text(
          api,
          style: context.label.copyWith(color: context.inkTertiary),
        ),
      );
    }
    return PillButton(
      label: api,
      onTap: () => Navigator.of(context).push(catalogueEntryRoute(target)),
    );
  }
}
