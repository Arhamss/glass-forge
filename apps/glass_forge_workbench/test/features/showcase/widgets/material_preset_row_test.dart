import 'package:flutter_test/flutter_test.dart';
import 'package:glass_forge/glass_forge.dart';
import 'package:glass_forge_workbench/exports.dart';
import 'package:glass_forge_workbench/features/showcase/presentation/widgets/instrument/material_preset_cell.dart';
import 'package:glass_forge_workbench/features/showcase/presentation/widgets/instrument/material_preset_row.dart';
import 'package:glass_forge_workbench/utils/helpers/demonstration_glass_material.dart';

Widget _row(GlassMaterial material, ValueChanged<GlassMaterial> onPicked) {
  return MaterialApp(
    home: Scaffold(
      body: Padding(
        padding: const EdgeInsetsDirectional.all(16),
        child: MaterialPresetRow(
          material: material,
          onPresetSelected: onPicked,
        ),
      ),
    ),
  );
}

bool _isSelected(WidgetTester tester, String label) => tester
    .widget<MaterialPresetCell>(
      find.ancestor(
        of: find.text(label),
        matching: find.byType(MaterialPresetCell),
      ),
    )
    .isSelected;

void main() {
  testWidgets('the Dome cell hands over the dome material', (tester) async {
    GlassMaterial? picked;
    await tester.pumpWidget(
      _row(demonstrationGlassMaterial(), (material) => picked = material),
    );

    await tester.tap(find.text('Dome'));
    expect(picked, GlassMaterial.dome());
    expect(picked!.profile, GlassProfile.dome);
  });

  testWidgets('the Dome cell, and only it, marks the dome as current', (
    tester,
  ) async {
    await tester.pumpWidget(_row(GlassMaterial.dome(), (_) {}));

    expect(_isSelected(tester, 'Dome'), isTrue);
    for (final label in <String>[
      'Demonstration',
      'Regular · Dark',
      'Regular · Light',
      'Clear',
    ]) {
      expect(_isSelected(tester, label), isFalse, reason: label);
    }
  });
}
