import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:glass_forge/glass_forge.dart';
import 'package:glass_forge_example/src/backdrop.dart';
import 'package:glass_forge_example/src/glyphs.dart';
import 'package:glass_forge_example/src/playground.dart';
import 'package:glass_forge_example/src/presets.dart';
import 'package:glass_forge_example/src/ui.dart';

/// A settings page built the way an app would build one: a
/// [GlassScaffold] with a [GlassAppBar] on top and a search field riding
/// the keyboard at the bottom, a list of controls in the body, and a
/// [showGlassSheet] for renaming.
///
/// Every control in the body shares the scaffold's body layer, which only
/// draws glass between the bars: scroll a switch under the app bar and it
/// is cut off at the bar's edge rather than stacked under its glass. Focus
/// a field and it scrolls clear of both the keyboard and the search bar
/// sitting on it.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _haptics = true;
  bool _sounds = false;
  double _glow = 0.6;
  int _density = 1;
  final TextEditingController _name = TextEditingController(
    text: 'Glass Forge',
  );

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _rename() async {
    final draft = TextEditingController(text: _name.text);
    final renamed = await showGlassSheet<String>(
      context: context,
      material: sheetMaterial,
      barrierLabel: 'Close rename',
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Rename', style: Font.title),
            const SizedBox(height: 14),
            GlassTextField(
              controller: draft,
              semanticLabel: 'Name',
              autofocus: true,
              textInputAction: TextInputAction.done,
              onSubmitted: (value) => Navigator.of(context).pop(value),
            ),
            const SizedBox(height: 14),
            GlassButton(
              onPressed: () => Navigator.of(context).pop(draft.text),
              child: const Text('Done', style: Font.title),
            ),
          ],
        ),
      ),
    );
    draft.dispose();
    if (renamed != null && mounted) {
      setState(() => _name.text = renamed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final photo = PlaygroundScope.of(context).photo;
    return GlassScaffold(
      background: Backdrop(photo: photo),
      topBar: GlassAppBar(
        material: chromeMaterial,
        leading: GlassButton.icon(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Glyph(Glyphs.back, size: 20),
          semanticLabel: 'Back',
        ),
        title: const Text('Settings', style: Font.title),
      ),
      bottomBar: const Padding(
        padding: EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: GlassTextField(
          placeholder: 'Search settings',
          textInputAction: TextInputAction.search,
        ),
      ),
      body: ListView(
        children: [
          const _Section('Feel'),
          _Row(
            label: 'Haptics',
            child: GlassSwitch(
              value: _haptics,
              semanticLabel: 'Haptics',
              onChanged: (v) {
                if (v) {
                  unawaited(HapticFeedback.selectionClick());
                }
                setState(() => _haptics = v);
              },
            ),
          ),
          _Row(
            label: 'Sounds',
            child: GlassSwitch(
              value: _sounds,
              semanticLabel: 'Sounds',
              onChanged: (v) => setState(() => _sounds = v),
            ),
          ),
          _Row(
            label: 'Glow',
            child: SizedBox(
              width: 180,
              child: GlassSlider(
                value: _glow,
                semanticLabel: 'Glow',
                semanticValueFormatter: (v) => '${(v * 100).round()}%',
                onChanged: (v) => setState(() => _glow = v),
              ),
            ),
          ),
          const _Section('Layout'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: GlassSegmentedControl<int>(
              semanticLabel: 'Density',
              segments: const [
                GlassSegment(value: 0, label: Text('Compact')),
                GlassSegment(value: 1, label: Text('Regular')),
                GlassSegment(value: 2, label: Text('Roomy')),
              ],
              selected: _density,
              onChanged: (v) => setState(() => _density = v),
            ),
          ),
          const _Section('Profile'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: GlassTextField(
              controller: _name,
              semanticLabel: 'Name',
              placeholder: 'Name',
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: GlassButton(
                onPressed: _rename,
                child: const Text('Rename in a sheet', style: Font.title),
              ),
            ),
          ),
          // Room to scroll the controls up under the app bar.
          const SizedBox(height: 480),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 4),
      child: Semantics(
        header: true,
        child: Text(title.toUpperCase(), style: Font.mono),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: ExcludeSemantics(child: Text(label, style: Font.title)),
          ),
          child,
        ],
      ),
    );
  }
}
