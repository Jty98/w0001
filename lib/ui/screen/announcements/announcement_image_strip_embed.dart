import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_quill_extensions/flutter_quill_extensions.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:w0001/ui/screen/announcements/worker_announcement_quill_codec.dart';
import 'package:w0001/ui/widget/network_image_viewer_sheet.dart';
import 'package:w0001/util/responsive_layout.dart';

/// 여러 장을 한 블록으로 묶어 저장한다. 표시는 카카오톡 다중 첨부형 콜라주.
enum AnnouncementImageStripMode {
  /// 카카오톡 채팅 다중 이미지처럼 한 덩어리 콜라주.
  grid,

  /// 이전 데이터 호환 — 표시는 [grid]와 동일.
  stack,
  carousel,
}

/// Quill 에 삽입하는 커스텀 블록 임베드 (`type` 과 JSON payload).
abstract final class AnnouncementImageStripEmbed {
  AnnouncementImageStripEmbed._();

  static const String type = 'w0001_images';

  static BlockEmbed create({
    required List<String> urls,
    AnnouncementImageStripMode mode = AnnouncementImageStripMode.grid,
  }) {
    final trimmed = urls
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList(growable: false);
    return BlockEmbed(
      type,
      jsonEncode(<String, Object?>{
        'urls': trimmed,
        'mode': mode.name,
      }),
    );
  }

  static AnnouncementImageStripData? tryParseEmbeddable(Embeddable e) {
    if (e.type != type) return null;
    final raw = e.data;
    if (raw is! String) return null;
    return AnnouncementImageStripData.tryParseJson(raw);
  }
}

final class AnnouncementImageStripData {
  const AnnouncementImageStripData({
    required this.urls,
    required this.mode,
  });

  final List<String> urls;
  final AnnouncementImageStripMode mode;

  static AnnouncementImageStripData? tryParseJson(String raw) {
    try {
      final m = jsonDecode(raw);
      if (m is! Map) return null;
      final urlsRaw = m['urls'];
      if (urlsRaw is! List) return null;
      final urls = urlsRaw
          .map((x) => x?.toString().trim() ?? '')
          .where((s) => s.isNotEmpty)
          .toList(growable: false);
      if (urls.isEmpty) return null;
      final modeName =
          (m['mode'] as String?) ?? AnnouncementImageStripMode.grid.name;
      var mode = AnnouncementImageStripMode.grid;
      for (final v in AnnouncementImageStripMode.values) {
        if (v.name == modeName) {
          mode = v;
          break;
        }
      }
      return AnnouncementImageStripData(urls: urls, mode: mode);
    } catch (_) {
      return null;
    }
  }
}

List<EmbedBuilder> announcementQuillEmbedBuilders({
  QuillEditorImageEmbedConfig imageEmbedConfig =
      const QuillEditorImageEmbedConfig(),
  QuillEditorVideoEmbedConfig? videoEmbedConfig,
}) =>
    <EmbedBuilder>[
      const AnnouncementImageStripEmbedBuilder(),
      ...FlutterQuillEmbeds.editorBuilders(
        imageEmbedConfig: imageEmbedConfig,
        videoEmbedConfig: videoEmbedConfig,
      ),
    ];

final class AnnouncementImageStripEmbedBuilder extends EmbedBuilder {
  const AnnouncementImageStripEmbedBuilder();

  @override
  String get key => AnnouncementImageStripEmbed.type;

  @override
  bool get expanded => false;

  @override
  Widget build(BuildContext context, EmbedContext embedContext) {
    final data = AnnouncementImageStripEmbed.tryParseEmbeddable(
      embedContext.node.value,
    );
    if (data == null || data.urls.isEmpty) {
      return const SizedBox.shrink();
    }
    return AnnouncementCollageImageStrip(urls: data.urls);
  }
}

/// 카카오톡 다중 이미지 첨부형 콜라주 + 탭 시 확대 뷰어.
class AnnouncementCollageImageStrip extends StatelessWidget {
  const AnnouncementCollageImageStrip({required this.urls});

  final List<String> urls;

  void _openViewer(BuildContext context, int index) {
    showNetworkImageViewerSheet(
      context,
      urls: urls,
      initialIndex: index,
    );
  }

