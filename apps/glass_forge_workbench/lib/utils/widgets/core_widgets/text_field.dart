import 'package:glass_forge_workbench/core/field_validators.dart';
import 'package:glass_forge_workbench/exports.dart';

/// Determines type-specific rendering (search prefix/suffix, password toggle,
/// keyboard action). Set automatically by named factories.
enum CustomTextFieldType { email, password, description, number, text, search }

/// A customizable text field with built-in support for common field types.
///
/// **Named factories** for common variants:
/// ```dart
/// CustomTextField.email(controller: _ctrl, hintText: 'Email')
/// CustomTextField.password(controller: _ctrl, hintText: 'Password')
/// CustomTextField.number(controller: _ctrl, hintText: 'Max players')
/// CustomTextField.phone(controller: _ctrl, hintText: 'Phone')
/// CustomTextField.description(controller: _ctrl, hintText: 'Bio')
/// CustomTextField.search(controller: _ctrl, onSearch: () => ...)
/// ```
///
/// **Base constructor** for one-off configurations:
/// ```dart
/// CustomTextField(
///   controller: _ctrl,
///   hintText: 'Notes',
///   config: TextFieldConfig(maxLines: 4, maxLength: 500),
/// )
/// ```
class CustomTextField extends StatefulWidget {
  const CustomTextField({
    required this.controller,
    this.type = CustomTextFieldType.text,
    this.config,
    this.padding = EdgeInsetsDirectional.zero,
    this.labelText,
    this.hintText,
    this.hintColor,
    this.validator,
    this.readOnly,
    this.onTap,
    this.onChanged,
    this.enabled = true,
    this.enableRealTimeValidation = true,
    this.showValidation = false,
    this.focusNode,
    this.prefix,
    this.suffix,
    this.suffixOnTap,
    this.backgroundColor,
    this.textStyle,
    this.textInputAction,
    this.onSearch,
    this.showFilterIcon = true,
    this.showSuffixAlways = false,
    this.filterCount,
    this.prefixOnTap,
    super.key,
  });

  /// Email field with [TextFieldConfig.email] and [FieldValidators.emailValidator].
  factory CustomTextField.email({
    required TextEditingController controller,
    String? labelText,
    String? hintText,
    String? Function(String?)? validator,
    EdgeInsetsGeometry padding = EdgeInsetsDirectional.zero,
    bool enabled = true,
    bool enableRealTimeValidation = false,
    FocusNode? focusNode,
    Widget? suffix,
    Color? backgroundColor,
    Key? key,
  }) {
    return CustomTextField(
      key: key,
      controller: controller,
      type: CustomTextFieldType.email,
      config: TextFieldConfig.email,
      labelText: labelText,
      hintText: hintText,
      validator: validator ?? FieldValidators.emailValidator,
      padding: padding,
      enabled: enabled,
      enableRealTimeValidation: enableRealTimeValidation,
      focusNode: focusNode,
      suffix: suffix,
      backgroundColor: backgroundColor,
    );
  }

  /// Password field with [TextFieldConfig.password] and eye-toggle suffix.
  factory CustomTextField.password({
    required TextEditingController controller,
    String? labelText,
    String? hintText,
    String? Function(String?)? validator,
    EdgeInsetsGeometry padding = EdgeInsetsDirectional.zero,
    bool enabled = true,
    FocusNode? focusNode,
    TextInputAction? textInputAction,
    Key? key,
  }) {
    return CustomTextField(
      key: key,
      controller: controller,
      type: CustomTextFieldType.password,
      config: TextFieldConfig.password,
      labelText: labelText,
      hintText: hintText,
      validator: validator ?? FieldValidators.passwordValidator,
      padding: padding,
      enabled: enabled,
      focusNode: focusNode,
      textInputAction: textInputAction,
    );
  }

  /// Numeric field with digits-only input and [FieldValidators.numberValidator].
  factory CustomTextField.number({
    required TextEditingController controller,
    String? labelText,
    String? hintText,
    String? Function(String?)? validator,
    Widget? suffix,
    EdgeInsetsGeometry padding = EdgeInsetsDirectional.zero,
    bool enabled = true,
    bool showValidation = false,
    FocusNode? focusNode,
    TextFieldConfig? config,
    Key? key,
  }) {
    return CustomTextField(
      key: key,
      controller: controller,
      type: CustomTextFieldType.number,
      config: config ?? TextFieldConfig.number,
      labelText: labelText,
      hintText: hintText,
      validator: validator ?? FieldValidators.numberValidator,
      suffix: suffix,
      padding: padding,
      enabled: enabled,
      showValidation: showValidation,
      focusNode: focusNode,
    );
  }

