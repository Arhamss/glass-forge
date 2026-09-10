import 'package:glass_forge_benchmark/exports.dart';

class CustomDropdown extends StatelessWidget {
  const CustomDropdown({
    required this.labelText,
    required this.options,
    required this.onChanged,
    this.selectedValue,
    this.hintText,
    this.prefixIconPath,
    this.borderRadius = 100.0,
    this.maxHeight = 200.0,
    this.enabled = true,
    this.validator,
    this.showValidation = false,
    this.onTap,
    super.key,
  });

  final String labelText;
  final List<String> options;
  final void Function(String) onChanged;
  final String? selectedValue;
  final String? hintText;
  final String? prefixIconPath;
  final double borderRadius;
  final double maxHeight;
  final bool enabled;
  final String? Function(String?)? validator;
  final bool showValidation;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return FormField<String>(
      initialValue: selectedValue,
      validator: validator,
      builder: (FormFieldState<String> field) {
        return BlocProvider(
          create: (_) => CustomDropdownCubit(),
          child: _CustomDropdownContent(
            labelText: labelText,
            options: options,
            onChanged: (value) {
              field.didChange(value);
              onChanged(value);
            },
            selectedValue: selectedValue,
            hintText: hintText,
            prefixIconPath: prefixIconPath,
            borderRadius: borderRadius,
            maxHeight: maxHeight,
            enabled: enabled,
            validator: validator,
            showValidation: showValidation,
            onTap: onTap,
            formFieldState: field,
          ),
        );
      },
    );
  }
}

class _CustomDropdownContent extends StatefulWidget {
  const _CustomDropdownContent({
    required this.labelText,
    required this.options,
    required this.onChanged,
    this.selectedValue,
    this.hintText,
    this.prefixIconPath,
    this.borderRadius = 100.0,
    this.maxHeight = 200.0,
    this.enabled = true,
    this.validator,
    this.showValidation = false,
    this.onTap,
    this.formFieldState,
  });

  final String labelText;
  final List<String> options;
  final void Function(String) onChanged;
  final String? selectedValue;
  final String? hintText;
  final String? prefixIconPath;
  final double borderRadius;
  final double maxHeight;
  final bool enabled;
  final String? Function(String?)? validator;
  final bool showValidation;
  final VoidCallback? onTap;
  final FormFieldState<String>? formFieldState;

  @override
  State<_CustomDropdownContent> createState() => _CustomDropdownContentState();
}

