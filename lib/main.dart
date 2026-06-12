import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:alarm/alarm.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:w0001/data/datasources/remote/http_client.dart';
import 'package:w0001/access/user_role_access.dart';
import 'package:w0001/data/model/auth_models.dart';
import 'package:w0001/presentation/viewmodel/auth_providers.dart';
import 'package:w0001/presentation/viewmodel/dashboard_schedule_view_model.dart';
import 'package:w0001/presentation/viewmodel/theme_mode_providers.dart';
import 'package:w0001/navigation/app_router.dart';
import 'package:w0001/navigation/app_scaffold_messenger.dart';
import 'package:w0001/theme/app_theme.dart';
import 'package:w0001/util/responsive_layout.dart';
import 'package:w0001/ui/widget/alarm_ringing_overlay.dart';
import 'package:w0001/util/alarm_permission_helper.dart';
import 'package:w0001/util/schedule_alarm_services.dart';
import 'package:w0001/util/auth_bootstrap.dart';
import 'package:w0001/util/fetch_data.dart';
import 'package:w0001/util/quill_native_bridge_safe_ios_wrapper.dart';
import 'package:w0001/util/fcm/fcm_bootstrap.dart';
import 'package:w0001/util/worker_dashboard_refresh.dart';
import 'package:w0001/util/fcm/firebase_messaging_background.dart';
import 'package:w0001/firebase_options.dart';

late final GoRouter _appRouter;

Duration _alarmNativeSetupDefer() {
  if (kIsWeb) return Duration.zero;
  // 첫 프레임 직후 FCM requestPermission 과 겹치면 안드로이드에서 권한 UI·플러그인 채널이
  // 서로 막혀 Alarm.init 이 완료되지 않거나 터치가 먹지 않는 현상이 난다.
  return defaultTargetPlatform == TargetPlatform.android
      ? const Duration(milliseconds: 2400)
      : Duration.zero;
}

Future<void> _initAlarmServicesSafely() async {
  try {
    final initTimeout = (!kIsWeb &&
            defaultTargetPlatform == TargetPlatform.android)
        ? const Duration(seconds: 25)
        : const Duration(seconds: 8);
    await Alarm.init().timeout(initTimeout);
    await AlarmPermissionHelper.ensurePermissions()
        .timeout(const Duration(seconds: 45));
  } catch (e) {
    // 알람 초기화/권한 단계에서 실패하더라도 앱 본 기능은 계속 동작해야 한다.
    debugPrint('Alarm init skipped: $e');
  } finally {
    completeScheduleAlarmServicesReady();
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  installQuillNativeBridgeIosChannelFallback();
  await dotenv.load(fileName: '.env');
  await AppHttpClient.I.init();

  final container = ProviderContainer();
  rootProviderContainer = container;

  final restored = await tryRestoreSessionIfAutoLoginEnabled(container);
  final initialLocation = !restored ? '/login' : '/dashboard';
  _appRouter = createAppRouter(
    container: container,
    initialLocation: initialLocation,
  );
  bindAppGoRouter(_appRouter);
  
  // HTTP 클라이언트에 rootNavigatorKey 설정 (네트워크 오류 스낵바용)
  AppHttpClient.rootNavigatorKey = rootNavigatorKey;

  // landscpae 막기
  SystemChrome.setPreferredOrientations(
    [
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ],
  );
  runApp(
    UncontrolledProviderScope(
      container: container,
      child: MyApp(container: container),
    ),
  );
}

class MyApp extends StatefulWidget {
  const MyApp({super.key, required this.container});

  final ProviderContainer container;

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  late final AlarmRingingOverlayController _alarmOverlayController;
  late final ProviderSubscription<AsyncValue<UserRead?>> _authRouteRefreshSub;
  late final ProviderSubscription<AsyncValue<UserRead?>> _fcmAuthSessionSub;

  @override
  void initState() {
    super.initState();
    _fcmAuthSessionSub = attachFirebaseMessaging(widget.container);
    _authRouteRefreshSub = widget.container.listen<AsyncValue<UserRead?>>(
      authSessionProvider,
      (_, __) => _appRouter.refresh(),
    );
    WidgetsBinding.instance.addObserver(this);
    _alarmOverlayController = AlarmRingingOverlayController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _alarmOverlayController.start();
      final defer = _alarmNativeSetupDefer();
      Future<void>.delayed(defer, () {
        unawaited(_initAlarmServicesSafely());
      });
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    final container = rootProviderContainer;
    if (container == null) return;
    final u = container.read(authSessionProvider).asData?.value;
    if (u == null) return;
    if (u.isWorker) {
      scheduleWorkerPersonalDashboardReload(container);
      return;
    }
    unawaited(
      container
          .read(dashboardScheduleProvider.notifier)
          .syncWidgetSnapshotNow(),
    );
  }

  @override
  void dispose() {
    _fcmAuthSessionSub.close();
    _authRouteRefreshSub.close();
    WidgetsBinding.instance.removeObserver(this);
    _alarmOverlayController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, _) {
        final themeMode = ref.watch(themeModeProvider);
        
        return MaterialApp.router(
          scaffoldMessengerKey: appScaffoldMessengerKey,
          routerConfig: _appRouter,
          builder: (context, child) {
            final mq = MediaQuery.of(context);
            return GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
              child: MediaQuery(
                data: mq.copyWith(
                  textScaler: ResponsiveLayout.appTextScaler(mq),
                ),
                child: child!,
              ),
            );
          },
          title: '현장좋아',
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          themeMode: themeMode,
          debugShowCheckedModeBanner: false,
          locale: WidgetsBinding.instance.platformDispatcher.locale,
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
            FlutterQuillLocalizations.delegate,
          ],
          supportedLocales: const [
            Locale('ko', 'KR'), // 한국어
          ],
        );
      },
    );
  }
}
