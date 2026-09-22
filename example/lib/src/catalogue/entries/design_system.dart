import 'package:flutter/widgets.dart';
import 'package:glass_forge/glass_forge.dart';
import 'package:glass_forge_example/src/backdrop_info.dart';
import 'package:glass_forge_example/src/catalogue/catalogue_entry.dart';
import 'package:glass_forge_example/src/theme.dart';

/// The Design system group: the theme that carries the system, the widget
/// that plays one role out of it, the scales it resolves against, the named
/// steps on the tint ramp, and the arithmetic every one of those promises is
/// stated in.
///
/// Five entries, and the layering is the story they tell together. A
/// `GlassSurface` names a **role**; `GlassSurfaces` says what that role is
/// made of, in token *names* rather than numbers; `GlassTokens` says what
/// those names are worth; `GlassTintStep` is one rung of one of those
/// ladders; and `GlassLegibility` is the function that decides how far up
/// the ladder a surface has to stand over a given backdrop. `GlassTheme` is
/// how a consumer replaces any of it.
///
/// `GlassTintRamp` and `GlassTints` get no entries of their own. Neither
/// name appears at a call site — a caller writes
/// `tint: GlassTintStep.readable` and reads them back off `GlassTokens.tint`
/// — so they are named in the copy of the entries that use them rather than
/// claiming rows nobody would search for.
final List<CatalogueEntry> designSystemEntries = <CatalogueEntry>[
  _glassTheme,
  _glassSurface,
  _glassTokens,
  _glassTintStep,
  _glassLegibility,
];

double _asDouble(Knob<Object?> knob) => knob.value! as double;

/// A colour as the Dart literal a snippet would quote.
///
/// Derived from the value rather than typed beside it: every colour in this
/// file comes out of [backdrops], and a hand-written hex is one edit away
/// from describing a photograph nobody is looking at.
String _hex(Color color) =>
    '0x${color.toARGB32().toRadixString(16).toUpperCase().padLeft(8, '0')}';

/// The photograph the whole catalogue sits over, and the colours measured
/// off it.
///
/// Everything here that supplies a `backdrop`, or prints a contrast figure,
/// uses this one sample — the same one the Chrome group hands its sheets. A
/// contrast number measured against a colour nobody put on screen would be
/// arithmetic about nothing.
final BackdropInfo _backdrop = backdropFor(catalogueBackdropPhoto);

/// How wide every specimen in this file is.
///
/// One width for all five: four of them are a surface with its own resolved
/// facts printed on it and the fifth is those facts without the surface, so
/// a reader paging between them should see the numbers move, not the box.
const double _panelWidth = 216;

/// The inset between a specimen surface's edge and the facts on it.
const EdgeInsets _panelPadding = EdgeInsets.symmetric(
  horizontal: 16,
  vertical: 12,
);

/// A token or field name on the left, the value it resolved to on the
/// right.
///
/// The name is [Expanded] rather than set beside a `Spacer`: these names run
/// long — `radius.extraLarge` is seventeen characters — and a row of two
/// intrinsically-sized `Text`s overflows the moment the font changes, which
/// it does between the app's Geist and the square fallback a widget test
/// renders with.
class _Fact extends StatelessWidget {
  const _Fact(this.name, this.value);

  /// What the design system calls it.
  final String name;

  /// What it came out as here.
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Row(
        children: [
          Expanded(
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.label.copyWith(color: context.inkSecondary),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.mono,
          ),
        ],
      ),
    );
  }
}

/// The heading on a specimen surface — one word, in the surface's own ink.
class _PanelTitle extends StatelessWidget {
  const _PanelTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: context.label,
    );
  }
}

// ---------------------------------------------------------------------------
// GlassTheme
// ---------------------------------------------------------------------------

/// The knob's three positions, spelled the way a caller says them.
const List<String> _brightnessNames = <String>['platform', 'light', 'dark'];

/// The `brightness` each position passes to [GlassThemeData].
///
/// `platform` is null, and null is the default rather than a missing value:
/// with nothing pinned, [GlassTheme.brightnessOf] reads
/// `MediaQuery.platformBrightnessOf`, so glass agrees with the rest of the
/// app without either one being told about the other.
Brightness? _brightnessFor(String name) => switch (name) {
  'light' => Brightness.light,
  'dark' => Brightness.dark,
  _ => null,
};