class _CustomDropdownContentState extends State<_CustomDropdownContent> {
  final FocusNode _focusNode = FocusNode();
  final GlobalKey _dropdownKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChanged);

    // Initial validation if showValidation is true
    if (widget.showValidation && widget.validator != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _validateField(context.read<CustomDropdownCubit>());
        }
      });
    }
  }

  @override
  void dispose() {
    _focusNode
      ..removeListener(_onFocusChanged)
      ..dispose();
    super.dispose();
  }

  void _onFocusChanged() {
    if (!mounted) return;
    
    if (!_focusNode.hasFocus) {
      // Close dropdown when focus is lost (tapping outside)
      try {
        if (mounted) {
          context.read<CustomDropdownCubit>().closeDropdown();
        }
      } catch (e) {
        // Widget might be disposed, ignore
      }
    }
  }

  void _validateField(CustomDropdownCubit cubit) {
    if (!mounted) return;
    
    try {
      if (widget.validator != null && widget.showValidation) {
        final error = widget.validator!(widget.selectedValue);
        if (mounted) {
          cubit.setError(error);
        }
      } else {
        if (mounted) {
          cubit.clearError();
        }
      }
    } catch (e) {
      // Widget might be disposed, ignore
    }
  }

  void _selectOption(CustomDropdownCubit cubit, String option) {
    if (!mounted) return;
    
    try {
      // Call the onChanged callback first
      widget.onChanged(option);
      
      // Then close dropdown and validate, but only if still mounted
      if (mounted) {
        cubit.closeDropdown();
        _validateField(cubit);
      }
    } catch (e) {
      // Widget might be disposed during callback, ignore
    }
  }

  @override
  void didUpdateWidget(covariant _CustomDropdownContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Validate when showValidation changes from false to true
    if (widget.showValidation && !oldWidget.showValidation) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _validateField(context.read<CustomDropdownCubit>());
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CustomDropdownCubit, CustomDropdownState>(
      builder: (context, state) {
        final cubit = context.read<CustomDropdownCubit>();
        final hasValue =
            widget.selectedValue != null && widget.selectedValue!.isNotEmpty;
        final hasError = state.errorText != null;

        final borderColor = !widget.enabled
            ? AppColors.textTertiary
            : hasError
                ? AppColors.error
                : AppColors.textTertiary;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.labelText,
              style: context.p1Medium.copyWith(color: AppColors.primary),
            ),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: widget.enabled
                  ? () {
                      widget.onTap?.call();
                      // Always open the dropdown when tapped, regardless of current state
                      if (!state.isOpen) {
                        cubit.openDropdown();
                        _focusNode.requestFocus();
                      }
                    }
                  : null,
              child: Focus(
                focusNode: _focusNode,
                child: Container(
                  key: _dropdownKey,
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(
                      state.isOpen ? 16 : widget.borderRadius,
                    ),
                    border: Border.all(color: borderColor),
                  ),
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsetsDirectional.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        child: Row(
                          children: [
                            if (widget.prefixIconPath != null) ...[
                              SvgPicture.asset(
                                widget.prefixIconPath!,
                                width: 16,
                                colorFilter: ColorFilter.mode(
                                  widget.enabled
                                      ? AppColors.primary
                                      : AppColors.textTertiary,
                                  BlendMode.srcIn,
                                ),
                              ),
                              const SizedBox(width: 12),
                            ],
                            Expanded(
                              child: Text(
                                hasValue
                                    ? widget.selectedValue!
                                    : (widget.hintText ?? widget.labelText),
                                style: hasValue
                                    ? context.p2
                                    : context.p2.copyWith(
                                        color: AppColors.textSecondary,
                                      ),
                              ),
                            ),
                            AnimatedRotation(
                              turns: state.isOpen ? 0.5 : 0,
                              duration: const Duration(milliseconds: 200),
                              child: SvgPicture.asset(
                                AssetPaths.dropdownArrowIcon,
                                colorFilter: ColorFilter.mode(
                                  widget.enabled
                                      ? AppColors.primary
                                      : AppColors.textTertiary,
                                  BlendMode.srcIn,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (state.isOpen && widget.options.isNotEmpty) ...[
                        const Divider(
                          color: AppColors.textTertiary,
                          height: 1,
                          thickness: 1,
                        ),
                        Container(
                          constraints:
                              BoxConstraints(maxHeight: widget.maxHeight),
                          child: ListView.builder(
                            shrinkWrap: true,
                            padding: EdgeInsets.zero,
                            physics: const ClampingScrollPhysics(),
                            itemCount: widget.options.length,
                            itemBuilder: (context, index) {
                              final option = widget.options[index];
                              final isSelected = widget.selectedValue == option;

                              return _DropdownOptionTile(
                                option: option,
                                isSelected: isSelected,
                                onTap: () => _selectOption(cubit, option),
                              );
                            },
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            // Always reserve fixed space for error when field has validator so layout never shifts
            if (widget.validator != null)
              SizedBox(
                height: 24,
                child: widget.showValidation && hasError && state.errorText != null
                    ? Padding(
                        padding: const EdgeInsetsDirectional.only(top: 6, start: 12),
                        child: Text(
                          state.errorText!,
                          style: context.captionMedium.copyWith(
                            color: AppColors.error,
                            fontSize: 13,
                            height: 1.4,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
          ],
        );
      },
    );
  }
}

/// Single selectable row used inside dropdown option lists.
class _DropdownOptionTile extends StatelessWidget {
  const _DropdownOptionTile({
    required this.option,
    required this.isSelected,
    required this.onTap,
  });

  final String option;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                option,
                style: context.p2.copyWith(
                  color: AppColors.primary,
                  fontWeight:
                      isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ),
            if (isSelected)
              Container(
                padding: const EdgeInsets.all(2),
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
                child: SvgPicture.asset(
                  AssetPaths.tickIcon,
                  width: 14,
                  height: 14,
                  colorFilter: const ColorFilter.mode(
                    AppColors.surface,
                    BlendMode.srcIn,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
