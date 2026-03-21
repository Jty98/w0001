import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:w0001/data/model/place_info_model.dart';
import 'package:w0001/ui/screen/1_place/place_list_screen.dart';
import 'package:w0001/ui/screen/1_place/place_revenue_screen.dart';
import 'package:w0001/ui/screen/1_place/place_screen.dart';
import 'package:w0001/ui/screen/2_add/add_screen.dart';
import 'package:w0001/ui/screen/3_calendar/calendar_screen.dart';
import 'package:w0001/ui/screen/4_human/human_screen.dart';
import 'package:w0001/ui/screen/4_human/w_detail_screen.dart';
import 'package:w0001/ui/screen/4_human/work_cost_screen.dart';

final GlobalKey<NavigatorState> rootNavigatorKey =
    GlobalKey<NavigatorState>(debugLabel: 'root');

/// 앱 전역 [GoRouter]. [main]에서 한 번 생성해 [MaterialApp.router]에 연결합니다.
GoRouter createAppRouter() {
  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/place',
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return _MainShell(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/place',
                pageBuilder: (context, state) => const NoTransitionPage<void>(
                  key: ValueKey<String>('place'),
                  child: PlaceListScreen(),
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
                        child: PlaceScreen(placeInfo: extra),
                      );
                    },
                    routes: [
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
                      final rawName = state.uri.queryParameters['name'] ?? '';
                      final hname = rawName.isEmpty
                          ? ''
                          : Uri.decodeComponent(rawName);
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
      length: 4,
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
        height: 80,
        decoration: BoxDecoration(
          color: Colors.blueGrey.withValues(alpha: 0.15),
        ),
        child: TabBar(
          controller: _tabController,
          onTap: (index) {
            if (_programmaticTabUpdate) return;
            _shell.goBranch(
              index,
              initialLocation: index == _shell.currentIndex,
            );
          },
          tabAlignment: TabAlignment.fill,
          indicatorSize: TabBarIndicatorSize.tab,
          labelColor: Colors.black,
          unselectedLabelColor: const Color.fromARGB(255, 146, 146, 146),
          labelStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
          ),
          unselectedLabelStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.normal,
          ),
          tabs: const [
            Tab(
              icon: Icon(Icons.house, size: 30),
              text: '현장 관리',
            ),
            Tab(
              icon: Icon(Icons.add_circle, size: 30),
              text: '금액 추가',
            ),
            Tab(
              icon: Icon(Icons.calendar_month, size: 30),
              text: '캘린더',
            ),
            Tab(
              icon: Icon(Icons.person, size: 30),
              text: '인건비',
            ),
          ],
        ),
      ),
    );
  }
}