/// How tall the card in this specimen is.
const double _themeCardHeight = 84;

/// How tall the control under it is — the HIG's minimum touch target.
const double _themeControlHeight = 44;

/// The gap between the two.
///
/// Wide enough that the two silhouettes never touch. Two glass shapes with
/// differing materials overlapping is the one composition this renderer
/// warns about, and a card and a control *are* two materials: the card blurs
/// regular and tints readable, the control blurs thin and tints regular.
const double _themeGap = 14;

/// The card's body copy, and the whole claim this entry makes.
class _ThemeCard extends StatelessWidget {
  const _ThemeCard();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: _panelPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _PanelTitle('card'),
          const SizedBox(height: 4),
          Text(
            'Both surfaces take their scheme from the one theme above '
            'them.',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: context.caption.copyWith(color: context.inkSecondary),
          ),
        ],
      ),
    );
  }
}

/// **Why neither surface here is given a `backdrop`.**
///
/// A surface that knows what is behind it may leave the scheme the theme
/// named: `GlassSurfaceSpec.control` flips, and at 44 points it is under the
/// size gate, so a supplied backdrop would pick its scheme off the
/// photograph and this knob would move everything except the surface a
/// reader is most likely watching. That behaviour is real and worth seeing —
/// it is what the `GlassSurface` entry shows. This entry is the other half
/// of the rule: with nothing to adapt to, everything under one `GlassTheme`
/// resolves in the scheme it names, down to the colour of the labels.
final CatalogueEntry _glassTheme = CatalogueEntry(
  api: 'GlassTheme',
  purpose:
      'Tokens, surfaces and motion as one inherited value — and the '
      'scheme every surface under it resolves in.',
  group: 'Design system',
  knobs: <Knob<Object?>>[
    Knob<String>(
      name: 'brightness',
      value: _brightnessNames.first,
      options: _brightnessNames,
    ),
  ],
  build: (knobs) {
    final name = knobs[0].value! as String;
    return SizedBox(
      width: _panelWidth,
      height: _themeCardHeight + _themeGap + _themeControlHeight,
      child: GlassTheme(
        data: GlassThemeData(brightness: _brightnessFor(name)),
        // Stretched, so both surfaces are the panel's full width rather
        // than their own text's. A `GlassSurface` resolves against the
        // constraints it is given, and a card that shrank to its label
        // would be resolving a size the reader never asked for.
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              key: ValueKey<String>('card'),
              height: _themeCardHeight,
              child: GlassSurface.card(child: _ThemeCard()),
            ),
            SizedBox(height: _themeGap),
            SizedBox(
              key: ValueKey<String>('control'),
              height: _themeControlHeight,
              child: GlassSurface.control(
                child: Center(child: _PanelTitle('control')),
              ),
            ),
          ],
        ),
      ),
    );
  },
  code: (knobs) {
    final name = knobs[0].value! as String;
    final brightness = _brightnessFor(name);
    final data = brightness == null
        ? 'const GlassThemeData(), // null: follows the platform'
        : 'const GlassThemeData(brightness: $brightness),';
    return 'GlassTheme(\n'
        '  data: $data\n'
        '  child: const Column(\n'
        '    crossAxisAlignment: CrossAxisAlignment.stretch,\n'
        '    children: [\n'
        '      SizedBox(\n'
        '        height: $_themeCardHeight,\n'
        '        child: GlassSurface.card(child: cardBody),\n'
        '      ),\n'
        '      SizedBox(height: $_themeGap),\n'
        '      SizedBox(\n'
        '        height: $_themeControlHeight,\n'
        '        child: GlassSurface.control(child: controlLabel),\n'
        '      ),\n'
        '    ],\n'
        '  ),\n'
        ')';
  },
  seeAlso: const <String>['GlassTokens', 'GlassSurface', 'GlassTintStep'],
);

// ---------------------------------------------------------------------------
// GlassSurface, and the GlassSurfaces specs behind it
// ---------------------------------------------------------------------------

/// How tall a role specimen is.
///
/// 96 on purpose, and not a pixel more: it is `GlassTokens.flipMaxShortSide`
/// exactly, the tallest standard bar iOS ships, so a role that is allowed to
/// flip still does here. One point taller and `adaptationFor` would demote
/// `navigationBar` and `control` to `adapt`, and the `adaptation` fact
/// printed on every one of the five would read the same word.
const double _roleHeight = 96;

