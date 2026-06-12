import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

class AlarmPermissionHelper {
  static Future<void> ensurePermissions() async {
    if (kIsWeb) return;

    await _requestIfNeeded(Permission.notification);
    if (Platform.isAndroid) {
      await _requestIfNeeded(Permission.scheduleExactAlarm);
    }
  }

  static Future<void> _requestIfNeeded(Permission permission) async {
    final status = await permission.status;
    if (status.isGranted || status.isLimited || status.isProvisional) return;
    await permission.request();
  }
}