  /// Phone number field with [FieldValidators.phoneValidator].
  factory CustomTextField.phone({
    required TextEditingController controller,
    String? labelText,
    String? hintText,
    String? Function(String?)? validator,
    EdgeInsetsGeometry padding = EdgeInsetsDirectional.zero,
    bool enabled = true,
    bool enableRealTimeValidation = false,
    bool showValidation = false,
    FocusNode? focusNode,
    Widget? prefix,
    TextFieldConfig? config,
    Key? key,
  }) {
    return CustomTextField(
      key: key,
      controller: controller,
      type: CustomTextFieldType.number,
      config: config ?? TextFieldConfig.number,
      labelText: labelText,
      hintText: hintText,
      validator: validator ?? FieldValidators.phoneValidator,
      padding: padding,
      enabled: enabled,
      enableRealTimeValidation: enableRealTimeValidation,
      showValidation: showValidation,
      focusNode: focusNode,
      prefix: prefix,
    );
  }

  /// Multiline description field with [TextFieldConfig.description].
  factory CustomTextField.description({
    required TextEditingController controller,
    String? labelText,
    String? hintText,
    String? Function(String?)? validator,
    EdgeInsetsGeometry padding = EdgeInsetsDirectional.zero,
    bool enabled = true,
    bool showValidation = false,
    FocusNode? focusNode,
    Key? key,
  }) {
    return CustomTextField(
      key: key,
      controller: controller,
      type: CustomTextFieldType.description,
      config: TextFieldConfig.description,
      labelText: labelText,
      hintText: hintText,
      validator: validator ?? FieldValidators.textValidator,
      padding: padding,
      enabled: enabled,
      showValidation: showValidation,
      focusNode: focusNode,
    );
  }

  /// Search field with search icon prefix and filter icon suffix.
  factory CustomTextField.search({
    required TextEditingController controller,
    String? hintText,
    void Function(String)? onChanged,
    EdgeInsetsGeometry padding = EdgeInsetsDirectional.zero,
    bool enabled = true,
    FocusNode? focusNode,
    VoidCallback? suffixOnTap,
    VoidCallback? prefixOnTap,
    VoidCallback? onSearch,
    bool showSuffixAlways = false,
    int? filterCount,
    bool showFilterIcon = true,
    Key? key,
  }) {
    return CustomTextField(
      key: key,
      controller: controller,
      type: CustomTextFieldType.search,
      config: TextFieldConfig.search,
      hintText: hintText,
      onChanged: onChanged,
      padding: padding,
      enabled: enabled,
      focusNode: focusNode,
      suffixOnTap: suffixOnTap,
      prefixOnTap: prefixOnTap,
      onSearch: onSearch,
      showSuffixAlways: showSuffixAlways,
      filterCount: filterCount,
      showFilterIcon: showFilterIcon,
    );
  }

  final TextEditingController controller;
  final CustomTextFieldType type;
  final TextFieldConfig? config;
  final EdgeInsetsGeometry padding;
  final String? labelText;
  final String? hintText;
  final Color? hintColor;
  final String? Function(String?)? validator;
  final bool? readOnly;
  final VoidCallback? onTap;
  final void Function(String)? onChanged;
  final bool enabled;
  final bool enableRealTimeValidation;
  final bool showValidation;
  final FocusNode? focusNode;
  final Widget? prefix;
  final Widget? suffix;
  final VoidCallback? suffixOnTap;
  final Color? backgroundColor;
  final TextStyle? textStyle;
  final TextInputAction? textInputAction;

  final VoidCallback? onSearch;
  final bool showFilterIcon;
  final bool showSuffixAlways;
  final int? filterCount;
  final VoidCallback? prefixOnTap;

  @override
  State<CustomTextField> createState() => _CustomTextFieldState();
}

class _CustomTextFieldState extends State<CustomTextField> {
  late final FocusNode _focusNode;
  late final bool _isExternalFocusNode;
  bool _obscureText = true;

