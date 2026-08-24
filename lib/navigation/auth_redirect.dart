import 'dart:async' show unawaited;

import 'package:w0001/access/user_role_capabilities.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:w0001/data/model/auth_models.dart';
import 'package:w0001/presentation/viewmodel/auth_providers.dart';
import 'package:w0001/ui/screen/0_auth/login_auth_dialogs.dart';
import 'package:w0001/util/auth_forced_sign_out.dart';

/// 로그인 상태·역할에 따른 경로 보정. [GoRouter.redirect]에서 사용합니다.
String? authRedirect(ProviderContainer container, GoRouterState state) {
  final session = container.read(authSessionProvider);
  final loc = state.matchedLocation;
  final loggingIn = loc == '/login' || loc == '/signup';

  if (session.isLoading) return null;

  final user = session.hasError ? null : session.asData?.value;

  if (user == null) {
    if (loggingIn) return null;
    return '/login';
  }

  // 승인 거절 — 세션 종료 후 로그인으로
  if (user.approvalStatus == UserApprovalStatus.rejected) {
    unawaited(
      performAuthForcedSignOut(
        accountRestrictionMessage(kind: AccountRestrictionKind.rejected),
      ),
    );
    return '/login';
  }

  // 승인 대기 작업자 — is_active=false여도 제한 화면만 허용
  if (user.isPendingApproval) {
    if (loc == '/pending-approval' || loc == '/profile') return null;
    return '/pending-approval';
  }

  // 정지·비활성 (승인 대기는 위에서 처리)
  if (!user.isActive) {
    unawaited(
      performAuthForcedSignOut(
        accountRestrictionMessage(kind: AccountRestrictionKind.suspended),
      ),
    );
    return '/login';
  }

  if (loggingIn) {
    return '/dashboard';
  }

  if (loc == '/pending-approval') {
    return '/dashboard';
  }

  if (loc.startsWith('/dashboard/worker-mgmt')) {
    if (!user.role.canAccessWorkerManagementMenus) {
      return '/dashboard';
    }
  }

  if (loc == '/dashboard/member-queue') {
    if (!user.role.canManageMemberAccounts) return '/dashboard';
    return null;
  }

  if (loc.startsWith('/dashboard/extras')) {
    if (!user.role.canManageExtras) return '/dashboard';
  }

  if (user.isWorker) {
    if (loc.startsWith('/dashboard')) {
      if (loc == '/dashboard/profile') return '/profile';
      // 알림함·상황판 홈 — 그 외 /dashboard/* (관리자 전용)는 차단
      if (loc == '/dashboard' || loc == '/dashboard/notifications') {
        return null;
      }
      return '/dashboard';
    }
    // 작업자는 /add 브랜치를 지도 탭으로 사용한다.
    if (loc.startsWith('/add')) {
      return null;
    }
    // 인건비(/work)만 관리자 전용으로 차단한다.
    if (loc.startsWith('/work')) {
      return '/dashboard';
    }
  } else {
    if (loc == '/profile') {
      return '/dashboard/profile';
    }
    // 관리자 /add 브랜치는 작업지시 탭이다.
  }

  return null;
}
