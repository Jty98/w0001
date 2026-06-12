import 'package:flutter/material.dart';

/// [MaterialApp.router]·FCM 스낵바용 전역 [ScaffoldMessenger].
final GlobalKey<ScaffoldMessengerState> appScaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>(debugLabel: 'appScaffoldMessenger');