  @override
  Widget build(BuildContext context) {
    final n = urls.length;
    if (n == 1) {
      return _CollageThumb(
        url: urls[0],
        onTap: () => _openViewer(context, 0),
        borderRadius: BorderRadius.circular(10),
      );
    }
    if (n == 2) {
      return AspectRatio(
        aspectRatio: 1.35,
        child: Row(
          children: [
            Expanded(
              child: _CollageThumb(
                url: urls[0],
                onTap: () => _openViewer(context, 0),
                borderRadius: const BorderRadius.horizontal(
                  left: Radius.circular(10),
                ),
              ),
            ),
            SizedBox(width: context.rsi(3)),
            Expanded(
              child: _CollageThumb(
                url: urls[1],
                onTap: () => _openViewer(context, 1),
                borderRadius: const BorderRadius.horizontal(
                  right: Radius.circular(10),
                ),
              ),
            ),
          ],
        ),
      );
    }
    if (n == 3) {
      return AspectRatio(
        aspectRatio: 1.25,
        child: Row(
          children: [
            Expanded(
              flex: 2,
              child: _CollageThumb(
                url: urls[0],
                onTap: () => _openViewer(context, 0),
                borderRadius: const BorderRadius.horizontal(
                  left: Radius.circular(10),
                ),
              ),
            ),
            SizedBox(width: context.rsi(3)),
            Expanded(
              child: Column(
                children: [
                  Expanded(
                    child: _CollageThumb(
                      url: urls[1],
                      onTap: () => _openViewer(context, 1),
                      borderRadius: const BorderRadius.only(
                        topRight: Radius.circular(10),
                      ),
                    ),
                  ),
                  SizedBox(height: context.rsi(3)),
                  Expanded(
                    child: _CollageThumb(
                      url: urls[2],
                      onTap: () => _openViewer(context, 2),
                      borderRadius: const BorderRadius.only(
                        bottomRight: Radius.circular(10),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    final show = n > 4 ? 4 : n;
    final extra = n - show;
    return AspectRatio(
      aspectRatio: 1,
      child: GridView.builder(
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: context.rsi(3),
          mainAxisSpacing: context.rsi(3),
        ),
        itemCount: show,
        itemBuilder: (context, i) {
          final isMore = extra > 0 && i == show - 1;
          return _CollageThumb(
            url: urls[i],
            onTap: () => _openViewer(context, i),
            borderRadius: BorderRadius.circular(8),
            overlayLabel: isMore ? '+$extra' : null,
          );
        },
      ),
    );
  }
}

class _CollageThumb extends StatelessWidget {
  const _CollageThumb({
    required this.url,
    required this.onTap,
    required this.borderRadius,
    this.overlayLabel,
  });

  final String url;
  final VoidCallback onTap;
  final BorderRadius borderRadius;
  final String? overlayLabel;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: borderRadius,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: borderRadius,
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
          ),
          child: ClipRRect(
            borderRadius: borderRadius,
            child: Stack(
              fit: StackFit.expand,
              children: [
                announcementEmbedImage(
                  url,
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, progress) {
                    if (progress == null) return child;
                    return Skeletonizer(
                      enabled: true,
                      child: ColoredBox(
                        color: Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest,
                        child: const Center(child: Text('…')),
                      ),
                    );
                  },
                  errorBuilder: (_, __, ___) => const Center(
                    child: Icon(Icons.broken_image_outlined),
                  ),
                ),
                if (overlayLabel != null)
                  ColoredBox(
                    color: Colors.black54,
                    child: Center(
                      child: Text(
                        overlayLabel!,
                        style:
                            Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
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

String _announcementNormalizeImageUrl(String url) {
  if (url.contains('base64')) {
    final parts = url.split(',');
    if (parts.length > 1) return parts[1];
  }
  return url;
}

/// Quill 단일 이미지·콜라주 썸네일 — 로컬 파일과 원격 URL 모두 표시.
Widget announcementEmbedImage(
  String url, {
  BoxFit fit = BoxFit.cover,
  ImageLoadingBuilder? loadingBuilder,
  ImageErrorWidgetBuilder? errorBuilder,
}) {
  if (WorkerAnnouncementQuillCodec.isLocalImageRef(url)) {
    final path = WorkerAnnouncementQuillCodec.localPathFromRef(url);
    return Image.file(
      File(path),
      fit: fit,
      errorBuilder: errorBuilder,
    );
  }
  final u = _announcementNormalizeImageUrl(url);
  return Image.network(
    u,
    fit: fit,
    loadingBuilder: loadingBuilder,
    errorBuilder: errorBuilder,
  );
}
