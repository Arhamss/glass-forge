import 'package:flutter/widgets.dart';
import 'package:glass_forge/glass_forge.dart';

/// Everything a screen needs to know about a backdrop before building glass
/// over it.
///
/// The photograph, the material the layer captures with, and the colour that
/// is actually behind the chrome at the bottom of the frame. That last one is
/// what turns adaptation on: `GlassSurface` will flip or thicken a surface to
/// keep its labels readable, but nothing in the package samples the backdrop
/// for you, so a value that knows what it put there says so.
@immutable
class BackdropInfo {
  const BackdropInfo({
    required this.photo,
    required this.panelBackdrop,
    required this.barBackdrop,
    required this.material,
  });

  /// The full-bleed photograph, painted behind the glass layer.
  final String photo;

  /// The mean colour under a control panel, measured off [photo].
  final Color panelBackdrop;

  /// The mean colour under a thin bar, measured off [photo].
  ///
  /// A second sample rather than one for the whole bottom of the frame: a
  /// panel and a bar can sit over different bands of the same picture, and
  /// on the dunes those bands are a shadowed trough and a sunlit crest.
  /// Averaging them together under-tints whichever surface is over the
  /// brighter one, which is exactly the surface that needed the tint.
  ///
  /// Both were measured over the strip each bar actually covers *after*
  /// `BoxFit.cover` has cropped the photograph — on a phone that keeps the
  /// middle 61% of these files' width — because the promise the tint ladder
  /// makes is a contrast number, and a number measured against pixels that
  /// are off-screen is fiction.
  final Color barBackdrop;

  /// What the layer captures with, and what every `Glass` under it inherits.
  final GlassMaterial material;
}

/// [backdrops], looked up by [BackdropInfo.photo] rather than a position in
/// the list.
///
/// A bare index drifts the moment a second caller wants the same backdrop:
/// nothing ties `backdrops[2]` to what the picture actually shows, where a
/// path is a name every caller can read and agree on.
BackdropInfo backdropFor(String photo) =>
    backdrops.firstWhere((backdrop) => backdrop.photo == photo);

/// The aurora crop behind the catalogue's own chrome.
///
/// The index and every entry page share this one photograph, so paging
/// between them never swaps out the picture underneath — only the glass
/// drawn over it changes, which is the whole point of the handoff.
const String catalogueBackdropPhoto = 'assets/images/northern_lights.jpg';

/// The five measured backdrops, one per photograph shipped with the example.
///
/// Photographs were generated for this project, so they ship with the
/// example rather than being fetched at run time. Each one was picked for
/// coarse structure — a ridge line, a painted terrace, a curtain of light. A
/// backdrop finer than the displacement is pushed through whole periods and
/// lands looking identical, and the glass then appears to do nothing.
final backdrops = <BackdropInfo>[
  BackdropInfo(
    photo: 'assets/images/desert_dunes.jpg',
    panelBackdrop: const Color(0xFF674339),
    barBackdrop: const Color(0xFF9E532C),
    material: GlassMaterial.dome(),
  ),
  BackdropInfo(
    photo: 'assets/images/coastal_town.jpg',
    panelBackdrop: const Color(0xFF3F4A4A),
    barBackdrop: const Color(0xFF424237),
    material: GlassMaterial.regular(brightness: Brightness.dark),
  ),
  BackdropInfo(
    photo: 'assets/images/northern_lights.jpg',
    panelBackdrop: const Color(0xFF29364C),
    barBackdrop: const Color(0xFF182831),
    material: GlassMaterial.dome(),
  ),
  BackdropInfo(
    photo: 'assets/images/tokyo_rain.jpg',
    panelBackdrop: const Color(0xFF482427),
    barBackdrop: const Color(0xFF56232A),
    material: GlassMaterial.dome(),
  ),
  BackdropInfo(
    photo: 'assets/images/alpine_lake.jpg',
    panelBackdrop: const Color(0xFF676664),
    barBackdrop: const Color(0xFF494A4D),
    material: GlassMaterial.regular(brightness: Brightness.dark),
  ),
];

/// [color] as the Dart literal a catalogue snippet would quote — the
/// `0xFF29364C` inside a `const Color(...)`.
///
/// Derived from the value rather than typed beside it. Every colour a
/// snippet prints comes out of [backdrops] or off the same photograph, and
/// a hand-written hex is one edit away from describing a picture nobody is
/// looking at. It lives here, with the colours, because the Adaptation,
/// Chrome and Design system groups each need it and each used to carry
/// their own copy of the same line.
String hexLiteral(Color color) =>
    '0x${color.toARGB32().toRadixString(16).toUpperCase().padLeft(8, '0')}';
