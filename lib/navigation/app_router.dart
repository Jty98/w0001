import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:w0001/access/user_role_access.dart';
import 'package:w0001/data/model/auth_models.dart';
import 'package:w0001/data/model/place_info_model.dart';
import 'package:w0001/navigation/auth_redirect.dart';
import 'package:w0001/navigation/overlay_back_scope.dart';
import 'package:w0001/navigation/place_navigation.dart';
import 'package:w0001/navigation/shell_back_navigation.dart';
import 'package:w0001/navigation/shell_branch_mapping.dart';
import 'package:w0001/util/responsive_layout.dart';
import 'package:w0001/presentation/viewmodel/auth_providers.dart';
import 'package:w0001/presentation/viewmodel/dashboard_schedule_view_model.dart';
import 'package:w0001/util/fetch_data.dart';
import 'package:w0001/util/clear_user_providers.dart';
import 'package:w0001/ui/screen/0_auth/login_screen.dart';
import 'package:w0001/ui/screen/0_auth/pending_approval_screen.dart';
import 'package:w0001/ui/screen/0_auth/signup_screen.dart';
import 'package:w0001/ui/screen/0_auth/profile_screen.dart';
import 'package:w0001/ui/screen/0_auth/worker_private_info_screen.dart';
import 'package:w0001/ui/screen/0_auth/account_settings_screen.dart';
import 'package:w0001/ui/screen/0_auth/phone_setting_screen.dart';
import 'package:w0001/ui/screen/0_auth/notification_settings_screen.dart';
import 'package:w0001/ui/screen/0_auth/worker_earnings_screen.dart';
import 'package:w0001/ui/screen/0_auth/worker_more_screen.dart';
import 'package:w0001/ui/screen/0_auth/worker_settings_screen.dart';
import 'package:w0001/ui/screen/0_auth/operator_settings_screen.dart';
import 'package:w0001/ui/screen/0_auth/archived_places_management_screen.dart';
import 'package:w0001/ui/screen/0_auth/worker_profile_settings_screen.dart';
import 'package:w0001/ui/screen/0_auth/worker_mgmt/worker_mgmt_route_screens.dart';
import 'package:w0001/ui/screen/0_auth/worker_mgmt/worker_rank_wage_settings_screen.dart';
import 'package:w0001/ui/screen/1_dashboard/dashboard_screen.dart';
import 'package:w0001/ui/screen/1_dashboard/worker_personal_dashboard_screen.dart';
import 'package:w0001/ui/screen/1_dashboard/widgets/dashboard_schedule_section.dart';
import 'package:w0001/ui/screen/5_place/place_detail_screen.dart';
import 'package:w0001/ui/screen/5_place/place_images_screen.dart';
import 'package:w0001/ui/screen/3_calendar/calendar_branch_screen.dart';
import 'package:w0001/ui/screen/4_human/human_screen.dart';
import 'package:w0001/ui/screen/4_human/w_detail_screen.dart';
import 'package:w0001/ui/screen/4_human/work_cost_screen.dart';
import 'package:w0001/ui/screen/4_human/worker_work_cost_items_screen.dart';
import 'package:w0001/ui/screen/4_human/work_cost_human_key_codec.dart';
import 'package:w0001/ui/screen/5_place/place_screen.dart';
import 'package:w0001/ui/screen/2_work_instruction/work_instruction_hub_screen.dart';
import 'package:w0001/ui/screen/5_place/place_revenue_screen.dart';
import 'package:w0001/ui/screen/5_place/place_cost_screen.dart';
import 'package:w0001/ui/screen/5_place/place_process_schedule_screen.dart';
import 'package:w0001/ui/screen/5_place/place_checklist_screen.dart';
import 'package:w0001/ui/screen/5_place/place_workforce_screen.dart';
import 'package:w0001/ui/screen/5_place/place_members_screen.dart';
import 'package:w0001/ui/screen/announcements/admin_worker_announcement_edit_screen.dart';
import 'package:w0001/ui/screen/announcements/admin_worker_announcements_list_screen.dart';
import 'package:w0001/ui/screen/announcements/place_worker_announcements_screen.dart';
import 'package:w0001/ui/screen/announcements/worker_announcement_detail_screen.dart';
import 'package:w0001/ui/screen/announcements/worker_announcements_inbox_screen.dart';
import 'package:w0001/ui/screen/extras/daily_quote_management_screen.dart';
import 'package:w0001/ui/screen/extras/field_knowledge_management_hub_screen.dart';
import 'package:w0001/ui/screen/extras/vendor_phone_directory_screen.dart';
import 'package:w0001/ui/screen/extras/worker_field_knowledge_hub_screen.dart';
import 'package:w0001/ui/screen/maps/worker_supply_map_screen.dart';
import 'package:w0001/ui/screen/notifications/notification_inbox_screen.dart';
import 'package:w0001/ui/widget/hammer_loading_indicator.dart';
import 'package:w0001/ui/widget/stacked_toast_overlay.dart';
import 'package:w0001/ui/screen/0_auth/super_admin_profile/member_queue_screen.dart';
import 'package:w0001/data/model/worker_announcement_models.dart';

