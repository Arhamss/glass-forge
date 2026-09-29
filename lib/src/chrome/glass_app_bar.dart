import 'package:flutter/widgets.dart';
import 'package:glass_forge/src/design/glass_surface.dart';
import 'package:glass_forge/src/material/glass_material.dart';
import 'package:glass_forge/src/widgets/glass_host_scope.dart';
import 'package:glass_forge/src/widgets/glass_presence.dart';

/// The bar's height, not counting the top safe-area inset above it.
const double _barHeight = 44;

/// The most the bar's content grows with the reader's text size.
///
/// The bar keeps iOS's fixed 44-point height, so a 17-point title has room
/// to grow to 1.5× (25.5 points) and no further; past that it would be cut
/// off. iOS itself does not scale navigation-bar titles at all. The same
/// policy as `GlassTabBar`'s labels.
const double _maxTextScale = 1.5;

/// Clear space kept between the bar's edges and its leading/title/actions.
const double _horizontalPadding = 16;

/// A top navigation bar: a leading widget, a title, and trailing actions,
/// on glass.
///
/// ```dart
/// GlassAppBar(
///   title: const Text('Messages'),
///   actions: [
///     GlassButton.icon(
///       onPressed: () {},
///       icon: const Icon(Icons.search),
///       semanticLabel: 'Search',
///     ),
///   ],
/// )
/// ```
///
/// The bar is a [GlassSurface.navigationBar] with the top safe-area inset
/// built in — without it, anything pinned to the top of an edge-to-edge
/// surface prints straight through the status bar's clock. [title] sits
/// centred on the bar, iOS style, as long as it fits between [leading] and
/// [actions]; an asymmetric pairing shifts it clear of whichever side is
/// wider rather than letting it overlap.
///
/// [leading], [title] and [actions] sit inside a [GlassHostScope], so a
/// `GlassButton.icon` action renders as paint rather than a second glass
/// stacked on this bar's — "always avoid glass on glass."
///
/// Its label colour and text style come from the resolved navigation-bar
/// surface's [DefaultTextStyle], never a hard-coded colour. Like every
/// [GlassSurface], it fades with the enclosing [GlassPresence] — a
/// `GlassScaffold`'s bar presence, usually — so covering the bar with a
/// route fades its title, leading and actions along with the glass beneath
/// them.
class GlassAppBar extends StatelessWidget {
  /// Creates an app bar.
  const GlassAppBar({
    this.leading,
    this.title,
    this.actions = const <Widget>[],
    this.backdrop,
    this.material,
    super.key,
  });

  /// Drawn at the bar's leading edge — a back button, a close button, and
  /// so on. Null leaves that edge empty.
  final Widget? leading;

  /// The bar's title.
  ///
  /// Centred on the bar as long as it fits clear of [leading] and
  /// [actions]; shifted toward [leading] only far enough to clear whichever
  /// side is wider. Null leaves the bar without one.
  final Widget? title;

  /// Drawn at the bar's trailing edge, in reading order. Under
  /// [TextDirection.rtl] the bar mirrors: [leading] is on the right and
  /// these on the left. Empty draws nothing.
  final List<Widget> actions;

  /// What is behind this bar, for the adaptation `GlassSurface` offers.
  final Color? backdrop;

  /// The bar's material, in place of the navigation-bar role's. Null keeps
  /// the role's; see [GlassSurface.material].
  final GlassMaterial? material;

  @override
  Widget build(BuildContext context) {
    final title = this.title;
    final toolbar = NavigationToolbar(
      leading: leading,
      // A header to a screen reader, so it can jump between the headings
      // of a screen the way it does on iOS.
      middle: title == null ? null : Semantics(header: true, child: title),
      trailing: actions.isEmpty
          ? null
          : Row(mainAxisSize: MainAxisSize.min, children: actions),
    );

    final content = GlassHostScope(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: _horizontalPadding,
        ),
        child: MediaQuery.withClampedTextScaling(
          maxScaleFactor: _maxTextScale,
          child: toolbar,
        ),
      ),
    );

    return SafeArea(
      bottom: false,
      left: false,
      right: false,
      child: SizedBox(
        height: _barHeight,
        child: GlassSurface.navigationBar(
          backdrop: backdrop,
          material: material,
          child: content,
        ),
      ),
    );
  }
}
