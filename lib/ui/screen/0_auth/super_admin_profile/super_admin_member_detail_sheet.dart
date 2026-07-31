import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:w0001/data/mappers/remote_mappers.dart';
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
import 'package:w0001/ui/widget/human_picker/human_picker_skill_panel.dart';
import 'package:w0001/ui/widget/worker_profile/worker_career_field.dart';
import 'package:w0001/ui/widget/worker_profile/worker_profile_human_fields_panel.dart';
import 'package:w0001/ui/widget/worker_profile/worker_profile_info_row.dart';
import 'package:w0001/ui/widget/app_refresh_indicator.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:w0001/util/career_input.dart';
import 'package:w0001/util/responsive_layout.dart';
import 'package:w0001/util/worker_skills_display.dart';

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
  HumanRead? _linkedHuman;
  int? _hid;
  HumanModel? _skillsHuman;
  var _detailBusy = false;
  Object? _loadError;
  String _careerDraft = '';

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
      HumanRead? linked;
      int? hidResolved;

      if (fresh.workerHid != null && fresh.workerHid! > 0) {
        hidResolved = fresh.workerHid;
        try {
          linked = await _uc.humanGet(hidResolved!);
        } catch (_) {}
      } else {
        final dir = ref.read(workerMgmtHumanDirectoryProvider);
        if (!dir.fullyLoaded && dir.humans.isEmpty) {
          await ref
              .read(workerMgmtHumanDirectoryProvider.notifier)
              .ensureLoaded();
        }
        final humans = ref.read(workerMgmtHumanDirectoryProvider).humans;
        hidResolved = resolveWorkerHidForMember(fresh, humans);
        linked =
            hidResolved != null ? findHumanReadForMember(fresh, humans) : null;
        if (hidResolved != null && linked == null) {
          try {
            linked = await _uc.humanGet(hidResolved);
          } catch (_) {}
        }
      }

      final skillsHuman = humanModelForMemberSkills(
        fresh,
        linkedHuman: linked,
      );
      if (!mounted) return;
      setState(() {
        _userFresh = fresh;
        _hid = hidResolved;
        _linkedHuman = linked;
        _skillsHuman = skillsHuman;
        _careerDraft = CareerInputUtils.formatForDisplay(
          linked?.career.trim().isNotEmpty == true
              ? linked!.career
              : fresh.career,
        );
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

  Future<void> _saveCareer(String career) async {
    final hid = _hid;
    if (hid == null) return;
    try {
      final updated = await _uc.humanPatch(
        hid,
        {'career': CareerInputUtils.careerForApi(career)},
      );
      if (!mounted) return;
      setState(() {
        _linkedHuman = updated;
        _careerDraft = CareerInputUtils.formatForDisplay(updated.career);
        _skillsHuman = humanModelForMemberSkills(
          _displayUser,
          linkedHuman: updated,
        );
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('경력을 저장했습니다.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('경력 저장 실패: $e')),
      );
    }
  }

  Future<void> _onWorkFieldsUpdated(HumanModel model) async {
    if (!mounted) return;
    setState(() => _skillsHuman = model);
    final hid = model.hid;
    if (hid == null) return;
    try {
      final fresh = await _uc.humanGet(hid);
      if (!mounted) return;
      setState(() => _linkedHuman = fresh);
      ref.invalidate(workerMgmtHumanDirectoryProvider);
    } catch (_) {}
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
    final linked = _linkedHuman;
    final skillsHuman = _skillsHuman;
    final siteRank = skillsHuman != null
        ? resolveHumanSiteRank(skillsHuman)
        : (user.role == UserRole.worker && user.workerRank.trim().isNotEmpty
            ? user.workerRank.trim()
            : null);
    final hasSiteRank = siteRank != null && siteRank.isNotEmpty;

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
              child: AppRefreshIndicator(
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
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Flexible(
                            fit: FlexFit.loose,
                            child: Text(
                              user.uname,
                              style: tt.titleMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.3,
                                height: 1.2,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (hasSiteRank) ...[
                            SizedBox(width: ctx.rsi(8)),
                            HumanPickerSiteRankBadge(label: siteRank),
                          ],
                        ],
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
                      const ProfileSectionTitle('기본 정보'),
                      SizedBox(height: ctx.rsi(8)),
                      ProfileInsetPanel(
                        padding: EdgeInsets.symmetric(
                          horizontal: ctx.rsi(12),
                          vertical: ctx.rsi(6),
                        ),
                        child: Column(
                          children: [
                            WorkerProfileInfoRow(
                              label: '아이디',
                              value: user.uid,
                            ),
                            if (user.phoneMasked != null &&
                                user.phoneMasked!.isNotEmpty)
                              WorkerProfileInfoRow(
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
                            if (hid != null)
                              WorkerProfileInfoRow(
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
                      if (hid != null && linked != null) ...[
                        SizedBox(height: ctx.rsi(14)),
                        ProfileInsetPanel(
                          padding: EdgeInsets.all(ctx.rsi(12)),
                          child: WorkerProfileHumanFieldsPanel(
                            human: humanReadToModel(linked),
                            onUpdated: _onWorkFieldsUpdated,
                          ),
                        ),
                      ] else if (user.role == UserRole.worker) ...[
                        SizedBox(height: ctx.rsi(14)),
                        ProfileInsetPanel(
                          padding: EdgeInsets.all(ctx.rsi(12)),
                          child: Text(
                            '인력 연결 후 현장 역할·일당·작업 분야를 수정할 수 있습니다.',
                            style: tt.bodyMedium?.copyWith(
                              color: cs.onSurfaceVariant,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                      SizedBox(height: ctx.rsi(14)),
                      const ProfileSectionTitle('경력'),
                      SizedBox(height: ctx.rsi(8)),
                      ProfileInsetPanel(
                        padding: EdgeInsets.all(ctx.rsi(12)),
                        child: hid != null
                            ? WorkerCareerField(
                                career: _careerDraft,
                                readOnlyUntilEdit: true,
                                autoCommit: false,
                                compact: true,
                                onChanged: _saveCareer,
                              )
                            : Text(
                                user.career.isNotEmpty
                                    ? CareerInputUtils.formatForDisplay(
                                        user.career,
                                      )
                                    : '인력 연결 후 경력을 수정할 수 있습니다.',
                                style: tt.bodyMedium?.copyWith(
                                  color: cs.onSurfaceVariant,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                      if (user.role == UserRole.worker) ...[
                        SizedBox(height: ctx.rsi(14)),
                        const ProfileSectionTitle('세무·정산 정보'),
                        SizedBox(height: ctx.rsi(8)),
                        AdminMemberPrivateInfoSection(
                          workerUid: user.uid,
                          human:
                              linked != null ? humanReadToModel(linked) : null,
                        ),
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
                          color:
                              user.approvalStatus == UserApprovalStatus.pending
                                  ? cs.errorContainer.withValues(alpha: 0.32)
                                  : cs.surfaceContainerHighest
                                      .withValues(alpha: 0.55),
                          borderRadius: BorderRadius.circular(ctx.rsi(12)),
                          child: Padding(
                            padding: EdgeInsets.all(ctx.rsi(12)),
                            child: Text(
                              user.approvalStatus == UserApprovalStatus.pending
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