final GlobalKey<NavigatorState> rootNavigatorKey =
    GlobalKey<NavigatorState>(debugLabel: 'root');

GoRouter? _boundAppGoRouter;

/// [main]에서 [GoRouter] 생성 직후 한 번 호출 — FCM 등 [BuildContext] 없이 라우팅할 때 사용.
void bindAppGoRouter(GoRouter router) {
  _boundAppGoRouter = router;
}

/// [bindAppGoRouter]로 연결된 라우터. 아직 바인딩 전이면 `null`.
GoRouter? get appBoundGoRouter => _boundAppGoRouter;

/// 앱 전역 [GoRouter]. [main]에서 한 번 생성해 [MaterialApp.router]에 연결합니다.
///
/// [initialLocation]은 [tryRestoreSessionIfAutoLoginEnabled] 성공 시 역할에 맞는 홈으로 둡니다.
GoRouter createAppRouter({
  required ProviderContainer container,
  String initialLocation = '/login',
}) {
  return GoRouter(
    navigatorKey: rootNavigatorKey,
    observers: [StackedToastNavigatorObserver()],
    initialLocation: initialLocation,
    redirect: (context, state) => authRedirect(container, state),
    routes: [
      // 로그인은 메인 쉘(하단 탭) 밖에서 전체 화면으로만 표시
      GoRoute(
        path: '/login',
        pageBuilder: (context, state) => const NoTransitionPage<void>(
          key: ValueKey<String>('login'),
          child: LoginScreen(),
        ),
      ),
      GoRoute(
        path: '/signup',
        pageBuilder: (context, state) => const NoTransitionPage<void>(
          key: ValueKey<String>('signup'),
          child: SignupScreen(),
        ),
      ),
      GoRoute(
        path: '/pending-approval',
        pageBuilder: (context, state) => const NoTransitionPage<void>(
          key: ValueKey<String>('pending-approval'),
          child: PendingApprovalScreen(),
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
                pageBuilder: (context, state) => NoTransitionPage<void>(
                  key: const ValueKey<String>('dashboard'),
                  child: ShellTabRootBackScope(
                    shellBranchIndex: 0,
                    child: Consumer(
                      builder: (context, ref, _) {
                        final session = ref.watch(authSessionProvider);
                        // loading 중 관리자 UI를 띄우면 KPI·일정 provider가 빈 세션으로
                        // 생성된 뒤 재조회가 건너뛰어질 수 있다(안드로이드에서 자주 재현).
                        return session.when(
                          loading: () => const Scaffold(
                            body: Center(
                              child: HammerLoadingIndicator(
                                size: 106,
                                label: '대시보드 준비 중...',
                              ),
                            ),
                          ),
                          error: (_, __) => const DashboardScreen(),
                          data: (u) => (u?.isWorker ?? false)
                              ? const WorkerPersonalDashboardScreen()
                              : const DashboardScreen(),
                        );
                      },
                    ),
                  ),
                ),
                routes: [
                  GoRoute(
                    path: 'profile',
                    pageBuilder: (context, state) =>
                        const NoTransitionPage<void>(
                      key: ValueKey<String>('profile'),
                      child: ProfileScreen(),
                    ),
                  ),
                  GoRoute(
                    path: 'notifications',
                    parentNavigatorKey: rootNavigatorKey,
                    pageBuilder: (context, state) => materialOverlayPage(
                      state: state,
                      child: const NotificationInboxScreen(),
                    ),
                  ),
                  GoRoute(
                    path: 'member-queue',
                    parentNavigatorKey: rootNavigatorKey,
                    pageBuilder: (context, state) => materialOverlayPage(
                      state: state,
                      child: const MemberQueueScreen(),
                    ),
                  ),
                  GoRoute(
                    path: 'worker-mgmt/memos',
                    parentNavigatorKey: rootNavigatorKey,
                    builder: (context, state) =>
                        const WorkerMgmtMemosHubScreen(),
                  ),
                  GoRoute(
                    path: 'worker-mgmt/troubles',
                    parentNavigatorKey: rootNavigatorKey,
                    builder: (context, state) =>
                        const WorkerMgmtTroublesHubScreen(),
                  ),
                  GoRoute(
                    path: 'worker-mgmt/rank-wages',
                    parentNavigatorKey: rootNavigatorKey,
                    builder: (context, state) =>
                        const WorkerRankWageSettingsScreen(),
                  ),
                  GoRoute(
                    path: 'worker-announcements',
                    parentNavigatorKey: rootNavigatorKey,
                    builder: (context, state) =>
                        const AdminWorkerAnnouncementsListScreen(),
                    routes: [
                      GoRoute(
                        path: 'edit',
                        parentNavigatorKey: rootNavigatorKey,
                        builder: (context, state) {
                          final extra = state.extra;
                          WorkerAnnouncementRead? existing;
                          PlaceAnnouncementEditAnchor? placeAnchor;
                          if (extra is AdminWorkerAnnouncementEditExtra) {
                            existing = extra.existing;
                            placeAnchor = extra.placeAnchor;
                          } else if (extra is WorkerAnnouncementRead) {
                            existing = extra;
                          }
                          return AdminWorkerAnnouncementEditScreen(
                            existing: existing,
                            placeAnchor: placeAnchor,
                          );
                        },
                      ),
                    ],
                  ),
                  GoRoute(
                    path: 'extras/daily-quotes',
                    parentNavigatorKey: rootNavigatorKey,
                    pageBuilder: (context, state) => materialOverlayPage(
                      state: state,
                      child: const DailyQuoteManagementScreen(),
                    ),
                  ),
                  GoRoute(
                    path: 'extras/knowledge',
                    parentNavigatorKey: rootNavigatorKey,
                    pageBuilder: (context, state) => materialOverlayPage(
                      state: state,
                      child: const FieldKnowledgeManagementHubScreen(),
                    ),
                  ),
                  GoRoute(
                    path: 'extras/vendor-phones',
                    parentNavigatorKey: rootNavigatorKey,
                    pageBuilder: (context, state) => materialOverlayPage(
                      state: state,
                      child: const VendorPhoneDirectoryScreen(),
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
                  child: ShellTabRootBackScope(
                    shellBranchIndex: 1,
                    child: PlaceScreen(),
                  ),
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
                        key: state.pageKey,
                        child: PlaceRouteBackScope(
                          child: PlaceDetailScreen(placeInfo: extra),
                        ),
                      );
                    },
                    routes: [
                      GoRoute(
                        path: 'cost',
                        pageBuilder: (context, state) {
                          final extra = state.extra;
                          if (extra is! PlaceInfoModel) {
                            return placeBranchSubPage(
                              state: state,
                              child: const Scaffold(
                                body: Center(child: Text('현장 정보가 없습니다.')),
                              ),
                            );
                          }
                          return placeBranchSubPage(
                            state: state,
                            child: Consumer(
                              builder: (context, ref, _) {
                                final worker = ref
                                        .watch(authSessionProvider)
                                        .asData
                                        ?.value
                                        ?.isWorker ??
                                    false;
                                if (worker) {
                                  return Scaffold(
                                    appBar: AppBar(
                                      title: const Text('현장 금액관리'),
                                    ),
                                    body: Center(
                                      child: Padding(
                                        padding: const EdgeInsets.all(24),
                                        child: Text(
                                          '작업자 계정에서는 현장 금액관리를 이용할 수 없습니다.',
                                          textAlign: TextAlign.center,
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodyLarge,
                                        ),
                                      ),
                                    ),
                                  );
                                }
                                return PlaceCostScreen(placeInfo: extra);
                              },
                            ),
                          );
                        },
                      ),
                      GoRoute(
                        path: 'images',
                        pageBuilder: (context, state) {
                          final extra = state.extra;
                          if (extra is! PlaceInfoModel) {
                            return placeBranchSubPage(
                              state: state,
                              child: const Scaffold(
                                body: Center(child: Text('현장 정보가 없습니다.')),
                              ),
                            );
                          }
                          return placeBranchSubPage(
                            state: state,
                            child: PlaceImagesScreen(placeInfo: extra),
                          );
                        },
                      ),
                      GoRoute(
                        path: 'revenue',
                        pageBuilder: (context, state) {
                          final extra = state.extra;
                          if (extra is! PlaceInfoModel) {
                            return placeBranchSubPage(
                              state: state,
                              child: const Scaffold(
                                body: Center(child: Text('현장 정보가 없습니다.')),
                              ),
                            );
                          }
                          return placeBranchSubPage(
                            state: state,
                            child: PlaceRevenueScreen(placeInfo: extra),
                          );
                        },
                      ),
                      GoRoute(
                        path: 'process-schedule',
                        pageBuilder: (context, state) {
                          final extra = state.extra;
                          if (extra is! PlaceInfoModel) {
                            return placeBranchSubPage(
                              state: state,
                              child: const Scaffold(
                                body: Center(child: Text('현장 정보가 없습니다.')),
                              ),
                            );
                          }
                          return MaterialPage<void>(
                            key: state.pageKey,
                            child: PlaceProcessScheduleScreen(placeInfo: extra),
                          );
                        },
                      ),
                      GoRoute(
                        path: 'checklist',
                        pageBuilder: (context, state) {
                          final extra = state.extra;
                          if (extra is! PlaceInfoModel) {
                            return placeBranchSubPage(
                              state: state,
                              child: const Scaffold(
                                body: Center(child: Text('현장 정보가 없습니다.')),
                              ),
                            );
                          }
                          return placeBranchSubPage(
                            state: state,
                            child: PlaceChecklistScreen(placeInfo: extra),
                          );
                        },
                      ),
                      GoRoute(
                        path: 'workforce',
                        pageBuilder: (context, state) {
                          final extra = state.extra;
                          final workforceExtra = switch (extra) {
                            PlaceWorkforceRouteExtra e => e,
                            PlaceInfoModel p =>
                              PlaceWorkforceRouteExtra(placeInfo: p),
                            _ => null,
                          };
                          if (workforceExtra == null) {
                            return placeBranchSubPage(
                              state: state,
                              child: const Scaffold(
                                body: Center(child: Text('현장 정보가 없습니다.')),
                              ),
                            );
                          }
                          return placeBranchSubPage(
                            state: state,
                            child: PlaceWorkforceScreen(extra: workforceExtra),
                          );
                        },
                      ),
                      GoRoute(
                        path: 'announcements',
                        pageBuilder: (context, state) {
                          final extra = state.extra;
                          if (extra is! PlaceInfoModel) {
                            return placeBranchSubPage(
                              state: state,
                              child: const Scaffold(
                                body: Center(child: Text('현장 정보가 없습니다.')),
                              ),
                            );
                          }
                          return placeBranchSubPage(
                            state: state,
                            child: PlaceWorkerAnnouncementsScreen(place: extra),
                          );
                        },
                      ),
                      GoRoute(
                        path: 'members',
                        pageBuilder: (context, state) {
                          final extra = state.extra;
                          if (extra is! PlaceInfoModel) {
                            return placeBranchSubPage(
                              state: state,
                              child: const Scaffold(
                                body: Center(child: Text('현장 정보가 없습니다.')),
                              ),
                            );
                          }
                          return placeBranchSubPage(
                            state: state,
                            child: PlaceMembersScreen(place: extra),
                          );
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
                pageBuilder: (context, state) => NoTransitionPage<void>(
                  key: const ValueKey<String>('add'),
                  child: ShellTabRootBackScope(
                    shellBranchIndex: 2,
                    child: Consumer(
                      builder: (context, ref, _) {
                        final session = ref.watch(authSessionProvider);
                        if (session.isLoading) {
                          return const Scaffold(
                            body: Center(
                              child: HammerLoadingIndicator(
                                size: 106,
                                label: '화면 준비 중...',
                              ),
                            ),
                          );
                        }
                        final isWorker =
                            session.asData?.value?.isWorker ?? false;
                        // 작업자는 전국 생활 지도 탭. 관리자는 별도 작업지시 허브 탭.
                        return isWorker
                            ? const WorkerSupplyMapScreen()
                            : const WorkInstructionHubScreen();
                      },
                    ),
                  ),
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
                  child: ShellTabRootBackScope(
                    shellBranchIndex: 3,
                    child: CalendarBranchScreen(),
                  ),
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
                  child: ShellTabRootBackScope(
                    shellBranchIndex: 4,
                    child: WorkCostScreen(),
                  ),
                ),
                routes: [
                  GoRoute(
                    path: 'human',
                    parentNavigatorKey: rootNavigatorKey,
                    pageBuilder: (context, state) => MaterialPage<void>(
                      key: state.pageKey,
                      child: const OverlayRouteBackScope(
                        child: HumanScreen(),
                      ),
                    ),
                  ),
                  GoRoute(
                    path: 'items/:humanKey',
                    parentNavigatorKey: rootNavigatorKey,
                    pageBuilder: (context, state) {
                      final encoded = state.pathParameters['humanKey'] ?? '';
                      final uniqueHuman = decodeWorkCostHumanRouteKey(encoded);
                      return MaterialPage<void>(
                        key: state.pageKey,
                        child: OverlayRouteBackScope(
                          child: WorkerWorkCostItemsScreen(
                            uniqueHuman: uniqueHuman,
                          ),
                        ),
                      );
                    },
                  ),
                  GoRoute(
                    path: 'detail/:hid',
                    parentNavigatorKey: rootNavigatorKey,
                    pageBuilder: (context, state) {
                      final hidStr = state.pathParameters['hid']!;
                      final hid = int.parse(hidStr);
                      final hname = state.uri.queryParameters['name'] ?? '';
                      return MaterialPage<void>(
                        key: state.pageKey,
                        child: OverlayRouteBackScope(
                          child: WorkCostDetailScreen(hid: hid, hname: hname),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/profile',
                pageBuilder: (context, state) => const NoTransitionPage<void>(
                  key: ValueKey<String>('profile-root'),
                  child: ShellTabRootBackScope(
                    shellBranchIndex: 5,
                    child: ProfileScreen(),
                  ),
                ),
                routes: [
                  GoRoute(
                    path: 'private-info',
                    parentNavigatorKey: rootNavigatorKey,
                    pageBuilder: (context, state) => materialOverlayPage(
                      state: state,
                      child: const WorkerPrivateInfoScreen(),
                    ),
                  ),
                  GoRoute(
                    path: 'phone-setting',
                    parentNavigatorKey: rootNavigatorKey,
                    pageBuilder: (context, state) => materialOverlayPage(
                      state: state,
                      child: const PhoneSettingScreen(),
                    ),
                  ),
                  GoRoute(
                    path: 'notification-settings',
                    parentNavigatorKey: rootNavigatorKey,
                    pageBuilder: (context, state) => materialOverlayPage(
                      state: state,
                      child: const NotificationSettingsScreen(),
                    ),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/settings',
                pageBuilder: (context, state) => NoTransitionPage<void>(
                  key: const ValueKey<String>('settings-root'),
                  child: ShellTabRootBackScope(
                    shellBranchIndex: 6,
                    child: Consumer(
                      builder: (context, ref, _) {
                        final session = ref.watch(authSessionProvider);
                        final isWorker =
                            session.asData?.value?.isWorker ?? false;
                        return isWorker
                            ? const WorkerMoreScreen()
                            : const OperatorSettingsScreen();
                      },
                    ),
                  ),
                ),
                routes: [
                  GoRoute(
                    path: 'worker-settings',
                    parentNavigatorKey: rootNavigatorKey,
                    pageBuilder: (context, state) => materialOverlayPage(
                      state: state,
                      child: const WorkerSettingsScreen(),
                    ),
                  ),
                  GoRoute(
                    path: 'field-knowledge',
                    parentNavigatorKey: rootNavigatorKey,
                    pageBuilder: (context, state) => materialOverlayPage(
                      state: state,
                      child: const WorkerFieldKnowledgeHubScreen(
                        asTabRoot: false,
                      ),
                    ),
                  ),
                  GoRoute(
                    path: 'profile',
                    parentNavigatorKey: rootNavigatorKey,
                    pageBuilder: (context, state) => materialOverlayPage(
                      state: state,
                      child: const WorkerProfileSettingsScreen(),
                    ),
                    routes: [
                      GoRoute(
                        path: 'phone-setting',
                        parentNavigatorKey: rootNavigatorKey,
                        pageBuilder: (context, state) => materialOverlayPage(
                          state: state,
                          child: const PhoneSettingScreen(),
                        ),
                      ),
                    ],
                  ),
                  GoRoute(
                    path: 'account',
                    parentNavigatorKey: rootNavigatorKey,
                    pageBuilder: (context, state) => materialOverlayPage(
                      state: state,
                      child: const AccountSettingsScreen(),
                    ),
                    routes: [
                      GoRoute(
                        path: 'phone-setting',
                        parentNavigatorKey: rootNavigatorKey,
                        pageBuilder: (context, state) => materialOverlayPage(
                          state: state,
                          child: const PhoneSettingScreen(),
                        ),
                      ),
                    ],
                  ),
                  GoRoute(
                    path: 'notification-settings',
                    parentNavigatorKey: rootNavigatorKey,
                    pageBuilder: (context, state) => materialOverlayPage(
                      state: state,
                      child: const NotificationSettingsScreen(),
                    ),
                  ),
                  GoRoute(
                    path: 'archived-places',
                    parentNavigatorKey: rootNavigatorKey,
                    pageBuilder: (context, state) => materialOverlayPage(
                      state: state,
                      child: const ArchivedPlacesManagementScreen(),
                    ),
                  ),
                  GoRoute(
                    path: 'earnings',
                    parentNavigatorKey: rootNavigatorKey,
                    pageBuilder: (context, state) => materialOverlayPage(
                      state: state,
                      child: const WorkerEarningsScreen(),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/announcements/inbox',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => WorkerAnnouncementsInboxScreen(
          initialSegment: WorkerAnnouncementInboxSegment.fromRouteQuery(
            state.uri.queryParameters['filter'],
          ),
        ),
      ),
      GoRoute(
        path: '/announcements/view',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) {
          final e = state.extra;
          if (e is! WorkerAnnouncementRead) {
            return Scaffold(
              appBar: AppBar(title: const Text('공지')),
              body: const Center(child: Text('공지 정보가 없습니다.')),
            );
          }
          return WorkerAnnouncementDetailScreen(item: e);
        },
      ),
    ],
  );
}

class _MainShell extends ConsumerStatefulWidget {
  const _MainShell({required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  ConsumerState<_MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<_MainShell>
    with TickerProviderStateMixin {
  late TabController _tabController;
  var _programmaticTabUpdate = false;
  var _workerLayout = false;

  StatefulNavigationShell get _shell => widget.navigationShell;

  bool _onShellSystemBack() {
    return handleAppShellSystemBack(
      context: context,
      router: GoRouter.of(context),
      shellBranchIndex: _shell.currentIndex,
    );
  }

  @override
  void initState() {
    super.initState();
    final user = ref.read(authSessionProvider).asData?.value;
    _workerLayout = user?.isWorker ?? false;
    _tabController = TabController(
      length: _workerLayout ? 5 : 6,
      vsync: this,
      initialIndex: shellIndexToDisplayIndex(
        _shell.currentIndex,
        _workerLayout,
      ),
    );
  }

  @override
  void didUpdateWidget(covariant _MainShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    final di = shellIndexToDisplayIndex(_shell.currentIndex, _workerLayout);
    if (di != _tabController.index) {
      _programmaticTabUpdate = true;
      _tabController.index = di;
      _programmaticTabUpdate = false;
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _applyWorkerLayout(bool worker) {
    if (worker == _workerLayout) return;
    setState(() {
      _workerLayout = worker;
      _tabController.dispose();
      final di = shellIndexToDisplayIndex(_shell.currentIndex, _workerLayout);
      // 작업자 5탭(대시보드·내 일정·현장·지도·더보기), 관리자 6탭(상황판·현장·작업지시·캘린더·인건비·설정)
      final len = _workerLayout ? 5 : 6;
      _tabController = TabController(
        length: len,
        vsync: this,
        initialIndex: di.clamp(0, len - 1),
      );
    });
  }

  /// 사용자 변경 시 모든 사용자별 provider 초기화
  void _clearAllUserProvidersOnUserChange() {
    final container = rootProviderContainer;
    if (container != null) {
      clearAllUserProviders(container);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<UserRead?>>(authSessionProvider, (prev, next) {
      final prevUser = prev?.asData?.value;
      final nextUser = next.asData?.value;

      // 계정·권한(role) 전환·로그아웃 시 캐시 초기화
      final switchedAccount = prevUser != null &&
          nextUser != null &&
          (prevUser.uid != nextUser.uid || prevUser.role != nextUser.role);
      final loggedOut = prevUser != null && nextUser == null;
      if (switchedAccount || loggedOut) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _clearAllUserProvidersOnUserChange();
        });
      }

      final w = nextUser?.isWorker ?? false;
      if (w == _workerLayout) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _applyWorkerLayout(w);
      });
    });

    final media = MediaQuery.of(context);
    final bottomInset = media.padding.bottom;
    final width = media.size.width;
    // 화면 폭이 좁을수록 아이콘/텍스트를 줄여 잘림 방지
    final compact = width < 380;
    final labelFontSize = context.rs(compact ? 12.0 : 13.0);
    // 기본 바 높이 + safe-area (기기별 홈 인디케이터 대응)
    final barHeight = context.rs(compact ? 64.0 : 70.0) + bottomInset;

    final router = GoRouter.of(context);
    final path = router.state.uri.path;
    final hideBottomNav = shouldHideShellBottomNavForPath(path);

    return BackButtonListener(
      onBackButtonPressed: () async => _onShellSystemBack(),
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (didPop) return;
          _onShellSystemBack();
        },
        child: Scaffold(
          body: SafeArea(
            child: Column(
              children: [
                Expanded(child: _shell),
                Divider(height: 0, color: Colors.grey[400]),
              ],
            ),
          ),
          bottomNavigationBar: hideBottomNav
              ? null
              : Container(
                  height: barHeight,
                  padding: EdgeInsets.only(bottom: bottomInset),
                  decoration: BoxDecoration(
                    color: Colors.blueGrey.withValues(alpha: 0.15),
                  ),
                  child: TabBar(
                    controller: _tabController,
                    // 아이콘/라벨 크기 기기별 대응
                    labelStyle: TextStyle(
                        fontSize: labelFontSize, fontWeight: FontWeight.bold),
                    unselectedLabelStyle: TextStyle(
                        fontSize: labelFontSize, fontWeight: FontWeight.normal),
                    labelPadding: const EdgeInsets.only(top: 2, bottom: 6),
                    // Tab 아이콘 테마를 강제해 const Tab에서 size 지정 제거
                    indicatorPadding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                    overlayColor:
                        const WidgetStatePropertyAll(Colors.transparent),
                    splashFactory: NoSplash.splashFactory,
                    // IconTheme은 TabBar가 내부적으로 사용
                    // ignore: deprecated_member_use_from_same_package
                    // (IconThemeData는 여전히 정상 사용)
                    // iconTheme는 3.22+에서 지원
                    // 아래는 런타임/SDK에 따라 무시될 수 있음
                    // 하지만 size는 Tab 아이콘에서 기본값보다 작게 유지됨
                    onTap: (displayIndex) {
                      resetShellExitBackRequest();
                      if (_programmaticTabUpdate) return;
                      HapticFeedback.selectionClick();
                      final branch =
                          displayIndexToShellIndex(displayIndex, _workerLayout);
                      if (!_workerLayout &&
                          _shell.currentIndex == 0 &&
                          branch != 0) {
                        unawaited(
                          ref
                              .read(dashboardScheduleProvider.notifier)
                              .flushPendingDonePatches(),
                        );
                      }
                      _shell.goBranch(
                        branch,
                        initialLocation: branch == _shell.currentIndex,
                      );
                    },
                    tabAlignment: TabAlignment.fill,
                    indicatorSize: TabBarIndicatorSize.tab,
                    labelColor: Theme.of(context).colorScheme.primary,
                    unselectedLabelColor:
                        Theme.of(context).colorScheme.onSurfaceVariant,
                    // labelStyle/unselectedLabelStyle are set above
                    tabs: _workerLayout
                        ? const [
                            Tab(
                              icon: Icon(Icons.stacked_line_chart_rounded),
                              text: '대시보드',
                            ),
                            Tab(
                              icon: Icon(Icons.calendar_month),
                              text: '내 일정',
                            ),
                            Tab(
                              icon: Icon(Icons.house),
                              text: '현장 관리',
                            ),
                            Tab(
                              icon: Icon(Icons.map_outlined),
                              text: '지도',
                            ),
                            Tab(
                              icon: Icon(Icons.more_horiz),
                              text: '더보기',
                            ),
                          ]
                        : const [
                            Tab(
                              icon: Icon(Icons.dashboard),
                              text: '상황판',
                            ),
                            Tab(
                              icon: Icon(Icons.house),
                              text: '현장 관리',
                            ),
                            Tab(
                              icon: Icon(Icons.assignment_turned_in_outlined),
                              text: '작업지시',
                            ),
                            Tab(
                              icon: Icon(Icons.calendar_month),
                              text: '캘린더',
                            ),
                            Tab(
                              icon: Icon(Icons.person),
                              text: '인건비',
                            ),
                            Tab(
                              icon: Icon(Icons.settings),
                              text: '설정',
                            ),
                          ],
                  ),
                ),
        ),
      ),
    );
  }
}
