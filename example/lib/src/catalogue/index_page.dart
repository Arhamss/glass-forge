import 'package:flutter/material.dart' show Scaffold, showLicensePage;
import 'package:flutter/widgets.dart';
import 'package:glass_forge/glass_forge.dart';
import 'package:glass_forge_example/src/backdrop.dart';
import 'package:glass_forge_example/src/backdrop_info.dart';
import 'package:glass_forge_example/src/catalogue/catalogue.dart';
import 'package:glass_forge_example/src/catalogue/catalogue_entry.dart';
import 'package:glass_forge_example/src/catalogue/entry_page.dart';
import 'package:glass_forge_example/src/chrome.dart';
import 'package:glass_forge_example/src/theme.dart';

/// The catalogue's home: every entry, grouped, before any one of them is
/// opened.
///
/// **One `GlassLayer` for the whole page**, wrapping both the top bar and
/// every row below it. That single layer is also what makes the index
/// demonstrate `InteractiveGlass`'s touch glow rather than merely use it:
/// `GlassGlowScope` publishes one shared glow channel per `GlassLayer`
/// instance, and every `InteractiveGlass` beneath a layer — however many
/// rows there are — writes into that same instance. Splitting the rows
/// across two layers, or giving any row its own, would give each its own
/// channel and the glow would stop reaching a row's neighbours, which is
/// the one behaviour a bench of separately-pressable rows exists to show.
/// None of the rows declare a `material` of their own either, for the same
/// reason one layer per screen already gives for free: a shape with no
/// declared material inherits the layer's, and shapes sharing a material
/// share a backdrop pass — the touch glow and the backdrop capture both
/// stay singular by the same rule.
class CatalogueIndexPage extends StatelessWidget {
  /// Creates the index.
  const CatalogueIndexPage({super.key});

  /// The photograph and measured colours behind the index.
  ///
  /// Looked up by [catalogueBackdropPhoto] rather than a position in
  /// [backdrops] — the entry page is a second caller wanting the same
  /// crop, and a bare index invites the two to drift apart. `GlassSurface`
  /// cannot sample its own backdrop, so a page with a bar to keep readable
  /// needs a colour that was actually measured off what is behind it, and
  /// this is one of the five the example already has numbers for.
  static final BackdropInfo _backdrop = backdropFor(catalogueBackdropPhoto);

  /// The bar's own height, independent of the safe-area inset added to it
  /// at build time — see `_TopBar`.
  static const double _barContentHeight = 56;

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;
    final barHeight = topInset + _barContentHeight;

    // Driven by the covering route's own progress rather than any local
    // state: this page never has to know an entry was pushed, only that
    // `ModalRoute` says something now sits on top of it. See
    // `outgoingCataloguePresence` for why this ramp and the entry page's
    // incoming one never overlap.
    final covering = ModalRoute.of(context);
    final covered = covering?.secondaryAnimation ?? kAlwaysDismissedAnimation;

