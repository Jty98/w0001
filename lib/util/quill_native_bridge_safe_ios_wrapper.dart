import 'package:flutter/services.dart';
import 'package:quill_native_bridge_platform_interface/quill_native_bridge_platform_interface.dart';

/// `quill_native_bridge` Pigeon 채널이 준비되지 않았을 때(핫 리스타트 직후 등)
/// [PlatformException] / 채널 오류 시 크래시 대신 안전한 기본값으로 돌린다.
final class QuillNativeBridgeSafeIosWrapper extends QuillNativeBridgePlatform {
  QuillNativeBridgeSafeIosWrapper(this._inner);

  final QuillNativeBridgePlatform _inner;

  static bool _channelFailure(Object e) =>
      e is PlatformException ||
      e is MissingPluginException ||
      (e is Exception && e.toString().contains('channel-error'));

  static Future<R> _guard<R>(
    Future<R> Function() fn,
    R onChannelFail,
  ) async {
    try {
      return await fn();
    } catch (e) {
      if (_channelFailure(e)) return onChannelFail;
      rethrow;
    }
  }

  static Future<void> _guardVoid(Future<void> Function() fn) async {
    try {
      await fn();
    } catch (e) {
      if (_channelFailure(e)) return;
      rethrow;
    }
  }

  @override
  Future<bool> isIOSSimulator() => _guard(() => _inner.isIOSSimulator(), false);

  @override
  Future<bool> isSupported(QuillNativeBridgeFeature feature) =>
      _guard(() => _inner.isSupported(feature), false);

  @override
  Future<String?> getClipboardHtml() =>
      _guard(() => _inner.getClipboardHtml(), null);

  @override
  Future<void> copyHtmlToClipboard(String html) =>
      _guardVoid(() => _inner.copyHtmlToClipboard(html));

  @override
  Future<void> copyImageToClipboard(Uint8List imageBytes) =>
      _guardVoid(() => _inner.copyImageToClipboard(imageBytes));

  @override
  Future<Uint8List?> getClipboardImage() =>
      _guard(() => _inner.getClipboardImage(), null);

  @override
  Future<Uint8List?> getClipboardGif() =>
      _guard(() => _inner.getClipboardGif(), null);

  @override
  Future<List<String>> getClipboardFiles() =>
      _guard(() => _inner.getClipboardFiles(), const <String>[]);

  @override
  Future<void> openGalleryApp() => _guardVoid(() => _inner.openGalleryApp());

  @override
  Future<void> saveImageToGallery(
    Uint8List imageBytes, {
    required GalleryImageSaveOptions options,
  }) =>
      _guardVoid(
        () => _inner.saveImageToGallery(imageBytes, options: options),
      );

  @override
  Future<ImageSaveResult> saveImage(
    Uint8List imageBytes, {
    required ImageSaveOptions options,
  }) =>
      _guard(
        () => _inner.saveImage(imageBytes, options: options),
        ImageSaveResult.io(filePath: null),
      );

  @override
  bool isAppleSafari() {
    try {
      return _inner.isAppleSafari();
    } catch (e) {
      if (_channelFailure(e)) return false;
      rethrow;
    }
  }
}

/// 플러그인 등록 이후 호출해야 한다 (`WidgetsFlutterBinding.ensureInitialized()` 직후).
void installQuillNativeBridgeIosChannelFallback() {
  try {
    final current = QuillNativeBridgePlatform.instance;
    if (current is QuillNativeBridgeSafeIosWrapper) return;
    QuillNativeBridgePlatform.instance =
        QuillNativeBridgeSafeIosWrapper(current);
  } catch (_) {
    // 플러그인 미등록 등 — 무시
  }
}
