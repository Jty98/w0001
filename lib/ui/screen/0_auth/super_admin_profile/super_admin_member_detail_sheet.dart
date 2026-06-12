import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:w0001/data/model/auth_models.dart';
import 'package:w0001/data/model/remote/super_admin_dtos.dart';
import 'package:w0001/domain/use_case/super_admin_remote_use_case.dart';
import 'package:w0001/presentation/viewmodel/super_admin_remote_providers.dart';
import 'package:w0001/presentation/viewmodel/worker_mgmt_view_model.dart';
import 'package:w0001/data/model/human_model.dart';
import 'package:w0001/ui/screen/0_auth/super_admin_profile/admin_member_private_info_section.dart';
import 'package:w0001/ui/screen/0_auth/super_admin_profile/super_admin_member_meta.dart';
import 'package:w0001/ui/screen/0_auth/widgets/profile_section_chrome.dart';
import 'package:w0001/ui/screen/0_auth/worker_mgmt/worker_mgmt_hid_content.dart';
import 'package:w0001/util/worker_skills_display.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:w0001/util/responsive_layout.dart';

/// 계정과 [HumanRead] 매칭: 서버 `worker_hid` → 이름 일치 → uid와 주민번호 숫자 일치.
int? resolveWorkerHidForMember(UserRead u, List<HumanRead> humans) {
  if (u.workerHid != null && u.workerHid! > 0) return u.workerHid;
  final uname = u.uname.trim();
  for (final h in humans) {
    if (h.hdelete != 0) continue;
    if (h.hname.trim() == uname) return h.hid;
  }
  final uidDigits = u.uid.replaceAll(RegExp(r'\D'), '');
  if (uidDigits.length >= 4) {
    for (final h in humans) {
      if (h.hdelete != 0) continue;
      final nd = h.hnumber.replaceAll(RegExp(r'\D'), '');
      if (nd.isNotEmpty && nd == uidDigits) return h.hid;
    }
  }
  return null;
}

class _DetailInfoRow extends StatelessWidget {
  const _DetailInfoRow({
    required this.label,
    required this.value,
    this.trailing,
  });

  final String label;
  final String value;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Padding(
      padding: EdgeInsets.symmetric(vertical: context.rsi(5)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: context.rsi(72),
            child: Text(
              label,
              style: tt.labelSmall?.copyWith(
                color: cs.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    value,
                    style: tt.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      height: 1.25,
                    ),
                  ),
                ),
                if (trailing != null) trailing!,
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 슈퍼관리자 회원 카드에서 연 경우 — 관리 메모·트러블 페어(인력 hid 기준).
class SuperAdminMemberDetailSheet extends ConsumerStatefulWidget {
  const SuperAdminMemberDetailSheet({
    super.key,
    required this.initialUser,
  });

  final UserRead initialUser;

  @override
  ConsumerState<SuperAdminMemberDetailSheet> createState() =>
      _SuperAdminMemberDetailSheetState();
}

class _SuperAdminMemberDetailSheetState
    extends ConsumerState<SuperAdminMemberDetailSheet> {
  UserRead? _userFresh;
  int? _hid;
  HumanModel? _skillsHuman;
  var _detailBusy = false;
  Object? _loadError;

  UserRead get _displayUser => _userFresh ?? widget.initialUser;

  SuperAdminRemoteUseCase get _uc => ref.read(superAdminRemoteUseCaseProvider);

  @override
  void initState() {
    super.initState();
    final ih = widget.initialUser.workerHid;
    if (ih != null && ih > 0) _hid = ih;
    Future.microtask(_load);
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _detailBusy = true;
      _loadError = null;
    });
    try {
      final fresh = await _uc.userGet(widget.initialUser.uid);
      await ref
          .read(workerMgmtHumanDirectoryProvider.notifier)
          .reload(blocking: false);
      var humans = ref.read(workerMgmtHumanDirectoryProvider).humans;
      if (humans.isEmpty) {
        await ref
            .read(workerMgmtHumanDirectoryProvider.notifier)
            .reload(blocking: true);
        humans = ref.read(workerMgmtHumanDirectoryProvider).humans;
      }
      final hidResolved = (fresh.workerHid != null && fresh.workerHid! > 0)
          ? fresh.workerHid
          : resolveWorkerHidForMember(fresh, humans);
      HumanRead? linked = hidResolved != null
          ? findHumanReadForMember(fresh, humans)
          : null;
      if (hidResolved != null) {
        try {
          linked = await _uc.humanGet(hidResolved);
        } catch (_) {}
      }
      final skillsHuman = humanModelForMemberSkills(
        fresh,
        linkedHuman: linked,
      );
      if (!mounted) return;
      setState(() {
        _userFresh = fresh;
        _hid = hidResolved;
        _skillsHuman = skillsHuman;
        _detailBusy = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = e;
        _detailBusy = false;
      });
    }
  }