    // A Scaffold, for one reason: `MaterialApp` marks any text that is not
    // inside a `Material` with a debug underline, and every label on this
    // page is drawn straight onto glass or bare photograph.
    return Scaffold(
      backgroundColor: Tone.ground,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Backdrop(photo: _backdrop.photo),
          GlassLayer(
            material: _backdrop.material,
            child: GlassPresence(
              presence: outgoingCataloguePresence(covered),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: CustomScrollView(
                      slivers: [
                        SliverPadding(
                          padding: EdgeInsets.only(top: barHeight),
                        ),
                        for (final group in catalogueGroups) ...[
                          SliverToBoxAdapter(child: _GroupHeader(group)),
                          SliverList(
                            delegate: SliverChildListDelegate(
                              _rowsFor(entriesIn(group)),
                            ),
                          ),
                        ],
                        const SliverPadding(
                          padding: EdgeInsets.only(bottom: 24),
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    height: barHeight,
                    child: _TopBar(
                      backdrop: _backdrop.barBackdrop,
                      topInset: topInset,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// [entries], each followed by a hairline divider except the last.
  static List<Widget> _rowsFor(List<CatalogueEntry> entries) {
    final rows = <Widget>[];
    for (var i = 0; i < entries.length; i++) {
      rows.add(_EntryRow(entry: entries[i]));
      if (i != entries.length - 1) {
        rows.add(const _RowDivider());
      }
    }
    return rows;
  }
}

/// The glass bar pinned to the top of the frame, with content scrolling
/// behind it.
///
/// Edge-to-edge on purpose, covering the safe-area inset rather than
/// sitting below it: an inset told apart from the bar reads as a status-bar
/// gap above a floating pill, and the comp this implements draws the glass
/// running all the way to the top of the frame instead.
///
/// It carries the app's one trailing action, and it has to: `main()`
/// registers the Geist and Geist Mono OFL text with `LicenseRegistry`, and
/// registration alone only means `showLicensePage` *would* find the text.
/// The app bundles the fonts, so something on screen has to be able to
/// reach it, and the index's bar is the only chrome every reader passes
/// through. A trailing action beside a large title is the idiom the rest of
/// this bar is already borrowing.
class _TopBar extends StatelessWidget {
  const _TopBar({required this.backdrop, required this.topInset});

  /// The measured colour behind this bar.
  final Color backdrop;

  /// The safe-area inset the title is padded below.
  final double topInset;

  @override
  Widget build(BuildContext context) {
    return GlassSurface.navigationBar(
      backdrop: backdrop,
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, topInset + 12, 20, 12),
        child: Row(
          children: [
            Expanded(child: Text('Catalogue', style: context.display)),
            const SizedBox(width: 12),
            PillButton(
              label: 'Licences',
              // Flutter's own page, not one this example draws: it is
              // already the thing every `LicenseRegistry` entry in the
              // process shows up in, including Flutter's own, and an
              // example that hand-rolled a second licence screen would be
              // showing the reader less than the platform gives for free.
              onTap: () => showLicensePage(
                context: context,
                applicationName: 'glass_forge',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A group's name, in the small tracked caps the comp uses for it.
///
/// A bare `Text` here reads fine over the aurora but washes out over
/// sunlit ice — this header is a sibling `SliverToBoxAdapter`, undecorated
/// by whatever photograph scrolls beneath it, and its colour resolves
/// through [SurfaceInk] to [Tone.overPhoto] precisely because nothing set a
/// surface colour. `Tone.captionScrim` is this codebase's own prior art for
/// exactly this ("a strip painted inside a bare `Glass` to carry a
/// caption") — painted here rather than a second `Glass`, which would cost
/// an extra backdrop pass and could stack. Sized to the label, not the row:
/// an `Align` under `Padding`'s loose constraints keeps the scrim a tight
/// pill rather than a bar spanning the width.
class _GroupHeader extends StatelessWidget {
  const _GroupHeader(this.group);

  /// One of [catalogueGroups].
  final String group;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 10),
      child: Align(
        alignment: Alignment.centerLeft,
        child: DecoratedBox(
          decoration: const BoxDecoration(color: Tone.captionScrim),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            child: Text(
              group.toUpperCase(),
              style: context.caption.copyWith(
                color: context.inkTertiary,
                fontWeight: FontWeight.w600,
                letterSpacing: 1,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// One entry: its thumbnail, its API name and its purpose.
///
/// `InteractiveGlass`, not `Glass` — the row itself carries no glass of its
/// own to press. What it wraps is a painted line of text beside a small
/// live thumbnail, and pressing anywhere on that line still claims the
/// enclosing layer's one shared touch-glow channel, which is what lets a
/// press here light [entry]'s thumbnail *and* every other row's on screen
/// that is itself glass.
class _EntryRow extends StatelessWidget {
  const _EntryRow({required this.entry});

  /// What this row shows.
  final CatalogueEntry entry;

  static const double _thumbnailSize = 44;

  @override
  Widget build(BuildContext context) {
    return InteractiveGlass(
      onTap: () => Navigator.of(context).push(catalogueEntryRoute(entry)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.all(Radius.circular(10)),
              child: SizedBox(
                width: _thumbnailSize,
                height: _thumbnailSize,
                // `entry.build` sizes itself however its own specimen
                // does; `FittedBox` is what lets one fixed thumbnail slot
                // hold any of them without the row needing to know which.
                child: FittedBox(
                  fit: BoxFit.cover,
                  child: entry.build(entry.knobs),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.api,
                    style: context.mono.copyWith(color: context.ink),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    entry.purpose,
                    style: context.body.copyWith(
                      color: context.inkSecondary,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A thin separator between two rows in the same group.
///
/// Painted, not glass — a hairline this thin has nothing for a backdrop
/// filter to do, and giving it one would be a second surface for no
/// reason. Sits outside every `InteractiveGlass` row rather than inside
/// one, so it never takes part in that row's own press.
class _RowDivider extends StatelessWidget {
  const _RowDivider();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: SizedBox(
        height: 1,
        child: ColoredBox(color: context.inkHairline),
      ),
    );
  }
}
