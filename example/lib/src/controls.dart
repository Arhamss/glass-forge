import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:glass_forge_example/src/ui.dart';

/// A preset chip: white when chosen, a faint wash otherwise.
class PresetChip extends StatelessWidget {
  const PresetChip({
    required this.label,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final duration = motion(context, const Duration(milliseconds: 260));
    return Semantics(
      button: true,
      selected: selected,
      child: GestureDetector(
        onTap: () {
          unawaited(HapticFeedback.selectionClick());
          onTap();
        },
        child: AnimatedContainer(
          duration: duration,
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? const Color(0xF2FFFFFF) : Tone.wash,
            borderRadius: BorderRadius.circular(20),
          ),
          child: AnimatedDefaultTextStyle(
            duration: duration,
            style: Font.body.copyWith(
              color: selected ? Tone.ground : Tone.primary,
            ),
            child: Text(label),
          ),
        ),
      ),
    );
  }
}

/// A small caps heading for a group of controls.
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 22, 4, 10),
      child: Text(
        text.toUpperCase(),
        style: Font.mono.copyWith(letterSpacing: 1.2),
      ),
    );
  }
}
