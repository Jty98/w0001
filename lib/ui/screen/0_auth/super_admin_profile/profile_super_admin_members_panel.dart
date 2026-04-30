import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:w0001/data/datasources/remote/http_client.dart';
import 'package:w0001/data/model/auth_models.dart';
import 'package:w0001/presentation/viewmodel/auth_providers.dart';
import 'package:w0001/presentation/viewmodel/profile_super_admin_members_notifier.dart';
import 'package:w0001/presentation/viewmodel/profile_super_admin_members_state.dart';
import 'package:w0001/ui/screen/0_auth/super_admin_profile/profile_super_admin_search_debounce_holder.dart';
import 'package:w0001/ui/screen/0_auth/super_admin_profile/super_admin_confirm_dialogs.dart';
import 'package:w0001/ui/screen/0_auth/super_admin_profile/super_admin_empty_banner.dart';
import 'package:w0001/ui/screen/0_auth/super_admin_profile/super_admin_member_card.dart';
import 'package:w0001/ui/screen/0_auth/super_admin_profile/super_admin_queue_block.dart';
import 'package:w0001/ui/screen/0_auth/super_admin_profile/super_admin_section_header.dart';

String _memberActionErrorLine(Object e) {
  if (e is DioException) {
    final inner = e.error;
    if (inner is HttpClientException) return inner.message;
  }
  if (e is HttpClientException) return e.message;
  return e.toString();
}

Future<String?> _obtainSensitiveActionToken(
  BuildContext context,
  WidgetRef ref, {
  required String title,
  required String body,
  required void Function(String message) toast,
}) async {
  final pw = await showSuperAdminSensitiveActionPasswordDialog(
    context: context,
    title: title,
    body: body,
  );
  if (pw == null || !context.mounted) return null;
  try {
    final r = await ref
        .read(authApiProvider)
        .verifySensitiveAction(password: pw);
    return r.actionToken;
  } catch (e) {
    if (context.mounted) toast(_memberActionErrorLine(e));
    return null;
  }
}

/// [ProfileSuperAdminUserSection] 내부 본문.
class ProfileSuperAdminMembersPanel extends ConsumerWidget {
  const ProfileSuperAdminMembersPanel({
    super.key,
    required this.searchController,
    required this.debounceHolder,
    required this.reloadSession,
  });

  final TextEditingController searchController;
  final ProfileSuperAdminSearchDebounceHolder debounceHolder;
  final VoidCallback? reloadSession;

