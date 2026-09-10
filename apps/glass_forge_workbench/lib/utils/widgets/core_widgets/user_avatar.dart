import 'package:glass_forge_workbench/exports.dart';

/// Decorative gradient pairs used by [UserAvatar]. The first entry is the
/// brand default (used when [UserAvatar.seed] is null); the remaining entries
/// are picked deterministically by `seed.hashCode`.
const _avatarGradients = <List<Color>>[
  [AppColors.primary, AppColors.overlayScrim],
  [Color(0xFFFE835F), Color(0xFFFF5668)],
  [Color(0xFFBC7AFA), Color(0xFFA84EFB)],
  [Color(0xFF9383FA), Color(0xFF7C69F9)],
  [Color(0xFFFFB367), Color(0xFFFF9831)],
  [Color(0xFF74BBFA), Color(0xFF3CA4FF)],
];

/// A circular user avatar with a gradient background.
///
/// When [seed] is provided (e.g. a member ID), a gradient is chosen
/// deterministically from [_avatarGradients]. When omitted,
/// the first gradient (brand primary) is used (for the current user's avatar).
///
/// Shows a cached network image if [imageUrl] is a valid absolute URL,
/// otherwise falls back to displaying [initial] text.
///
/// ```dart
/// UserAvatar(initial: 'A', size: 76)                          // own avatar (brand)
/// UserAvatar(initial: 'AH', size: 44, seed: member.id)        // other user (random gradient)
/// UserAvatar(initial: 'J', size: 32, seed: id, imageUrl: url) // with photo
/// UserAvatar(initial: 'A', isLoading: true)                    // uploading state
/// ```
class UserAvatar extends StatelessWidget {
  const UserAvatar({
    required this.initial,
    this.imageUrl,
    this.size = 76,
    this.seed,
    this.onTap,
    this.isLoading = false,
    super.key,
  });

  final String initial;
  final String? imageUrl;
  final double size;

  /// Deterministic seed for gradient selection (e.g. user/member ID).
  /// When null, defaults to the brand primary gradient.
  final String? seed;
  final VoidCallback? onTap;

  /// When true, shows a loading overlay and disables tap.
  final bool isLoading;

  static bool _isValidImageUrl(String? url) {
    if (url == null || url.isEmpty) return false;
    return url.startsWith('http://') || url.startsWith('https://');
  }

  List<Color> get _gradientColors {
    if (seed == null) {
      return _avatarGradients.first;
    }
    final index = seed.hashCode.abs() % _avatarGradients.length;
    return _avatarGradients[index];
  }

  @override
  Widget build(BuildContext context) {
    final hasImage = _isValidImageUrl(imageUrl);
    final gradient = _gradientColors;

    final avatar = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: gradient,
        ),
      ),
      alignment: Alignment.center,
      child: hasImage
          ? ClipOval(
              child: CustomCachedImageWidget(
                imageUrl: imageUrl!,
                width: size,
                height: size,
                errorFallback: Text(
                  initial,
                  style: _textStyle(context),
                ),
              ),
            )
          : Text(
              initial,
              style: _textStyle(context),
            ),
    );

    final content = isLoading
        ? Stack(
            children: [
              avatar,
              Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.overlayScrim.withValues(alpha: 0.4),
                ),
                alignment: Alignment.center,
                child: CustomLoadingWidget(
                  size: size * 0.35,
                  color: AppColors.surface,
                ),
              ),
            ],
          )
        : avatar;

    if (onTap != null && !isLoading) {
      return GestureDetector(onTap: onTap, child: content);
    }

    return content;
  }

  TextStyle _textStyle(BuildContext context) {
    if (size >= 64) {
      return context.h3Bold.copyWith(color: AppColors.textOnPrimary);
    }
    if (size >= 40) {
      return context.p1Medium.copyWith(
        color: AppColors.surface,
        fontWeight: FontWeight.w600,
      );
    }
    return context.p2.copyWith(
      color: AppColors.surface,
      fontWeight: FontWeight.w600,
      fontSize: 12,
    );
  }
}