/// The size a role specimen resolves against.
///
/// Stated rather than measured, and it is the same number either way: the
/// surface sits in a doubly-tight box, so the `constraints.biggest`
/// `GlassSurface` resolves against internally is exactly this.
const Size _roleSize = Size(_panelWidth, _roleHeight);

/// The five roles, in the order [GlassSurfaceRole] declares them.
///
/// Each one's name is also its constructor's name — `GlassSurface.sheet`
/// plays `GlassSurfaceRole.sheet` — which is what lets the snippet below
/// render a real call from nothing but the enum.
const List<GlassSurfaceRole> _roles = GlassSurfaceRole.values;

/// What the chosen role actually resolved to, printed on the surface
/// playing it.
///
/// The same [GlassTheme.surfaceOf] call `GlassSurface` makes internally, run
/// a second time here for one reason: [GlassSurfaceStyle.labelContrast] is
/// the contrast this role achieves over this photograph, and a promise
/// nobody can read is not a promise.
class _RoleFacts extends StatelessWidget {
  const _RoleFacts({required this.role});

  final GlassSurfaceRole role;

  @override
  Widget build(BuildContext context) {
    final style = GlassTheme.surfaceOf(
      context,
      role,
      size: _roleSize,
      backdrop: _backdrop.panelBackdrop,
    );
    final contrast = style.labelContrast;
    return Padding(
      padding: _panelPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _PanelTitle(role.name),
          const SizedBox(height: 2),
          _Fact('adaptation', style.adaptation.name),
          _Fact(
            'labelContrast',
            contrast == null
                ? 'unmeasured'
                : '${contrast.toStringAsFixed(1)}:1',
          ),
        ],
      ),
    );
  }
}

/// **One semantic surface, and the five specs behind the five roles.**
///
/// `GlassSurface` is one line at a call site and four decisions underneath
/// it. The role picks a [GlassSurfaceSpec] out of [GlassSurfaces]; the spec
/// names token *steps* rather than numbers; the size gate decides how much
/// adaptation that role actually gets; and the backdrop, where the app knows
/// one, decides which scheme wins and how much tint it takes to keep the
/// labels legible.
///
/// Moving the knob moves all four at once, which is the point — the roles
/// are not five styles, they are five different *answers*. The corner radius
/// alone separates them on sight: a card resolves `medium`, a bar `large`, a
/// sheet `extraLarge`, a control a capsule, and a scrim no radius at all.
final CatalogueEntry _glassSurface = CatalogueEntry(
  api: 'GlassSurface',
  purpose:
      'One semantic role — bar, sheet, card, control or scrim — resolved '
      'against a size, a scheme and what is behind it.',
  group: 'Design system',
  knobs: <Knob<Object?>>[
    Knob<GlassSurfaceRole>(
      name: 'role',
      value: GlassSurfaceRole.card,
      options: _roles,
    ),
  ],
  build: (knobs) {
    final role = knobs[0].value! as GlassSurfaceRole;
    return SizedBox(
      width: _panelWidth,
      height: _roleHeight,
      child: GlassSurface(
        role: role,
        backdrop: _backdrop.panelBackdrop,
        child: _RoleFacts(role: role),
      ),
    );
  },
  code: (knobs) {
    final role = knobs[0].value! as GlassSurfaceRole;
    // Read off the same `GlassSurfaces` the surface resolves through, so
    // the three names in the comment are this role's real spec rather than
    // a description of it that could drift.
    final spec = const GlassSurfaces().of(role);
    final resolved = spec.adaptationFor(
      _roleSize,
      maxShortSide: const GlassTokens().flipMaxShortSide,
    );
    final size = '${_roleSize.width.toInt()}x${_roleSize.height.toInt()}';
    return 'GlassSurface.${role.name}(\n'
        '  // GlassSurfaceSpec.${role.name}, out of GlassSurfaces:\n'
        '  // blur ${spec.blur.name}, tint ${spec.tint.name}, '
        'radius ${spec.radius.name},\n'
        '  // depth ${spec.depth.name}, labels promised '
        '${spec.minimumContrast}:1.\n'
        '  //\n'
        '  // Adaptation is at most ${spec.adaptation.name}; at $size '
        'the size\n'
        '  // gate leaves it ${resolved.name}.\n'
        '  backdrop: const Color(${_hex(_backdrop.panelBackdrop)}),\n'
        '  child: facts,\n'
        ')';
  },
  seeAlso: const <String>[
    'GlassSurfaces',
    'GlassTheme',
    'GlassTokens',
    'GlassLegibility',
  ],
);

