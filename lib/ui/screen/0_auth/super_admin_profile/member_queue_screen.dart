import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:w0001/presentation/viewmodel/profile_super_admin_members_notifier.dart';
import 'package:w0001/ui/screen/0_auth/super_admin_profile/profile_super_admin_members_panel.dart';
import 'package:w0001/ui/screen/0_auth/super_admin_profile/profile_super_admin_search_debounce_holder.dart';
import 'package:w0001/ui/screen/0_auth/widgets/profile_section_chrome.dart';
import 'package:w0001/util/responsive_layout.dart';

/// 가입 승인 대기 등 — **처리 필요** 큐만 전체 화면으로 연다 (알림·FCM 딥링크).
///
/// 루트 네비게이터 [materialOverlayPage] 로 띄워 iOS 스와이프·앱바 뒤로가기가
/// 한 번에 상황판으로 돌아가게 한다.
class MemberQueueScreen extends ConsumerStatefulWidget {
  const MemberQueueScreen({super.key});

  @override
  ConsumerState<MemberQueueScreen> createState() => _MemberQueueScreenState();
}

class _MemberQueueScreenState extends ConsumerState<MemberQueueScreen> {
  final _searchController = TextEditingController();
  final _debounceHolder = ProfileSuperAdminSearchDebounceHolder();

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onActiveSearchSignal);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(reloadProfileSuperAdminMembers(ref));
    });
  }

  @override
  void dispose() {
    _debounceHolder.cancel();
    _searchController.removeListener(_onActiveSearchSignal);
    _searchController.dispose();
    super.dispose();
  }

  void _onActiveSearchSignal() {
    final nextTrim = _searchController.text.trim();
    final applied =
        ref.read(profileSuperAdminMembersProvider).appliedActiveTrim;
    if (nextTrim == applied) {
      _debounceHolder.cancel();
      return;
    }
    _debounceHolder.cancel();
    _debounceHolder.timer = Timer(const Duration(milliseconds: 460), () {
      if (!mounted) return;
      final t = _searchController.text.trim();
      final appliedNow =
          ref.read(profileSuperAdminMembersProvider).appliedActiveTrim;
      if (t == appliedNow) return;
      unawaited(
        ref
            .read(profileSuperAdminMembersProvider.notifier)
            .fetchActiveMembers(t),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: context.canPop(),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('회원 관리'),
        ),
        body: SafeArea(
          child: RefreshIndicator(
            onRefresh: () => reloadProfileSuperAdminMembers(ref),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.fromLTRB(
                context.rsi(16),
                context.rsi(8),
                context.rsi(16),
                context.rsi(24),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    '처리 필요',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  SizedBox(height: context.rsi(4)),
                  Text(
                    '가입 승인 대기·정지·거절 계정을 처리합니다.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                  SizedBox(height: context.rsi(12)),
                  ProfileInsetPanel(
                    padding: EdgeInsets.fromLTRB(
                      context.rsi(12),
                      context.rsi(12),
                      context.rsi(12),
                      context.rsi(12),
                    ),
                    child: ProfileSuperAdminMembersPanel(
                      searchController: _searchController,
                      debounceHolder: _debounceHolder,
                      initialSection: 0,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
