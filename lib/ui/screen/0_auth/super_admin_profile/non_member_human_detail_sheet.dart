import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:w0001/data/mappers/remote_mappers.dart';
import 'package:w0001/data/model/human_model.dart';
import 'package:w0001/data/model/remote/super_admin_dtos.dart';
import 'package:w0001/domain/data_change_event.dart';
import 'package:w0001/domain/use_case/human_use_case.dart';
import 'package:w0001/domain/use_case/super_admin_remote_use_case.dart';
import 'package:w0001/presentation/viewmodel/place_list_view_model.dart';
import 'package:w0001/presentation/viewmodel/super_admin_remote_providers.dart';
import 'package:w0001/ui/screen/0_auth/super_admin_profile/admin_member_private_info_section.dart';
import 'package:w0001/ui/screen/0_auth/widgets/profile_section_chrome.dart';
import 'package:w0001/ui/screen/0_auth/worker_mgmt/worker_mgmt_hid_content.dart';
import 'package:w0001/ui/screen/4_human/widgets/human_editor_dialog.dart';
import 'package:w0001/ui/widget/human_picker/human_picker_skill_panel.dart';
import 'package:w0001/ui/widget/worker_profile/worker_career_field.dart';
import 'package:w0001/ui/widget/worker_profile/worker_profile_human_fields_panel.dart';
import 'package:w0001/ui/widget/worker_profile/worker_profile_info_row.dart';
import 'package:w0001/ui/widget/app_refresh_indicator.dart';
import 'package:w0001/util/career_input.dart';
import 'package:w0001/util/fetch_data.dart';
import 'package:w0001/util/responsive_layout.dart';
import 'package:w0001/util/worker_skills_display.dart';

/// 회원관리 · 비회원 탭 — 직접 등록 인력 상세 (회원 상세와 동일 양식).
class NonMemberHumanDetailSheet extends ConsumerStatefulWidget {
  const NonMemberHumanDetailSheet({
    super.key,
    required this.initialHuman,
  });

  final HumanRead initialHuman;

  @override
  ConsumerState<NonMemberHumanDetailSheet> createState() =>
      _NonMemberHumanDetailSheetState();
}

class _NonMemberHumanDetailSheetState
    extends ConsumerState<NonMemberHumanDetailSheet> {
  HumanRead? _human;
  var _busy = false;
  String _careerDraft = '';

  SuperAdminRemoteUseCase get _uc => ref.read(superAdminRemoteUseCaseProvider);

  HumanUseCase get _humanUseCase => ref.read(humanUseCaseProvider);

  HumanRead get _display => _human ?? widget.initialHuman;

  @override
  void initState() {
    super.initState();
    _careerDraft =
        CareerInputUtils.formatForDisplay(widget.initialHuman.career);
    Future.microtask(_reload);
  }

  Future<void> _reload() async {
    if (!mounted) return;
    setState(() => _busy = true);
    try {
      final fresh = await _uc.humanGet(widget.initialHuman.hid);
      if (!mounted) return;
      setState(() {
        _human = fresh;
        _careerDraft = fresh.career;
        _busy = false;
      });
    } catch (_) {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _saveCareer(String career) async {
    final hid = _display.hid;
    try {
      final updated = await _uc.humanPatch(
        hid,
        {'career': CareerInputUtils.careerForApi(career)},
      );
      if (!mounted) return;
      setState(() {
        _human = updated;
        _careerDraft = updated.career;
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
    final hid = model.hid;
    if (hid == null) return;
    try {
      final fresh = await _uc.humanGet(hid);
      if (!mounted) return;
      setState(() => _human = fresh);
    } catch (_) {}
  }

  Future<void> _openEditor() async {
    await showHumanEditorDialog(
      context: context,
      ref: ref,
      editHuman: humanReadToModel(_display),
    );
    if (mounted) await _reload();
  }

  Future<void> _deleteNonMember() async {
    final hid = _display.hid;
    final name = _display.hname;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('삭제'),
        content: Text('$name 님을 삭제할까요?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              '삭제',
              style: TextStyle(color: Theme.of(ctx).colorScheme.error),
            ),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    setState(() => _busy = true);
    try {
      await _humanUseCase.deleteWorker(hid);
      await FetchData.onDataChanged(DataChangeEvent.humanSaved);
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('\'$name\' 인력을 삭제했습니다.')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('삭제 실패: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final bottom = MediaQuery.paddingOf(context).bottom;
    final h = _display;
    final humanModel = humanReadToModel(h);
    final siteRank = resolveHumanSiteRank(humanModel);

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
                onRefresh: _reload,
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
                        children: [
                          Expanded(
                            child: Text(
                              h.hname,
                              style: tt.titleMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (siteRank != null && siteRank.isNotEmpty)
                            HumanPickerSiteRankBadge(label: siteRank),
                          SizedBox(width: ctx.rsi(8)),
                          IconButton(
                            tooltip: '삭제',
                            onPressed: _busy ? null : _deleteNonMember,
                            icon: Icon(
                              Icons.delete_outline_rounded,
                              color: cs.error,
                            ),
                          ),
                          FilledButton.tonalIcon(
                            onPressed: _busy ? null : _openEditor,
                            icon: const Icon(Icons.edit_outlined, size: 18),
                            label: const Text('수정'),
                            style: FilledButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                              padding: EdgeInsets.symmetric(
                                horizontal: ctx.rsi(12),
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: ctx.rsi(6)),
                      Text(
                        '비회원 · 직접 등록 인력',
                        style: tt.labelMedium?.copyWith(
                          color: cs.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
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
                            if (h.hdefaultrole.trim().isNotEmpty)
                              WorkerProfileInfoRow(
                                label: '기본 역할',
                                value: h.hdefaultrole.trim(),
                              ),
                            if (h.hmemo != null && h.hmemo!.trim().isNotEmpty)
                              WorkerProfileInfoRow(
                                label: '메모',
                                value: h.hmemo!.trim(),
                              ),
                            if (h.hdefaultrole.trim().isEmpty &&
                                (h.hmemo == null || h.hmemo!.trim().isEmpty))
                              Text(
                                '등록된 기본 정보가 없습니다.',
                                style: tt.bodySmall?.copyWith(
                                  color: cs.onSurfaceVariant,
                                ),
                              ),
                          ],
                        ),
                      ),
                      SizedBox(height: ctx.rsi(14)),
                      ProfileInsetPanel(
                        padding: EdgeInsets.all(ctx.rsi(12)),
                        child: WorkerProfileHumanFieldsPanel(
                          human: humanModel,
                          onUpdated: _onWorkFieldsUpdated,
                        ),
                      ),
                      SizedBox(height: ctx.rsi(14)),
                      const ProfileSectionTitle('경력'),
                      SizedBox(height: ctx.rsi(8)),
                      ProfileInsetPanel(
                        padding: EdgeInsets.all(ctx.rsi(12)),
                        child: WorkerCareerField(
                          career: _careerDraft,
                          readOnlyUntilEdit: true,
                          autoCommit: false,
                          compact: true,
                          onChanged: _saveCareer,
                        ),
                      ),
                      SizedBox(height: ctx.rsi(14)),
                      const ProfileSectionTitle('세무·정산 정보'),
                      SizedBox(height: ctx.rsi(8)),
                      AdminMemberPrivateInfoSection(human: humanModel),
                      SizedBox(height: ctx.rsi(14)),
                      const ProfileSectionTitle('인력 관리'),
                      SizedBox(height: ctx.rsi(8)),
                      WorkerMgmtHidContent(
                        workerHid: h.hid,
                        displayName: h.hname,
                        embedInScrollView: false,
                      ),
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