// ---------------------------------------------------------------------------
// GlassTokens
// ---------------------------------------------------------------------------

/// How tall the token specimen is.
///
/// Room for a `radius.extraLarge` at the top of its slider: the shape's
/// radius is clamped to half the shorter side at paint time, so anything
/// over 58 here would stop being a number the reader can see move.
const double _tokensHeight = 116;

/// The facts a token override lands on.
class _TokenFacts extends StatelessWidget {
  const _TokenFacts({required this.thick, required this.extraLarge});

  /// The sigma [GlassBlurStep.thick] was moved to.
  final double thick;

  /// The radius [GlassRadiusStep.extraLarge] was moved to.
  final double extraLarge;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: _panelPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const _PanelTitle('sheet'),
          const SizedBox(height: 2),
          _Fact('blur.thick', thick.toStringAsFixed(1)),
          _Fact('radius.extraLarge', extraLarge.toStringAsFixed(1)),
        ],
      ),
    );
  }
}

/// **Why the sheet role, and why these two rungs.**
///
/// `GlassSurfaceSpec.sheet` asks for `blur: thick` and
/// `radius: extraLarge`, so those are the two rungs of the two ladders this
/// specimen is actually standing on — move either and the surface on screen
/// changes, because the role named that step by name and the theme decides
/// what the name is worth.
///
/// Moving `blur.regular` instead would have looked like a knob that did
/// nothing, and it is worth knowing why: blur steps are applied as a
/// **ratio** to the scale's own `regular` (`GlassBlurScale.factorOf`), so
/// that the fitted frost's light/dark difference survives every step. Widen
/// the anchor and the whole ladder widens with it; the regular step's
/// factor stays exactly 1.
final CatalogueEntry _glassTokens = CatalogueEntry(
  api: 'GlassTokens',
  purpose:
      'The blur, radius, depth and tint ladders a role names its steps '
      'on — and what one theme can change them to.',
  group: 'Design system',
  knobs: <Knob<Object?>>[
    Knob<double>(name: 'blur.thick', value: 14, min: 7, max: 28),
    Knob<double>(name: 'radius.extraLarge', value: 44, min: 12, max: 58),
  ],
  build: (knobs) {
    final thick = _asDouble(knobs[0]);
    final extraLarge = _asDouble(knobs[1]);
    return SizedBox(
      width: _panelWidth,
      height: _tokensHeight,
      child: GlassTheme(
        data: GlassThemeData(
          tokens: GlassTokens(
            blur: GlassBlurScale(thick: thick),
            radius: GlassRadiusScale(extraLarge: extraLarge),
          ),
        ),
        // No `backdrop`: this entry is about what the *tokens* are worth,
        // and a supplied backdrop would let the legibility solver raise the
        // tint past the step the sheet asked for. That raise is the
        // `GlassLegibility` entry's subject.
        child: GlassSurface.sheet(
          child: _TokenFacts(thick: thick, extraLarge: extraLarge),
        ),
      ),
    );
  },
  code: (knobs) {
    final thick = _asDouble(knobs[0]).toStringAsFixed(1);
    final extraLarge = _asDouble(knobs[1]).toStringAsFixed(1);
    return 'GlassTheme(\n'
        '  data: const GlassThemeData(\n'
        '    tokens: GlassTokens(\n'
        '      // GlassSurfaceSpec.sheet asks for blur: thick and\n'
        '      // radius: extraLarge, so these two rungs are the ones\n'
        '      // that reach it. Every other scale stays fitted.\n'
        '      blur: GlassBlurScale(thick: $thick),\n'
        '      radius: GlassRadiusScale(extraLarge: $extraLarge),\n'
        '    ),\n'
        '  ),\n'
        '  child: GlassSurface.sheet(child: facts),\n'
        ')';
  },
  seeAlso: const <String>['GlassTheme', 'GlassSurface', 'GlassTintStep'],
);

