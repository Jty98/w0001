import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:kakao_flutter_sdk_navi/kakao_flutter_sdk_navi.dart';
import 'package:url_launcher/url_launcher.dart';

abstract final class MapNavigationLauncher {
  static Uri _androidStore(String pkg) => Uri.parse('market://details?id=$pkg');

  static final Uri _iosKakaoMapStore =
      Uri.parse('https://apps.apple.com/kr/app/id304608425');
  static final Uri _iosKakaoNaviStore = Uri.parse(
      'https://apps.apple.com/kr/search?term=%EC%B9%B4%EC%B9%B4%EC%98%A4%EB%82%B4%EB%B9%84');
  static final Uri _iosTmapStore =
      Uri.parse('https://apps.apple.com/kr/app/id431589174');

  static String _naviDebugMode() {
    final raw =
        (dotenv.env['kakao_navi_debug_mode'] ?? 'direct_then_sdk').trim();
    switch (raw) {
      case 'direct_only':
      case 'sdk_only':
      case 'sdk_api_only':
      case 'sdk_then_direct':
      case 'direct_then_sdk':
        return raw;
      default:
        return 'direct_then_sdk';
    }
  }

  static Future<bool> _tryDirectRouteUri({
    required String name,
    required String x,
    required String y,
  }) async {
    final directUri = Uri.parse(
      'kakaonavi://navigate?name=${Uri.encodeComponent(name)}&x=$x&y=$y&coord_type=wgs84',
    );
    debugPrint('[KakaoNavi] try direct URI: $directUri');
    if (await _tryLaunchExternal(directUri)) {
      debugPrint('[KakaoNavi] direct URI launch success');
      return true;
    }
    debugPrint('[KakaoNavi] direct URI launch failed');
    return false;
  }

  static Future<bool> _trySdkApiRoute({
    required String name,
    required String x,
    required String y,
  }) async {
    try {
      debugPrint('[KakaoNavi] try SDK API shareDestination (preview)');
      await NaviApi.instance.shareDestination(
        destination: Location(name: name, x: x, y: y),
        option: NaviOption(coordType: CoordType.wgs84),
      );
      debugPrint('[KakaoNavi] SDK API shareDestination success');
      return true;
    } catch (e) {
      debugPrint('[KakaoNavi] SDK API shareDestination failed: $e');
      return false;
    }
  }

  static Future<bool> openKakaoNaviRoute({
    required String destinationName,
    required double latitude,
    required double longitude,
  }) async {
    if (kIsWeb) return false;
    final name =
        destinationName.trim().isEmpty ? '목적지' : destinationName.trim();
    final x = longitude.toStringAsFixed(6);
    final y = latitude.toStringAsFixed(6);
    debugPrint(
      '[KakaoNavi] route request name="$name" x=$x y=$y',
    );
    final mode = _naviDebugMode();
    debugPrint('[KakaoNavi] debug_mode=$mode');
    if (mode == 'direct_only') {
      if (await _tryDirectRouteUri(name: name, x: x, y: y)) return true;
    } else if (mode == 'sdk_api_only') {
      if (await _trySdkApiRoute(name: name, x: x, y: y)) return true;
    } else if (mode == 'sdk_only') {
      // sdk_only는 "공식 SDK API만" 강제해 수동 URI(extras 누락) 변수를 제거한다.
      if (await _trySdkApiRoute(name: name, x: x, y: y)) return true;
    } else if (mode == 'sdk_then_direct') {
      if (await _trySdkApiRoute(name: name, x: x, y: y)) return true;
      if (await _tryDirectRouteUri(name: name, x: x, y: y)) return true;
    } else {
      if (await _tryDirectRouteUri(name: name, x: x, y: y)) return true;
      if (await _trySdkApiRoute(name: name, x: x, y: y)) return true;
    }

    final installed = await NaviApi.instance.isKakaoNaviInstalled();
    debugPrint('[KakaoNavi] isInstalled=$installed');
    if (!installed) {
      debugPrint('[KakaoNavi] app not installed -> open store');
      return _openKakaoNaviStore();
    }

    return false;
  }