  Future<void> _refreshAll() async {
    await _load();
    final hid = _hid;
    if (!mounted || hid == null) return;
    await ref.read(workerMgmtHidVmProvider(hid).notifier).reload(silent: true);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final bottom = MediaQuery.paddingOf(context).bottom;
    final user = _displayUser;
    final hid = _hid;

    return DraggableScrollableSheet(
      initialChildSize: 0.88,
      minChildSize: 0.45,
      maxChildSize: 0.94,
      expand: false,
      builder: (ctx, scrollCtrl) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: RefreshIndicator(
                onRefresh: _refreshAll,
                child: SingleChildScrollView(
                  controller: scrollCtrl,
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(
                    ctx.rsi(16),
                    ctx.rsi(2),
                    ctx.rsi(16),
                    ctx.rsi(16) + bottom,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        user.uname,
                        style: tt.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                        ),
                      ),
                      SizedBox(height: ctx.rsi(6)),
                      SuperAdminMemberStatusChips(
                        user: user,
                        dense: false,
                      ),
                      if (_loadError != null) ...[
                        SizedBox(height: ctx.rsi(10)),
                        Material(
                          color: cs.errorContainer.withValues(alpha: 0.35),
                          borderRadius: BorderRadius.circular(10),
                          child: Padding(
                            padding: EdgeInsets.all(ctx.rsi(10)),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(
                                  '일부 정보를 불러오지 못했습니다',
                                  style: tt.labelMedium?.copyWith(
                                    color: cs.onErrorContainer,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                SizedBox(height: ctx.rsi(4)),
                                Text(
                                  '$_loadError',
                                  style: tt.bodySmall?.copyWith(
                                    color: cs.onErrorContainer,
                                  ),
                                ),
                                SizedBox(height: ctx.rsi(6)),
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: TextButton.icon(
                                    onPressed: _detailBusy ? null : _load,
                                    icon: Icon(Icons.refresh_rounded,
                                        size: ctx.rs(16)),
                                    label: const Text('다시 시도'),
                                    style: TextButton.styleFrom(
                                      visualDensity: VisualDensity.compact,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                      SizedBox(height: ctx.rsi(14)),
                      const ProfileSectionTitle('계정 정보'),
                      SizedBox(height: ctx.rsi(8)),
                      ProfileInsetPanel(
                        padding: EdgeInsets.symmetric(
                          horizontal: ctx.rsi(12),
                          vertical: ctx.rsi(6),
                        ),
                        child: Column(
                          children: [
                            _DetailInfoRow(label: '아이디', value: user.uid),
                            if (user.phoneMasked != null &&
                                user.phoneMasked!.isNotEmpty)
                              _DetailInfoRow(
                                label: '연락처',
                                value: user.phoneMasked!,
                                trailing: user.phoneVerified
                                    ? Icon(
                                        Icons.verified_rounded,
                                        size: ctx.rs(16),
                                        color: cs.primary,
                                      )
                                    : null,
                              ),
                            if (user.role == UserRole.worker &&
                                user.workerRank.isNotEmpty)
                              _DetailInfoRow(
                                label: '현장 역할',
                                value: user.workerRank,
                              ),
                            if (user.role == UserRole.worker &&
                                user.career.isNotEmpty)
                              _DetailInfoRow(
                                label: '경력',
                                value: user.career,
                              ),
                            if (hid != null)
                              _DetailInfoRow(
                                label: '인력 연결',
                                value: '연결됨 (hid $hid)',
                                trailing: Icon(
                                  Icons.link_rounded,
                                  size: ctx.rs(16),
                                  color: cs.primary,
                                ),
                              ),
                          ],
                        ),
                      ),
                      if (memberShouldShowWorkerSkills(user) &&
                          _skillsHuman != null) ...[
                        SizedBox(height: ctx.rsi(14)),
                        const ProfileSectionTitle('작업 분야'),
                        SizedBox(height: ctx.rsi(8)),
                        ProfileInsetPanel(
                          padding: EdgeInsets.all(ctx.rsi(10)),
                          child: HumanSkillsChipRow(
                            human: _skillsHuman!,
                            extraScrollHeight: 28,
                          ),
                        ),
                      ],
                      if (user.role == UserRole.worker) ...[
                        SizedBox(height: ctx.rsi(14)),
                        const ProfileSectionTitle('세금·개인 정보'),
                        SizedBox(height: ctx.rsi(8)),
                        AdminMemberPrivateInfoSection(workerUid: user.uid),
                      ],
                      if (_detailBusy && hid == null)
                        Padding(
                          padding: EdgeInsets.only(top: ctx.rsi(14)),
                          child: Skeletonizer(
                            enabled: true,
                            child: Row(
                              children: [
                                Icon(
                                  Icons.link_rounded,
                                  size: ctx.rs(16),
                                  color: cs.primary,
                                ),
                                SizedBox(width: ctx.rsi(8)),
                                Expanded(
                                  child: Text(
                                    '인력 계정 연결 정보를 확인하는 중…',
                                    style: tt.labelSmall?.copyWith(
                                      color: cs.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      else if (!_detailBusy && hid == null) ...[
                        SizedBox(height: ctx.rsi(14)),
                        const ProfileSectionTitle('인력 연결'),
                        SizedBox(height: ctx.rsi(8)),
                        Material(
                          color: user.approvalStatus ==
                                  UserApprovalStatus.pending
                              ? cs.errorContainer.withValues(alpha: 0.32)
                              : cs.surfaceContainerHighest
                                  .withValues(alpha: 0.55),
                          borderRadius: BorderRadius.circular(ctx.rsi(12)),
                          child: Padding(
                            padding: EdgeInsets.all(ctx.rsi(12)),
                            child: Text(
                              user.approvalStatus ==
                                      UserApprovalStatus.pending
                                  ? '승인 대기 중인 계정입니다\n가입 승인 후 인력 정보가 연결됩니다'
                                  : user.approvalStatus ==
                                          UserApprovalStatus.rejected
                                      ? '거절된 계정입니다\n인력(메모·트러블) 정보를 연결할 수 없습니다'
                                      : '인력 레코드와 연결되지 않았습니다\n이름이 일치하는 인력이 없거나 아직 동기화되지 않았을 수 있습니다',
                              style: tt.labelMedium?.copyWith(
                                color: user.approvalStatus ==
                                        UserApprovalStatus.pending
                                    ? cs.onErrorContainer
                                    : cs.onSurfaceVariant,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ),
                      ] else ...[
                        SizedBox(height: ctx.rsi(14)),
                        const ProfileSectionTitle('인력 관리'),
                        SizedBox(height: ctx.rsi(8)),
                        WorkerMgmtHidContent(
                          workerHid: hid!,
                          displayName: user.uname,
                          embedInScrollView: false,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
