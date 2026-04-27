import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:w0001/data/model/place_info_model.dart';
import 'package:w0001/ui/screen/0_auth/login_screen.dart';
import 'package:w0001/ui/screen/0_auth/profile_screen.dart';
import 'package:w0001/ui/screen/1_dashboard/dashboard_screen.dart';
import 'package:w0001/ui/screen/1_dashboard/widgets/dashboard_schedule_section.dart';
import 'package:w0001/ui/screen/5_place/place_detail_screen.dart';
import 'package:w0001/ui/screen/5_place/place_images_screen.dart';
import 'package:w0001/ui/screen/2_add/add_screen.dart';
import 'package:w0001/ui/screen/3_calendar/calendar_screen.dart';
import 'package:w0001/ui/screen/4_human/human_screen.dart';
import 'package:w0001/ui/screen/4_human/w_detail_screen.dart';
import 'package:w0001/ui/screen/4_human/work_cost_screen.dart';
import 'package:w0001/ui/screen/5_place/place_screen.dart';
import 'package:w0001/ui/screen/5_place/place_revenue_screen.dart';
import 'package:w0001/ui/screen/5_place/place_cost_screen.dart';

final GlobalKey<NavigatorState> rootNavigatorKey =
    GlobalKey<NavigatorState>(debugLabel: 'root');

