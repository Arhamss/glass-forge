import 'package:glass_forge_workbench/exports.dart';
import 'package:glass_forge_workbench/l10n/localization_service.dart';
import 'package:toastification/toastification.dart';

class ToastHelper {
  ToastHelper._();

  static const _toastDuration = Duration(seconds: 3);
  static const _toastIconSize = 24.0;
  static const _toastRadius = 48.0;

  static void _show({
    required ToastificationType type,
    required Color background,
    required String iconPath,
    required String message,
  }) {
    toastification.show(
      type: type,
      backgroundColor: background,
      borderRadius: BorderRadius.circular(_toastRadius),
      borderSide: BorderSide.none,
      closeButton: const ToastCloseButton(showType: CloseButtonShowType.none),
      icon: Padding(
        padding: const EdgeInsetsDirectional.only(start: 12, end: 8),
        child: SvgPicture.asset(
          iconPath,
          height: _toastIconSize,
          width: _toastIconSize,
          colorFilter: const ColorFilter.mode(AppColors.textOnPrimary, BlendMode.srcIn),
        ),
      ),
      title: Text(
        message,
        style: const TextStyle(
          fontFamily: AppFonts.body,
          fontWeight: FontWeight.w500,
          fontSize: 16,
          color: AppColors.textOnPrimary,
        ),
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
      ),
      autoCloseDuration: _toastDuration,
      alignment: Alignment.topCenter,
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: 12,
        vertical: 8,
      ),
      closeOnClick: true,
      pauseOnHover: true,
      dragToClose: true,
      showProgressBar: false,
    );
  }

  static void showErrorToast(String? message) {
    _show(
      type: ToastificationType.error,
      background: AppColors.error,
      iconPath: AssetPaths.errorIcon,
      message: message ?? Localization.somethingWentWrong,
    );
  }

  static void showSuccessToast(String message) {
    _show(
      type: ToastificationType.success,
      background: AppColors.success,
      iconPath: AssetPaths.successIcon,
      message: message,
    );
  }

  static void showInfoToast(String message) {
    _show(
      type: ToastificationType.info,
      background: AppColors.info,
      iconPath: AssetPaths.infoIcon,
      message: message,
    );
  }
}