  /// 좌표가 없는 화면(오늘 일정 등)에서는 카카오내비 검색을 먼저 시도하고,
  /// 실패하면 false를 반환한다.
  static Future<bool> openKakaoNaviSearch(String query) async {
    final q = query.trim();
    if (q.isEmpty) return false;
    debugPrint('[KakaoNavi] search request query="$q"');
    if (kIsWeb) return false;
    final installed = await NaviApi.instance.isKakaoNaviInstalled();
    debugPrint('[KakaoNavi] search isInstalled=$installed');
    if (installed) {
      final encoded = Uri.encodeComponent(q);
      final candidates = <Uri>[
        Uri.parse('kakaonavi://search?query=$encoded'),
        Uri.parse('kakaonavi://search?q=$encoded'),
        Uri.parse('kakaonavi://navigate?name=$encoded'),
      ];
      for (final appUri in candidates) {
        debugPrint('[KakaoNavi] try search URI: $appUri');
        if (await _tryLaunchExternal(appUri)) {
          debugPrint('[KakaoNavi] search URI launch success');
          return true;
        }
      }
      debugPrint('[KakaoNavi] search URI launch failed');
      return false;
    }
    debugPrint('[KakaoNavi] app not installed(search) -> open store');
    return _openKakaoNaviStore();
  }

  static Future<bool> openKakaoMapSearch(String query) async {
    final q = query.trim();
    if (q.isEmpty) return false;
    final appUri = Uri.parse('kakaomap://search?q=${Uri.encodeComponent(q)}');
    return _openExternalOrStore(
      appUri: appUri,
      openStore: _openKakaoMapStore,
    );
  }

  static Future<bool> openTmapSearch(String query) async {
    final q = query.trim();
    if (q.isEmpty) return false;
    final appUri = Uri.parse('tmap://search?name=${Uri.encodeComponent(q)}');
    return _openExternalOrStore(
      appUri: appUri,
      openStore: _openTmapStore,
    );
  }

  static Future<bool> _openExternalOrStore({
    required Uri appUri,
    required Future<bool> Function() openStore,
  }) async {
    return _openAnyExternalOrStore(
      appUris: <Uri>[appUri],
      openStore: openStore,
    );
  }

  static Future<bool> _openAnyExternalOrStore({
    required List<Uri> appUris,
    required Future<bool> Function() openStore,
  }) async {
    if (appUris.isEmpty) return openStore();

    for (final appUri in appUris) {
      if (await _tryLaunchExternal(appUri)) {
        return true;
      }
    }

    for (final appUri in appUris) {
      final installed = await _canLaunchExternal(appUri);
      if (installed && await _tryLaunchExternal(appUri)) {
        return true;
      }
    }

    return openStore();
  }

  static Future<bool> _canLaunchExternal(Uri uri) async {
    try {
      return await canLaunchUrl(uri);
    } catch (_) {
      return false;
    }
  }

  static Future<bool> _tryLaunchExternal(Uri uri) async {
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }

  static Future<bool> _openKakaoMapStore() async {
    if (kIsWeb) return false;
    if (Platform.isAndroid) {
      final market = _androidStore('net.daum.android.map');
      if (await canLaunchUrl(market)) {
        return launchUrl(market, mode: LaunchMode.externalApplication);
      }
      return launchUrl(
        Uri.parse(
          'https://play.google.com/store/apps/details?id=net.daum.android.map',
        ),
        mode: LaunchMode.externalApplication,
      );
    }
    if (Platform.isIOS) {
      return launchUrl(_iosKakaoMapStore, mode: LaunchMode.externalApplication);
    }
    return false;
  }

  static Future<bool> _openKakaoNaviStore() async {
    if (kIsWeb) return false;
    if (Platform.isAndroid) {
      return launchUrl(
        Uri.parse(NaviApi.webNaviInstall),
        mode: LaunchMode.externalApplication,
      );
    }
    if (Platform.isIOS) {
      return launchUrl(_iosKakaoNaviStore,
          mode: LaunchMode.externalApplication);
    }
    return false;
  }

  static Future<bool> _openTmapStore() async {
    if (kIsWeb) return false;
    if (Platform.isAndroid) {
      final market = _androidStore('com.skt.tmap.ku');
      if (await canLaunchUrl(market)) {
        return launchUrl(market, mode: LaunchMode.externalApplication);
      }
      return launchUrl(
        Uri.parse(
          'https://play.google.com/store/apps/details?id=com.skt.tmap.ku',
        ),
        mode: LaunchMode.externalApplication,
      );
    }
    if (Platform.isIOS) {
      return launchUrl(_iosTmapStore, mode: LaunchMode.externalApplication);
    }
    return false;
  }
}
