import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

bool isHttpImageUrl(String url) =>
    url.startsWith('http://') || url.startsWith('https://');

/// 현장 사진·도면 썸네일 — 디스크 캐시 + [memCacheWidth] 로 디코드 비용 절감.
class PlaceNetworkImage extends StatelessWidget {
  const PlaceNetworkImage({
    super.key,
    required this.url,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.thumbCacheLogicalWidth,
    this.errorBuilder,
    this.placeholder,
    this.fadeIn = true,
  });

  final String url;
  final BoxFit fit;
  final double? width;
  final double? height;

  /// 그리드·목록 썸네일 너비(dp) — null이면 원본 해상도로 디코드.
  final double? thumbCacheLogicalWidth;
  final Widget Function(BuildContext)? errorBuilder;
  final Widget Function(BuildContext)? placeholder;
  final bool fadeIn;

  @override
  Widget build(BuildContext context) {
    if (!isHttpImageUrl(url)) {
      return errorBuilder?.call(context) ?? const SizedBox.shrink();
    }

    final cs = Theme.of(context).colorScheme;
    final memW = thumbCacheLogicalWidth == null
        ? null
        : (thumbCacheLogicalWidth! * MediaQuery.devicePixelRatioOf(context))
            .round();

    return CachedNetworkImage(
      imageUrl: url,
      fit: fit,
      width: width,
      height: height,
      memCacheWidth: memW,
      fadeInDuration:
          fadeIn ? const Duration(milliseconds: 120) : Duration.zero,
      placeholder: (_, __) =>
          placeholder?.call(context) ??
          ColoredBox(color: cs.surfaceContainerHighest),
      errorWidget: (_, __, ___) =>
          errorBuilder?.call(context) ??
          Icon(
            Icons.broken_image_outlined,
            color: cs.onSurfaceVariant,
          ),
    );
  }
}
