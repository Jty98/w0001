import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

enum PhoneMoSmsComposeResult {
  sent,
  cancelled,
  failed,
  unavailable,
  external,
}

/// MO 인증 문자 발송 — iOS는 앱 내 composer, Android는 문자 앱.
abstract final class PhoneMoSmsLauncher {
  static const _channel = MethodChannel('com.w0001/phone_mo_sms');

  static Future<PhoneMoSmsComposeResult> compose({
    required String moNumber,
    required String body,
  }) async {
    final digits = moNumber.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty || body.trim().isEmpty) {
      return PhoneMoSmsComposeResult.failed;
    }

    if (!kIsWeb && Platform.isIOS) {
      try {
        final raw = await _channel.invokeMethod<Object?>(
          'compose',
          <String, dynamic>{
            'recipients': <String>[digits],
            'body': body,
          },
        );
        if (raw is Map) {
          final status = raw['status']?.toString() ?? '';
          return switch (status) {
            'sent' => PhoneMoSmsComposeResult.sent,
            'cancelled' => PhoneMoSmsComposeResult.cancelled,
            'unavailable' => PhoneMoSmsComposeResult.unavailable,
            _ => PhoneMoSmsComposeResult.failed,
          };
        }
      } on PlatformException catch (e, st) {
        debugPrint('PhoneMoSmsLauncher iOS compose: $e\n$st');
      }
    }

    final uri = Uri(
      scheme: 'sms',
      path: digits,
      queryParameters: <String, String>{'body': body},
    );
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    return opened
        ? PhoneMoSmsComposeResult.external
        : PhoneMoSmsComposeResult.failed;
  }
}
