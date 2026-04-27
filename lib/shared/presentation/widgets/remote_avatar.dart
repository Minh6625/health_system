import 'package:flutter/material.dart';

import 'package:healthguard/shared/presentation/theme/app_colors.dart';

/// Circular avatar that loads a remote image with explicit loading and
/// error states. Falls back to either an initial-letter or an icon when
/// the URL is null, empty, or fails to load.
///
/// Replaces the bare `CircleAvatar(backgroundImage: NetworkImage(...))`
/// pattern which silently shows a blank circle on 4xx/5xx/timeout
/// responses (the user just sees no image and assumes the upload was
/// lost).
class RemoteAvatar extends StatelessWidget {
  /// Public image URL. When null, empty, or whitespace-only the
  /// fallback is rendered immediately without touching the network.
  final String? url;

  /// Circle radius in logical pixels. The image is rendered at
  /// `radius * 2` square and clipped to a circle.
  final double radius;

  /// Letter or short string shown when the image is unavailable.
  /// Typically the first letter of the user's display name.
  final String? fallbackText;

  /// Icon shown when `fallbackText` is null/empty.
  final IconData? fallbackIcon;

  final Color? backgroundColor;

  /// Color used for the fallback text/icon and the loading spinner.
  final Color? foregroundColor;

  /// Custom text style for the fallback letter. Defaults to a bold
  /// glyph sized relative to `radius`.
  final TextStyle? fallbackTextStyle;

  const RemoteAvatar({
    super.key,
    required this.url,
    required this.radius,
    this.fallbackText,
    this.fallbackIcon,
    this.backgroundColor,
    this.foregroundColor,
    this.fallbackTextStyle,
  }) : assert(
          fallbackText != null || fallbackIcon != null,
          'RemoteAvatar requires either fallbackText or fallbackIcon for the offline state',
        );

  @override
  Widget build(BuildContext context) {
    final trimmed = url?.trim();
    final hasUrl = trimmed != null && trimmed.isNotEmpty;
    final size = radius * 2;
    final bg = backgroundColor ?? AppColors.strokeSoft;

    if (!hasUrl) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: bg,
        child: _buildFallback(),
      );
    }

    return CircleAvatar(
      radius: radius,
      backgroundColor: bg,
      child: ClipOval(
        child: Image.network(
          trimmed,
          width: size,
          height: size,
          fit: BoxFit.cover,
          loadingBuilder: (context, child, progress) {
            if (progress == null) return child;
            return SizedBox(
              width: size,
              height: size,
              child: Center(
                child: SizedBox(
                  width: radius * 0.55,
                  height: radius * 0.55,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: foregroundColor ?? AppColors.brandPrimary,
                    value: progress.expectedTotalBytes != null
                        ? progress.cumulativeBytesLoaded /
                            progress.expectedTotalBytes!
                        : null,
                  ),
                ),
              ),
            );
          },
          errorBuilder: (context, error, stackTrace) => _buildFallback(),
        ),
      ),
    );
  }

  Widget _buildFallback() {
    if (fallbackText != null && fallbackText!.trim().isNotEmpty) {
      return Text(
        fallbackText!,
        style: fallbackTextStyle ??
            TextStyle(
              fontSize: radius * 0.8,
              fontWeight: FontWeight.bold,
              color: foregroundColor ?? AppColors.textSecondary,
            ),
      );
    }
    return Icon(
      fallbackIcon ?? Icons.person_outline_rounded,
      size: radius,
      color: foregroundColor ?? AppColors.textSecondary,
    );
  }
}