// ---------------------------------------------------------------------------
// GlassTintStep
// ---------------------------------------------------------------------------

/// How tall the tint specimen is.
const double _tintHeight = 104;

/// The step, the opacity it resolved to, and what that buys on this photo.
///
/// The ramp is read back out of the theme — `GlassTokens.tint` is a
/// [GlassTints], and `of` picks the [GlassTintRamp] for the scheme in scope
/// — rather than naming `GlassTintRamp.appleLight` here. A consumer who
/// replaced either ramp would want these numbers to be theirs.
class _TintFacts extends StatelessWidget {
  const _TintFacts({required this.step});

  final GlassTintStep step;

  @override
  Widget build(BuildContext context) {
    final ramp = GlassTheme.of(
      context,
    ).tokens.tint.of(GlassTheme.brightnessOf(context));
    final contrast = ramp.labelContrastOver(
      _backdrop.panelBackdrop,
      step: step,
    );
    return Padding(
      padding: _panelPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _PanelTitle(step.name),
          const SizedBox(height: 2),
          _Fact('tintOpacity', ramp.opacityFor(step).toStringAsFixed(3)),
          _Fact('labelContrast', '${contrast.toStringAsFixed(1)}:1'),
        ],
      ),
    );
  }
}

/// **The names are promises, not sizes.**
///
/// Each step is the *smallest* tint opacity that keeps its promise over the
/// worst backdrop its scheme can face: `legible` clears 3:1, `readable`
/// 4.5:1, `opaque` 7:1, and `regular` is Apple's own fitted value, which
/// lands between the first two — legible for large text, short of the
/// body-text threshold. That is the compromise in Apple's fit, recorded
/// rather than corrected.
///
/// The opacity each name resolves to lives on a [GlassTintRamp], one per
/// scheme, and the pair of them is the [GlassTints] on `GlassTokens.tint`.
/// Neither is written at a call site, which is why neither has an entry:
/// what a caller writes is the step, on a role's spec.
///
/// No `backdrop` is supplied to the card, deliberately. With one, the
/// legibility solver would raise the tint above whichever step the knob
/// asked for whenever that step undershot the role's 4.5:1 target — and a
/// knob whose lower half all resolved to the same opacity would teach the
/// wrong thing about what the steps are. The contrast printed underneath is
/// still measured against this photograph, because that is the colour this
/// card is genuinely sitting over.
final CatalogueEntry _glassTintStep = CatalogueEntry(
  api: 'GlassTintStep',
  purpose:
      'Four named points on the tint ramp, each the least tint that '
      'clears a stated contrast over the worst backdrop.',
  group: 'Design system',
  knobs: <Knob<Object?>>[
    Knob<GlassTintStep>(
      name: 'tint',
      value: GlassTintStep.regular,
      options: GlassTintStep.values,
    ),
  ],
  build: (knobs) {
    final step = knobs[0].value! as GlassTintStep;
    return SizedBox(
      width: _panelWidth,
      height: _tintHeight,
      child: GlassTheme(
        data: GlassThemeData(
          surfaces: GlassSurfaces(
            card: GlassSurfaceSpec.card.copyWith(tint: step),
          ),
        ),
        child: GlassSurface.card(child: _TintFacts(step: step)),
      ),
    );
  },
  code: (knobs) {
    final step = knobs[0].value! as GlassTintStep;
    return 'GlassTheme(\n'
        '  data: GlassThemeData(\n'
        '    // GlassTokens.tint is a GlassTints: one GlassTintRamp\n'
        '    // per scheme, and the step names an opacity on it.\n'
        '    surfaces: GlassSurfaces(\n'
        '      card: GlassSurfaceSpec.card.copyWith(\n'
        '        tint: GlassTintStep.${step.name},\n'
        '      ),\n'
        '    ),\n'
        '  ),\n'
        '  child: GlassSurface.card(child: facts),\n'
        ')';
  },
  seeAlso: const <String>[
    'GlassLegibility',
    'GlassTokens',
    'GlassSurface',
    'GlassTints',
  ],
);

// ---------------------------------------------------------------------------
// GlassLegibility
// ---------------------------------------------------------------------------

/// How tall a swatch in the legibility specimen is.
const double _swatchHeight = 60;

