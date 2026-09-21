import 'package:flutter/material.dart' show Icons;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:glass_forge_example/src/catalogue/catalogue_entry.dart';
import 'package:glass_forge_example/src/catalogue/snippet.dart';
import 'package:glass_forge_example/src/theme.dart';

/// The Dart that produced the live thing above it, painted rather than
/// glazed.
///
/// A second piece of glass on top of the first is the one composition this
/// renderer cannot draw — see `Tone.captionScrim`'s own doc comment — so
/// this panel is a plain `DecoratedBox` over [Tone.captionScrim], sitting
/// on bare photograph or on the page's own chrome, never on another piece
/// of glass. Its text reads [SurfaceInk.ink] rather than a literal colour,
/// which is what keeps it legible if a future caller ever sits it over a
/// surface that flipped schemes.
class SnippetView extends StatelessWidget {
  /// Creates a snippet view for [entry]'s current knobs.
  const SnippetView({required this.entry, super.key});

  /// The entry whose [renderSnippet] this shows.
  final CatalogueEntry entry;

  @override
  Widget build(BuildContext context) {
    final code = renderSnippet(entry);
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Tone.captionScrim,
        borderRadius: BorderRadius.all(Radius.circular(14)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                code,
                style: context.code.copyWith(color: context.ink),
              ),
            ),
            _CopyButton(code: code),
          ],
        ),
      ),
    );
  }
}

/// A small glyph that copies [code] to the clipboard, and says so briefly.
class _CopyButton extends StatefulWidget {
  const _CopyButton({required this.code});

  final String code;

  @override
  State<_CopyButton> createState() => _CopyButtonState();
}

class _CopyButtonState extends State<_CopyButton> {
  bool _copied = false;

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.code));
    if (!mounted) {
      return;
    }
    setState(() => _copied = true);
    Future<void>.delayed(const Duration(milliseconds: 1200), () {
      if (mounted) {
        setState(() => _copied = false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _copy,
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Icon(
          _copied ? Icons.check_rounded : Icons.copy_rounded,
          size: 16,
          color: context.inkSecondary,
        ),
      ),
    );
  }
}