  void _toast(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(profileSuperAdminMembersProvider);
    final n = ref.read(profileSuperAdminMembersProvider.notifier);
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    Future<void> approve(UserRead u) async {
      final pack = await showSuperAdminConfirmWithNoteDialog(
        context: context,
        title: '가입 승인',
        body:
            '\'${u.uname}\' 님 가입 요청을 승인합니다. 활동 가능 상태로 만들 수 있습니다.',
        affirmativeLabel: '승인',
        hint: '메모 (선택)',
        affirmativeStyle: FilledButton.styleFrom(
          backgroundColor: cs.primary,
          foregroundColor: cs.onPrimary,
        ),
      );
      if (pack == null || pack.$1 != true || !context.mounted) return;
      try {
        await n.userApprove(
          u.uid,
          note: pack.$2.isEmpty ? null : pack.$2,
        );
        if (!context.mounted) return;
        _toast(context, '승인했습니다.');
      } catch (e) {
        if (context.mounted) _toast(context, '승인 실패: $e');
      }
    }

    Future<void> reject(UserRead u) async {
      final pack = await showSuperAdminConfirmWithNoteDialog(
        context: context,
        title: '가입 거절',
        body:
            '\'${u.uname}\' 님 가입 요청을 거절합니다. 계정 레코드는 남으며, 나중에 다시 승인할 수 있습니다.',
        affirmativeLabel: '거절',
        hint: '사유 메모 (선택)',
        affirmativeStyle: FilledButton.styleFrom(
          backgroundColor: cs.error,
          foregroundColor: cs.onError,
        ),
      );
      if (pack == null || pack.$1 != true || !context.mounted) return;
      try {
        await n.userReject(
          u.uid,
          note: pack.$2.isEmpty ? null : pack.$2,
        );
        if (!context.mounted) return;
        _toast(context, '거절 처리했습니다.');
      } catch (e) {
        if (context.mounted) _toast(context, '거절 실패: $e');
      }
    }

    Future<void> suspend(UserRead u) async {
      if (isSuperAdminUser(u)) return;
      final pack = await showSuperAdminConfirmWithNoteDialog(
        context: context,
        title: '활동 정지',
        body:
            '\'${u.uname}\' 계정 활동을 막습니다. 나중에 재활성화할 수 있습니다.',
        affirmativeLabel: '정지',
        hint: '사유 (선택)',
        affirmativeStyle: null,
      );
      if (pack == null || pack.$1 != true || !context.mounted) return;
      final token = await _obtainSensitiveActionToken(
        context,
        ref,
        title: '활동 정지 확인',
        body:
            '\'${u.uname}\' 계정에 활동 정지를 적용합니다. 관리자 비밀번호를 입력하세요.',
        toast: (m) => _toast(context, m),
      );
      if (token == null || !context.mounted) return;
      try {
        await n.userSuspend(
          u.uid,
          reason: pack.$2.isEmpty ? null : pack.$2,
          adminActionToken: token,
        );
        if (!context.mounted) return;
        _toast(context, '활동을 정지했습니다.');
      } catch (e) {
        if (context.mounted) _toast(context, '정지 실패: ${_memberActionErrorLine(e)}');
      }
    }

    Future<void> activate(UserRead u) async {
      final ok = await showSuperAdminSimpleConfirmDialog(
        context: context,
        title: '계정 활성화',
        body:
            '\'${u.uname}\' 활동 정지 상태를 해제합니다. 바로 활동 가능 상태로 되돌립니다.',
        confirmLabel: '활성화',
      );
      if (!ok || !context.mounted) return;
      try {
        await n.userActivate(u.uid);
        if (!context.mounted) return;
        _toast(context, '재활성화했습니다.');
        reloadSession?.call();
      } catch (e) {
        if (context.mounted) _toast(context, '재활성화 실패: $e');
      }
    }

    Future<void> flipRole(UserRead u) async {
      if (isSuperAdminUser(u)) return;
      final next =
          u.role == UserRole.admin ? UserRole.worker : UserRole.admin;
      final token = await _obtainSensitiveActionToken(
        context,
        ref,
        title: '권한 변경 확인',
        body:
            '\'${u.uname}\' 님을 ${next.labelKo}(으)로 변경합니다. 관리자 비밀번호를 입력하세요.',
        toast: (m) => _toast(context, m),
      );
      if (token == null || !context.mounted) return;
      try {
        await n.userChangeRole(u.uid, next, adminActionToken: token);
        if (!context.mounted) return;
        _toast(context, '권한을 ${next.labelKo}(으)로 변경했습니다.');
        reloadSession?.call();
      } catch (e) {
        if (context.mounted) {
          _toast(context, '권한 변경 실패: ${_memberActionErrorLine(e)}');
        }
      }
    }

    Future<void> deleteUser(UserRead u) async {
      final ok = await showSuperAdminDeleteUserConfirmDialog(
        context: context,
        uname: u.uname,
      );
      if (!ok || !context.mounted) return;
      try {
        await n.userDelete(u.uid);
        if (!context.mounted) return;
        _toast(context, '삭제했습니다.');
      } catch (e) {
        if (context.mounted) _toast(context, '삭제 실패: $e');
      }
    }

    final handlers = SuperAdminMemberHandlers(
      approve: approve,
      reject: reject,
      suspend: suspend,
      activate: activate,
      flipRole: flipRole,
      deleteUser: deleteUser,
    );

    if (!state.bootstrapDone) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 28),
        child: Column(
          children: [
            CircularProgressIndicator(color: cs.primary),
            const SizedBox(height: 14),
            Text(
              '불러오는 중…',
              style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SuperAdminSectionHeader(
          title: '활동 회원',
          trailing: state.busyActive
              ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: cs.primary.withValues(alpha: 0.85),
                  ),
                )
              : null,
        ),
        const SizedBox(height: 10),
        ListenableBuilder(
          listenable: searchController,
          builder: (context, _) {
            final hasQuery = searchController.text.trim().isNotEmpty;
            return TextField(
              controller: searchController,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: '이름 검색',
                isDense: true,
                prefixIcon: const Icon(Icons.search_rounded, size: 22),
                suffixIcon: hasQuery
                    ? IconButton(
                        tooltip: '지우기',
                        icon: const Icon(Icons.clear_rounded),
                        onPressed: () {
                          debounceHolder.cancel();
                          final had = searchController.text.trim().isNotEmpty;
                          searchController.clear();
                          if (had) {
                            unawaited(n.fetchActiveMembers(''));
                          }
                        },
                      )
                    : null,
                filled: true,
                fillColor: cs.surface.withValues(alpha: 0.65),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.5)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.5)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: cs.primary.withValues(alpha: 0.55)),
                ),
              ),
              onSubmitted: (_) {
                debounceHolder.cancel();
                unawaited(
                  n.fetchActiveMembers(searchController.text.trim()),
                );
              },
            );
          },
        ),
        if (state.errorActive != null)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(11),
              decoration: BoxDecoration(
                color: cs.errorContainer.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: cs.error, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '목록 로드 오류 · ${state.errorActive}',
                      style:
                          tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                    ),
                  ),
                  IconButton(
                    tooltip: '다시',
                    constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                    padding: EdgeInsets.zero,
                    icon: Icon(Icons.refresh_rounded, color: cs.primary),
                    onPressed: () => unawaited(
                      n.fetchActiveMembers(searchController.text.trim()),
                    ),
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 10),
        if (state.activeMembers.isEmpty &&
            !state.busyActive &&
            state.errorActive == null)
          SuperAdminEmptyBanner(
            message: searchController.text.trim().isEmpty
                ? '등록된 활동 회원이 없습니다.'
                : '검색 결과 없음',
            icon: Icons.people_outline_rounded,
          )
        else if (state.activeMembers.isNotEmpty) ...[
          ...state.activeMembers.map(
            (u) => SuperAdminMemberCard(user: u, handlers: handlers),
          ),
        ],
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Divider(
            height: 1,
            color: cs.outlineVariant.withValues(alpha: 0.4),
          ),
        ),
        SuperAdminSectionHeader(
          title: '처리 필요',
          trailing: state.busyQueue
              ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: cs.tertiary.withValues(alpha: 0.9),
                  ),
                )
              : null,
        ),
        const SizedBox(height: 8),
        SuperAdminQueueBlock(
          subtitle: '승인 대기',
          items: state.pendingMembers,
          error: state.errorPending,
          icon: Icons.mark_email_unread_rounded,
          emptyMessage: '대기 없음',
          handlers: handlers,
          onRetryReload: () => unawaited(n.reload()),
        ),
        SuperAdminQueueBlock(
          subtitle: '활동 정지',
          items: state.suspendedMembers,
          error: state.errorSuspended,
          icon: Icons.block_rounded,
          emptyMessage: '없음',
          handlers: handlers,
          onRetryReload: () => unawaited(n.reload()),
        ),
        SuperAdminQueueBlock(
          subtitle: '거절 · 재승인',
          items: state.rejectedMembers,
          error: state.errorRejected,
          icon: Icons.cancel_outlined,
          emptyMessage: '없음',
          handlers: handlers,
          onRetryReload: () => unawaited(n.reload()),
        ),
      ],
    );
  }
}
