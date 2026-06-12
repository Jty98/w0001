import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:w0001/ui/screen/0_auth/super_admin_profile/profile_super_admin_members_panel.dart';
import 'package:w0001/ui/screen/0_auth/super_admin_profile/profile_super_admin_search_debounce_holder.dart';

import 'package:w0001/presentation/viewmodel/profile_super_admin_members_notifier.dart';

/// 슈퍼관리자 프로필 내 회원 승인·검색·활동 제어·역할 변경·삭제.
///
/// 데이터는 [profileSuperAdminMembersProvider], 당김 새로고침은
/// [reloadProfileSuperAdminMembers] 를 사용합니다.
class ProfileSuperAdminUserSection extends ConsumerStatefulWidget {
  const ProfileSuperAdminUserSection({super.key});

  @override
  ConsumerState<ProfileSuperAdminUserSection> createState() =>
      _ProfileSuperAdminUserSectionState();
}

class _ProfileSuperAdminUserSectionState
    extends ConsumerState<ProfileSuperAdminUserSection> {
  final _searchController = TextEditingController();
  final _debounceHolder = ProfileSuperAdminSearchDebounceHolder();

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onActiveSearchSignal);
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
    return ProfileSuperAdminMembersPanel(
      searchController: _searchController,
      debounceHolder: _debounceHolder,
    );
  }
}