/// How wide one is.
const double _swatchWidth = 100;

/// The gap between the two.
const double _swatchGap = 16;

/// How tall the whole legibility specimen is.
///
/// The swatch, six points of air, the caption naming the column and the
/// mono line under it, then ten more points and the line saying which
/// colour all of this was solved against. Stated rather than left to the
/// column: the index thumbnail hands every specimen an unbounded width, so
/// a root that measured itself from its children would never lay out.
const double _legibilityHeight = _swatchHeight + 6 + 16 + 16 + 10 + 16;

/// The tints this entry solves against.
const GlassTints _tints = GlassTints();

/// The scheme a surface that may *not* flip is stuck with over [backdrop].
///
/// [GlassTints.schemeFor] names the scheme whose labels read better there,
/// and a `GlassAdaptation.flip` role takes it and is finished — over these
/// photographs that is the dark scheme, which clears 7:1 with no tint at
/// all. An `adapt` role, which is what a sheet or a card is, keeps the
/// ambient scheme instead and can only thicken.
///
/// So this entry solves for the ramp that *lost*, because that is the only
/// case [GlassLegibility.opacityForContrast] exists to handle: everything a
/// flipping surface needs, `schemeFor` already gave it.
Brightness _adaptingScheme(Color backdrop) =>
    _tints.schemeFor(backdrop) == Brightness.dark
    ? Brightness.light
    : Brightness.dark;

/// One composited surface, with a label on it, and the contrast between
/// the two printed underneath.
///
/// The label's colour is never named here. It is the ramp's own
/// [GlassTintRamp.label] — the one of black or white that scheme exists to
/// make readable — published through a `DefaultTextStyle` exactly as
/// `GlassSurface` publishes its own, so the `Text` inside inherits it the
/// same way everything drawn on a real surface does, through the style
/// [SurfaceInk] reads.
class _ContrastSwatch extends StatelessWidget {
  const _ContrastSwatch({
    required this.label,
    required this.opacity,
    required this.ramp,
    required this.swatchKey,
  });

  /// What this column is showing — `floor` or the solved step.
  final String label;

  /// The tint opacity this swatch composites at.
  final double opacity;

  /// The ramp the tint and the label colour come from.
  final GlassTintRamp ramp;

  /// The key on the painted composite, so a test can read its colour.
  final Key swatchKey;

  @override
  Widget build(BuildContext context) {
    final surface = GlassLegibility.surfaceOver(
      tint: ramp.color,
      opacity: opacity,
      backdrop: _backdrop.panelBackdrop,
    );
    final contrast = GlassLegibility.contrastRatio(surface, ramp.label);
    return SizedBox(
      width: _swatchWidth,
      child: Column(
        // Min, not the default max: a `Row` hands its children loose
        // vertical constraints, so a greedy column here would grow to the
        // panel's whole height and push the caption under it off the
        // bottom of a specimen sized to fit exactly.
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: _swatchHeight,
            child: ColoredBox(
              key: swatchKey,
              color: surface,
              child: DefaultTextStyle.merge(
                style: TextStyle(color: ramp.label),
                child: const Center(child: _PanelTitle('Label')),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.caption.copyWith(color: context.inkTertiary),
          ),
          Text(
            '${opacity.toStringAsFixed(3)}  '
            '${contrast.toStringAsFixed(1)}:1',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.mono.copyWith(color: context.inkSecondary),
          ),
        ],
      ),
    );
  }
}

/// What the caption says when the floor was already enough.
const String _flooredLabel = 'The floor already clears it';

/// And when the solver had to thicken the tint to get there.
const String _raisedLabel = 'Raised above the floor to reach it';

/// The whole specimen: a floor, the opacity solved for the target, and the
/// contrast each one lands on.
class _LegibilityPanel extends StatelessWidget {
  const _LegibilityPanel({required this.target});

  /// The contrast ratio being solved for.
  final double target;