/// 앱 전역 [GoRouter]. [main]에서 한 번 생성해 [MaterialApp.router]에 연결합니다.
GoRouter createAppRouter() {
  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/login',
    routes: [
      // 로그인은 메인 쉘(하단 탭) 밖에서 전체 화면으로만 표시
      GoRoute(
        path: '/login',
        pageBuilder: (context, state) => const NoTransitionPage<void>(
          key: ValueKey<String>('login'),
          child: LoginScreen(),
        ),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return _MainShell(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/dashboard',
                pageBuilder: (context, state) => const NoTransitionPage<void>(
                  key: ValueKey<String>('dashboard'),
                  child: DashboardScreen(),
                ),
                routes: [
                  GoRoute(
                    path: 'profile',
                    pageBuilder: (context, state) => const NoTransitionPage<void>(
                      key: ValueKey<String>('profile'),
                      child: ProfileScreen(),
                    ),
                  ),
                  GoRoute(
                    path: 'schedule-full',
                    builder: (context, state) =>
                        const DashboardScheduleFullScreen(),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/place',
                pageBuilder: (context, state) => const NoTransitionPage<void>(
                  key: ValueKey<String>('place'),
                  child: PlaceScreen(),
                ),
                routes: [
                  GoRoute(
                    path: 'detail',
                    pageBuilder: (context, state) {
                      final extra = state.extra;
                      if (extra is! PlaceInfoModel) {
                        return const MaterialPage<void>(
                          child: Scaffold(
                            body: Center(child: Text('현장 정보가 없습니다.')),
                          ),
                        );
                      }
                      return MaterialPage<void>(
                        fullscreenDialog: true,
                        child: PlaceDetailScreen(placeInfo: extra),
                      );
                    },
                    routes: [
                      GoRoute(
                        path: 'cost',
                        builder: (context, state) {
                          final extra = state.extra;
                          if (extra is! PlaceInfoModel) {
                            return const Scaffold(
                              body: Center(child: Text('현장 정보가 없습니다.')),
                            );
                          }
                          return PlaceCostScreen(placeInfo: extra);
                        },
                      ),
                      GoRoute(
                        path: 'images',
                        builder: (context, state) {
                          final extra = state.extra;
                          if (extra is! PlaceInfoModel) {
                            return const Scaffold(
                              body: Center(child: Text('현장 정보가 없습니다.')),
                            );
                          }
                          return PlaceImagesScreen(placeInfo: extra);
                        },
                      ),
                      GoRoute(
                        path: 'revenue',
                        builder: (context, state) {
                          final extra = state.extra;
                          if (extra is! PlaceInfoModel) {
                            return const Scaffold(
                              body: Center(child: Text('현장 정보가 없습니다.')),
                            );
                          }
                          return PlaceRevenueScreen(placeInfo: extra);
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/add',
                pageBuilder: (context, state) => const NoTransitionPage<void>(
                  key: ValueKey<String>('add'),
                  child: AddScreen(),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/calendar',
                pageBuilder: (context, state) => const NoTransitionPage<void>(
                  key: ValueKey<String>('calendar'),
                  child: CalendarScreen(),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/work',
                pageBuilder: (context, state) => const NoTransitionPage<void>(
                  key: ValueKey<String>('work'),
                  child: WorkCostScreen(),
                ),
                routes: [
                  GoRoute(
                    path: 'human',
                    builder: (context, state) => const HumanScreen(),
                  ),
                  GoRoute(
                    path: 'detail/:hid',
                    builder: (context, state) {
                      final hidStr = state.pathParameters['hid']!;
                      final hid = int.parse(hidStr);
                      // go_router의 queryParameters는 이미 디코딩된 값입니다.
                      // (예: '%' 등이 포함된 이름을 decodeComponent로 다시 디코딩하면 예외가 날 수 있음)
                      final hname = state.uri.queryParameters['name'] ?? '';
                      return WorkCostDetailScreen(hid: hid, hname: hname);
                    },
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ],
  );
}

class _MainShell extends StatefulWidget {
  const _MainShell({required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  State<_MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<_MainShell>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  var _programmaticTabUpdate = false;

  StatefulNavigationShell get _shell => widget.navigationShell;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 5,
      vsync: this,
      initialIndex: _shell.currentIndex,
    );
  }

  @override
  void didUpdateWidget(covariant _MainShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_shell.currentIndex != _tabController.index) {
      _programmaticTabUpdate = true;
      _tabController.index = _shell.currentIndex;
      _programmaticTabUpdate = false;
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final bottomInset = media.padding.bottom;
    final w = media.size.width;
    // 화면 폭이 좁을수록 아이콘/텍스트를 줄여 잘림 방지
    final compact = w < 380;
    final labelFontSize = compact ? 12.0 : 13.0;
    // 기본 바 높이 + safe-area (기기별 홈 인디케이터 대응)
    final barHeight = (compact ? 64.0 : 70.0) + bottomInset;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(child: _shell),
            Divider(height: 0, color: Colors.grey[400]),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        height: barHeight,
        padding: EdgeInsets.only(bottom: bottomInset),
        decoration: BoxDecoration(
          color: Colors.blueGrey.withValues(alpha: 0.15),
        ),
        child: TabBar(
          controller: _tabController,
          // 아이콘/라벨 크기 기기별 대응
          labelStyle:
              TextStyle(fontSize: labelFontSize, fontWeight: FontWeight.bold),
          unselectedLabelStyle:
              TextStyle(fontSize: labelFontSize, fontWeight: FontWeight.normal),
          labelPadding: const EdgeInsets.only(top: 2, bottom: 6),
          // Tab 아이콘 테마를 강제해 const Tab에서 size 지정 제거
          indicatorPadding:
              const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
          overlayColor: WidgetStatePropertyAll(Colors.transparent),
          splashFactory: NoSplash.splashFactory,
          // IconTheme은 TabBar가 내부적으로 사용
          // ignore: deprecated_member_use_from_same_package
          // (IconThemeData는 여전히 정상 사용)
          // iconTheme는 3.22+에서 지원
          // 아래는 런타임/SDK에 따라 무시될 수 있음
          // 하지만 size는 Tab 아이콘에서 기본값보다 작게 유지됨
          onTap: (index) {
            if (_programmaticTabUpdate) return;
            HapticFeedback.selectionClick();
            _shell.goBranch(
              index,
              initialLocation: index == _shell.currentIndex,
            );
          },
          tabAlignment: TabAlignment.fill,
          indicatorSize: TabBarIndicatorSize.tab,
          labelColor: Colors.black,
          unselectedLabelColor: const Color.fromARGB(255, 146, 146, 146),
          // labelStyle/unselectedLabelStyle are set above
          tabs: const [
            Tab(
              // sizes are applied via IconTheme in TabBar parent
              icon: Icon(Icons.dashboard),
              text: '상황판',
            ),
            Tab(
              icon: Icon(Icons.house),
              text: '현장 관리',
            ),
            Tab(
              icon: Icon(Icons.add_circle),
              text: '금액 추가',
            ),
            Tab(
              icon: Icon(Icons.calendar_month),
              text: '캘린더',
            ),
            Tab(
              icon: Icon(Icons.person),
              text: '인건비',
            ),
          ],
        ),
      ),
    );
  }
}