  @override
  void initState() {
    super.initState();
    _isExternalFocusNode = widget.focusNode != null;
    _focusNode = widget.focusNode ?? FocusNode();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_focusNode.hasFocus) {
        _focusNode.canRequestFocus = true;
      }
    });
  }

  @override
  void dispose() {
    if (!_isExternalFocusNode) {
      _focusNode.dispose();
    }
    super.dispose();
  }

  TextFieldConfig get _config {
    if (widget.config != null) return widget.config!;
    return switch (widget.type) {
      CustomTextFieldType.email => TextFieldConfig.email,
      CustomTextFieldType.password => TextFieldConfig.password,
      CustomTextFieldType.description => TextFieldConfig.description,
      CustomTextFieldType.number => TextFieldConfig.number,
      CustomTextFieldType.search => TextFieldConfig.search,
      CustomTextFieldType.text => TextFieldConfig.text,
    };
  }

  bool get _isSearch => widget.type == CustomTextFieldType.search;

  bool get _isPassword => widget.type == CustomTextFieldType.password;

  Widget? _buildPrefix() {
    if (widget.prefix != null) return widget.prefix;
    if (!_isSearch) return null;

    return GestureDetector(
      onTap: widget.prefixOnTap ?? widget.onSearch,
      child: Padding(
        padding: const EdgeInsetsDirectional.only(
          bottom: 8,
          top: 8,
          start: 16,
          end: 8,
        ),
        child: SvgPicture.asset(AssetPaths.searchIcon),
      ),
    );
  }

  Widget? _buildSuffix() {
    if (widget.suffix != null) return widget.suffix;

    if (_isSearch) {
      if (!widget.showFilterIcon) return null;
      return Visibility(
        visible: widget.showSuffixAlways || _focusNode.hasFocus,
        child: Padding(
          padding: const EdgeInsetsDirectional.only(
            start: 8,
            end: 22,
            top: 8,
            bottom: 8,
          ),
          child: CustomFilterIconWidget(filterCount: widget.filterCount),
        ),
      );
    }

    if (_isPassword) {
      return GestureDetector(
        onTap: () => setState(() => _obscureText = !_obscureText),
        child: Padding(
          padding: const EdgeInsetsDirectional.symmetric(horizontal: 12),
          child: Icon(
            _obscureText ? Icons.visibility_off : Icons.visibility,
            size: 20,
            color: AppColors.textSecondary,
          ),
        ),
      );
    }

    return null;
  }

  InputBorder _border(Color color) {
    return OutlineInputBorder(
      borderSide: BorderSide(color: color),
      borderRadius: BorderRadius.all(Radius.circular(_config.borderRadius)),
    );
  }

  InputBorder get _errorBorder => OutlineInputBorder(
    borderSide: const BorderSide(color: AppColors.error),
    borderRadius: BorderRadius.all(Radius.circular(_config.borderRadius)),
  );

  Color _borderColor({required bool hasFocus, required bool hasError}) {
    if (!widget.enabled) return AppColors.border;
    if (hasError) return AppColors.error;
    if (hasFocus) return AppColors.primary;
    return AppColors.border;
  }

  @override
  Widget build(BuildContext context) {
    final config = _config;

    return Padding(
      padding: widget.padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.labelText != null) ...[
            Text(
              widget.labelText!,
              style: context.p1Medium.copyWith(color: AppColors.primary),
            ),
            const SizedBox(height: 8),
          ],
          ListenableBuilder(
            listenable: Listenable.merge([_focusNode, widget.controller]),
            builder: (context, child) {
              final hasFocus = _focusNode.hasFocus;
              final validationError =
                  widget.showValidation && widget.validator != null
                  ? widget.validator!(widget.controller.text)
                  : null;
              final hasError =
                  validationError != null && validationError.isNotEmpty;

              final suffixWidget = _buildSuffix();

              return DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.all(
                    Radius.circular(config.borderRadius),
                  ),
                  boxShadow: hasFocus
                      ? [
                          BoxShadow(
                            color: AppColors.primary.withValues(
                              alpha: 0.15,
                            ),
                            blurRadius: 4,
                          ),
                        ]
                      : const [],
                ),
                child: TextFormField(
                  cursorWidth: 1.5,
                  cursorHeight: 22,
                  controller: widget.controller,
                  focusNode: _focusNode,
                  enabled: widget.enabled,
                  readOnly: widget.readOnly ?? false,
                  obscureText: config.obscureText && _obscureText,
                  obscuringCharacter: '*',
                  keyboardType: config.keyboardType,
                  textCapitalization:
                      config.keyboardType == TextInputType.emailAddress
                      ? TextCapitalization.none
                      : TextCapitalization.sentences,
                  textInputAction:
                      widget.textInputAction ??
                      config.textInputAction ??
                      (_isSearch
                          ? TextInputAction.search
                          : TextInputAction.done),
                  maxLines: config.maxLines,
                  maxLength: config.maxLength,
                  maxLengthEnforcement: MaxLengthEnforcement.enforced,
                  inputFormatters: config.inputFormatters,
                  style: widget.textStyle ?? context.p2,
                  cursorColor: AppColors.primary,
                  autovalidateMode:
                      (widget.enableRealTimeValidation && widget.showValidation)
                      ? AutovalidateMode.onUserInteraction
                      : AutovalidateMode.disabled,
                  onChanged: widget.onChanged,
                  onFieldSubmitted: _isSearch
                      ? (_) => widget.onSearch?.call()
                      : null,
                  validator: widget.validator,
                  decoration: InputDecoration(
                    hintText: widget.hintText,
                    filled: true,
                    fillColor: widget.backgroundColor ?? AppColors.surface,
                    hintStyle: context.p2.copyWith(
                      color: widget.hintColor ?? AppColors.textSecondary,
                    ),
                    counterText: '',
                    border: _border(
                      _borderColor(hasFocus: hasFocus, hasError: hasError),
                    ),
                    enabledBorder: _border(
                      _borderColor(hasFocus: hasFocus, hasError: hasError),
                    ),
                    disabledBorder: _border(AppColors.border),
                    focusedBorder: _border(
                      _borderColor(hasFocus: hasFocus, hasError: hasError),
                    ),
                    errorBorder: _errorBorder,
                    focusedErrorBorder: _errorBorder,
                    errorStyle: context.captionMedium.copyWith(
                      color: AppColors.error,
                    ),
                    prefixIcon: _buildPrefix(),
                    prefixIconConstraints: widget.prefix != null
                        ? const BoxConstraints()
                        : null,
                    suffixIcon: suffixWidget != null
                        ? GestureDetector(
                            onTap: widget.suffixOnTap,
                            child: suffixWidget,
                          )
                        : null,
                    contentPadding:
                        config.contentPadding ??
                        const EdgeInsetsDirectional.all(12),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

/// Configuration for text field styling and behavior.
///
/// Use the predefined static constants for common field types,
/// or create a custom instance for specialized configurations.
///
/// ```dart
/// // Predefined
/// CustomTextField(config: TextFieldConfig.number, ...)
///
/// // Custom
/// CustomTextField(config: TextFieldConfig(maxLines: 4, maxLength: 500), ...)
/// ```
class TextFieldConfig {
  const TextFieldConfig({
    this.maxLines = 1,
    this.maxLength = 100,
    this.keyboardType = TextInputType.text,
    this.textInputAction,
    this.obscureText = false,
    this.borderRadius = 12.0,
    this.contentPadding,
    this.inputFormatters,
  });

  final int maxLines;
  final int maxLength;
  final TextInputType keyboardType;
  final TextInputAction? textInputAction;
  final bool obscureText;
  final double borderRadius;
  final EdgeInsetsGeometry? contentPadding;
  final List<TextInputFormatter>? inputFormatters;

  static const TextFieldConfig email = TextFieldConfig(
    keyboardType: TextInputType.emailAddress,
  );

  static const TextFieldConfig password = TextFieldConfig(
    keyboardType: TextInputType.visiblePassword,
    obscureText: true,
  );

  static const TextFieldConfig description = TextFieldConfig(
    maxLines: 5,
    maxLength: 500,
    borderRadius: 18,
    keyboardType: TextInputType.multiline,
    textInputAction: TextInputAction.newline,
    contentPadding: EdgeInsetsDirectional.only(start: 16, top: 24),
  );

  static final TextFieldConfig number = TextFieldConfig(
    maxLength: 10,
    keyboardType: TextInputType.number,
    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
  );

  static const TextFieldConfig text = TextFieldConfig();

  static const TextFieldConfig search = TextFieldConfig();
}