  @override
  Widget build(BuildContext context) {
    final ramp = _tints.of(_adaptingScheme(_backdrop.panelBackdrop));
    final raised = GlassLegibility.opacityForContrast(
      tint: ramp.color,
      backdrop: _backdrop.panelBackdrop,
      label: ramp.label,
      target: target,
      floor: ramp.legible,
      ceiling: ramp.opaque,
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _ContrastSwatch(
              label: 'floor',
              opacity: ramp.legible,
              ramp: ramp,
              swatchKey: const ValueKey<String>('floor'),
            ),
            const SizedBox(width: _swatchGap),
            _ContrastSwatch(
              label: 'target ${target.toStringAsFixed(1)}:1',
              opacity: raised,
              ramp: ramp,
              swatchKey: const ValueKey<String>('raised'),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          // Which of the two rules is in force, in one line. Below the
          // crossover the right swatch is the left one, and that is the
          // answer rather than a stuck control: a surface already more
          // legible than it promised is not a defect to correct.
          raised > ramp.legible ? _raisedLabel : _flooredLabel,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: context.caption.copyWith(color: context.inkTertiary),
        ),
      ],
    );
  }
}

/// **Why this one is painted rather than rendered as glass.**
///
/// `GlassLegibility` is arithmetic, not a widget: the WCAG 2.2 contrast
/// ratio, the source-over composite the compositor actually performs, and a
/// bisection that finds the least tint opacity reaching a target over a
/// known backdrop. Every tint step and every `minimumContrast` in this layer
/// is a claim evaluated by these three functions, and the package's own
/// tests re-derive the ramp's constants from them.
///
/// So the specimen is the arithmetic, made visible: the left swatch is the
/// composite at the floor the caller passed in, the right one is the
/// composite at the opacity [GlassLegibility.opacityForContrast] solved for.
/// Both are painted with the exact colour
/// [GlassLegibility.surfaceOver] returns, which is the colour a viewer sees
/// where that tint covers that photograph — so the contrast under each is
/// measured, not asserted.
///
/// The floor is `GlassTintStep.legible`, the bottom of the ramp, so the
/// solver has the most room to work in. Below the crossover it still has
/// nothing to do and returns that floor unchanged — which is not a stuck
/// knob but the rule itself: `opacityForContrast` never pushes tint *down*,
/// because a surface more legible than it promised is not a defect. The
/// caption under the swatches says which of the two is happening.
final CatalogueEntry _glassLegibility = CatalogueEntry(
  api: 'GlassLegibility',
  purpose:
      'The contrast arithmetic behind every tint promise — and the least '
      'tint that reaches a target over a known backdrop.',
  group: 'Design system',
  knobs: <Knob<Object?>>[
    // 3 to 7 is the whole span WCAG 2.2 gives a design system: 3:1 for
    // large text and UI components, 4.5:1 for body text, 7:1 for AAA and
    // for what Increase Contrast asks for.
    Knob<double>(name: 'target', value: 4.5, min: 3, max: 7),
  ],
  build: (knobs) => SizedBox(
    width: _panelWidth,
    height: _legibilityHeight,
    child: _LegibilityPanel(target: _asDouble(knobs[0])),
  ),
  code: (knobs) {
    final target = _asDouble(knobs[0]);
    final ramp = _tints.of(_adaptingScheme(_backdrop.panelBackdrop));
    final raised = GlassLegibility.opacityForContrast(
      tint: ramp.color,
      backdrop: _backdrop.panelBackdrop,
      label: ramp.label,
      target: target,
      floor: ramp.legible,
      ceiling: ramp.opaque,
    );
    final scheme = _adaptingScheme(_backdrop.panelBackdrop).name;
    return 'const backdrop = Color(${_hex(_backdrop.panelBackdrop)});\n'
        'const tints = GlassTints();\n'
        '\n'
        '// The scheme an adapting surface is stuck with: schemeFor\n'
        '// names the one that reads better, a flipping role takes it,\n'
        '// and a sheet or a card has to tint its way there instead.\n'
        'final ramp = tints.of(Brightness.$scheme);\n'
        '\n'
        'GlassLegibility.opacityForContrast(\n'
        '  tint: ramp.color,\n'
        '  backdrop: backdrop,\n'
        '  label: ramp.label,\n'
        '  target: ${target.toStringAsFixed(1)},\n'
        '  floor: ramp.legible, // ${ramp.legible}\n'
        '  ceiling: ramp.opaque, // ${ramp.opaque}\n'
        '); // ${raised.toStringAsFixed(3)}';
  },
  seeAlso: const <String>[
    'GlassTintStep',
    'GlassSurface',
    'GlassTokens',
    'GlassTintRamp',
  ],
);
