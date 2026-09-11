import 'package:glass_forge/glass_forge.dart';
import 'package:glass_forge_workbench/exports.dart';
import 'package:glass_forge_workbench/utils/widgets/glass/zones/glass_priority.dart';
import 'package:glass_forge_workbench/utils/widgets/glass/zones/kit_glass_layer.dart';
import 'package:glass_forge_workbench/utils/widgets/primitives/app_svg_icon.dart';
import 'package:glass_forge_workbench/utils/widgets/primitives/pressable_scale.dart';

/// A glass search capsule. Reports every edit, and offers a clear button
/// once there is something to clear.
class GlassSearchBar extends StatefulWidget {
  const GlassSearchBar({
    required this.hint,
    required this.clearLabel,
    required this.onChanged,
    this.value,
    this.material,
    super.key,
  });

  static const double height = 48;

  final String hint;

  /// The clear button's accessible label.
  final String clearLabel;
  final ValueChanged<String> onChanged;

  /// The query as its owner knows it. When it changes from outside — an
  /// empty state's "show everything" — the field follows. Null leaves the
  /// field to itself.
  final String? value;

  /// Null uses the house material.
  final GlassMaterial? material;

  @override
  State<GlassSearchBar> createState() => _GlassSearchBarState();
}

class _GlassSearchBarState extends State<GlassSearchBar> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.value,
  );
  final FocusNode _focus = FocusNode();

  @override
  void didUpdateWidget(GlassSearchBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    final value = widget.value;
    if (value != null && value != _controller.text) _controller.text = value;
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _clear() {
    _controller.clear();
    widget.onChanged('');
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: GlassSearchBar.height,
      child: KitGlassLayer(
        priority: GlassPriority.chrome,
        material: widget.material,
        shape: const GlassSuperellipse(
          radius: BorderRadius.all(Radius.circular(GlassSearchBar.height / 2)),
        ),
        child: ColoredBox(
          color: AppColors.glassChromeScrim,
          child: MediaQuery.withClampedTextScaling(
            maxScaleFactor: 1.3,
            child: Row(
              children: [
                const SizedBox(width: AppSpacing.s16),
                const AppSvgIcon(
                  AssetPaths.magnifyingGlass,
                  size: 20,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: AppSpacing.s12),
                Expanded(
                  child: TextField(
                    controller: _controller,
                    focusNode: _focus,
                    onChanged: widget.onChanged,
                    onTapOutside: (_) => _focus.unfocus(),
                    textInputAction: TextInputAction.search,
                    cursorColor: AppColors.accent,
                    style: context.body,
                    decoration: InputDecoration.collapsed(
                      hintText: widget.hint,
                      hintStyle: context.body.copyWith(
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ),
                ),
                ValueListenableBuilder<TextEditingValue>(
                  valueListenable: _controller,
                  builder: (context, value, _) => value.text.isEmpty
                      ? const SizedBox(width: AppSpacing.s16)
                      : PressableScale(
                          onTap: _clear,
                          semanticLabel: widget.clearLabel,
                          child: const SizedBox.square(
                            dimension: GlassSearchBar.height,
                            child: Center(
                              child: AppSvgIcon(
                                AssetPaths.x,
                                size: 18,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
