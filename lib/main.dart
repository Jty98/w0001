import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:alarm/alarm.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:w0001/data/datasources/remote/http_client.dart';
import 'package:w0001/presentation/viewmodel/dashboard_schedule_view_model.dart';
import 'package:w0001/router/app_router.dart';
import 'package:w0001/ui/widget/alarm_ringing_overlay.dart';
import 'package:w0001/util/alarm_permission_helper.dart';
import 'package:w0001/util/auth_bootstrap.dart';
import 'package:w0001/util/fetch_data.dart';

late final GoRouter _appRouter;

Future<void> _initAlarmServicesSafely() async {
  try {
    await Alarm.init().timeout(const Duration(seconds: 4));
    await AlarmPermissionHelper.ensurePermissions()
        .timeout(const Duration(seconds: 4));
  } catch (e) {
    // 알람 초기화/권한 단계에서 실패하더라도 앱 본 기능은 계속 동작해야 한다.
    debugPrint('Alarm init skipped: $e');
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');
  await AppHttpClient.I.init();
  unawaited(_initAlarmServicesSafely());

  final container = ProviderContainer();
  rootProviderContainer = container;

  final restored =
      await tryRestoreSessionIfAutoLoginEnabled(container);
  _appRouter = createAppRouter(
    initialLocation: restored ? '/dashboard' : '/login',
  );

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
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  late final AlarmRingingOverlayController _alarmOverlayController;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _alarmOverlayController = AlarmRingingOverlayController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _alarmOverlayController.start();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    final container = rootProviderContainer;
    if (container == null) return;
    unawaited(
      container
          .read(dashboardScheduleProvider.notifier)
          .syncWidgetSnapshotNow(),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _alarmOverlayController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      routerConfig: _appRouter,
      builder: (context, child) => GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
        child: MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.noScaling,
          ),
          child: child!,
        ),
      ),
      title: 'Flutter Demo',
      theme: ThemeData(
        colorSchemeSeed: Colors.blue,
        // cardTheme: CardTheme(
        //   elevation: 0,
        //   shape: RoundedRectangleBorder(
        //     borderRadius: BorderRadius.circular(10),
        //     side: const BorderSide(
        //         width: 2, color: Color.fromARGB(255, 177, 176, 176)),
        //   ),
        // ),
        searchBarTheme: const SearchBarThemeData(
          elevation: WidgetStatePropertyAll(0),
          backgroundColor: WidgetStatePropertyAll(Colors.transparent),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              side: BorderSide(
                width: 2,
              ),
              borderRadius: BorderRadius.all(Radius.circular(10)),
            ),
          ),
        ),
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          toolbarHeight: 70,
        ),
        fontFamily: 'SCDream',
        // colorSchemeSeed: Colors.red,
        useMaterial3: true,
      ),
      debugShowCheckedModeBanner: false,
      locale: WidgetsBinding.instance.platformDispatcher.locale,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('ko', 'KR'), // 한국어
      ],
    );
  }
}
