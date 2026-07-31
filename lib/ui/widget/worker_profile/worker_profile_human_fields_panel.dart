import 'package:currency_text_input_formatter/currency_text_input_formatter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:w0001/data/model/human_model.dart';
import 'package:w0001/data/model/worker_profile_model.dart';
import 'package:w0001/presentation/viewmodel/place_list_view_model.dart'
    show humanUseCaseProvider;
import 'package:w0001/presentation/viewmodel/worker_rank_wage_settings_providers.dart';
import 'package:w0001/ui/screen/0_auth/widgets/worker_skills_editor.dart';
import 'package:w0001/ui/widget/human_picker/human_picker_skill_panel.dart';
import 'package:w0001/ui/widget/worker_profile/worker_profile_info_row.dart';
import 'package:w0001/util/funtions.dart';
import 'package:w0001/util/responsive_layout.dart';
import 'package:w0001/util/worker_skills_display.dart';

/// 현장 역할 · 일당 · 작업 분야 — 보기/수정 (회원·비회원 상세 공통).
class WorkerProfileHumanFieldsPanel extends ConsumerStatefulWidget {
  const WorkerProfileHumanFieldsPanel({
    super.key,
    required this.human,
    required this.onUpdated,
  });

  final HumanModel human;
  final ValueChanged<HumanModel> onUpdated;

  @override
  ConsumerState<WorkerProfileHumanFieldsPanel> createState() =>
      _WorkerProfileHumanFieldsPanelState();
}

class _WorkerProfileHumanFieldsPanelState
    extends ConsumerState<WorkerProfileHumanFieldsPanel> {
  var _editing = false;
  var _saving = false;
  late String _rank;
  late final TextEditingController _wageCtrl;
  final _skillsKey = GlobalKey<WorkerSkillsEditorState>();

  @override
  void initState() {
    super.initState();
    _applyHuman(widget.human);
    _wageCtrl = TextEditingController();
    _syncWageField(widget.human.hdailyWage);
  }

  @override
  void didUpdateWidget(WorkerProfileHumanFieldsPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.human.hid != widget.human.hid ||
        (!_editing &&
            (oldWidget.human.workerRank != widget.human.workerRank ||
                oldWidget.human.hdailyWage != widget.human.hdailyWage ||
                oldWidget.human.displayPrimarySpecialty !=
                    widget.human.displayPrimarySpecialty))) {
      _applyHuman(widget.human);
      _syncWageField(widget.human.hdailyWage);
      _skillsKey.currentState?.loadFromHuman(widget.human);
    }
  }

  @override
  void dispose() {
    _wageCtrl.dispose();
    super.dispose();
  }

  void _applyHuman(HumanModel h) {
    _rank = h.workerRank.trim();
  }

  List<String> _rankOptions() {
    final settings = ref.read(workerRankWageSettingsProvider).value;
    final ordered =
        settings?.orderedRanks() ?? List<String>.from(kWorkerRankOptions);
    final current = _rank.trim();
    if (current.isNotEmpty && !ordered.contains(current)) {
      return [...ordered, current];
    }
    return ordered;
  }

  void _selectRank(String rank) {
    setState(() => _rank = rank);
    if (rank.isEmpty) return;
    final wage =
        ref.read(workerRankWageSettingsUseCaseProvider).wageForRankSync(rank);
    if (wage != null) _syncWageField(wage);
  }

  void _syncWageField(int wage) {
    final fmt = CurrencyTextInputFormatter.currency(
      decimalDigits: 0,
      symbol: '',
    );
    _wageCtrl.text = fmt.formatString('$wage');
  }

  String _rankLabel(String rank) {
    final t = rank.trim();
    return t.isEmpty ? '미선택' : t;
  }

  int _parseWage() {
    final digits = _wageCtrl.text.replaceAll(RegExp(r'[^0-9]'), '');
    return int.tryParse(digits) ?? widget.human.hdailyWage;
  }

  void _cancelEdit() {
    _applyHuman(widget.human);
    _syncWageField(widget.human.hdailyWage);
    _skillsKey.currentState?.loadFromHuman(widget.human);
    setState(() => _editing = false);
  }

  Future<void> _save() async {
    if (_saving || widget.human.hid == null) return;
    setState(() => _saving = true);
    try {
      final skills = _skillsKey.currentState;
      final primary = skills?.primaryTrimmed ?? '';
      final updated = HumanModel(
        hid: widget.human.hid,
        uid: widget.human.uid,
        hname: widget.human.hname,
        hnumber: widget.human.hnumber,
        hmemo: widget.human.hmemo,
        hdailyWage: _parseWage(),
        hdefaultRole: widget.human.hdefaultRole,
        primarySpecialty: primary.isEmpty ? null : primary,
        specialties: widget.human.specialties,
        career: widget.human.career,
        workerRank: _rank,
        canBePlaceMember: widget.human.canBePlaceMember,
        linkedUserName: widget.human.linkedUserName,
        hphone: widget.human.hphone,
        linkedPhone: widget.human.linkedPhone,
        hstar: widget.human.hstar,
        hdelete: widget.human.hdelete,
      );
      final saved = await ref.read(humanUseCaseProvider).updateWorker(updated);
      if (!mounted) return;
      widget.onUpdated(saved);
      setState(() => _editing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('근무 정보를 저장했습니다.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('저장 실패: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final human = widget.human;
    final siteRank = resolveHumanSiteRank(human);
    final rankOptions = _rankOptions();

    if (!_editing) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '근무 정보',
                  style: tt.labelLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              TextButton.icon(
                onPressed:
                    _saving ? null : () => setState(() => _editing = true),
                icon: Icon(Icons.edit_outlined, size: context.rs(16)),
                label: const Text('수정'),
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ],
          ),
          SizedBox(height: context.rsi(8)),
          WorkerProfileInfoRow(
            label: '일당',
            value: getPrice(price: human.hdailyWage, isContainWon: true),
          ),
          WorkerProfileInfoRow(
            label: '현장 역할',
            value: _rankLabel(
              human.workerRank.isNotEmpty ? human.workerRank : (siteRank ?? ''),
            ),
          ),
          if (human.displayPrimarySpecialty?.trim().isNotEmpty == true) ...[
            SizedBox(height: context.rsi(8)),
            HumanPickerSkillPanel(human: human, showRrn: false),
          ] else
            Padding(
              padding: EdgeInsets.only(top: context.rsi(6)),
              child: Text(
                '등록된 작업 분야가 없습니다.',
                style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              ),
            ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '현장 역할',
          style: tt.labelMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: cs.onSurfaceVariant,
          ),
        ),
        SizedBox(height: context.rsi(8)),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              FilterChip(
                showCheckmark: false,
                padding: EdgeInsets.symmetric(horizontal: context.rsi(4)),
                visualDensity: VisualDensity.compact,
                label: Text('미선택', style: tt.labelSmall),
                selected: _rank.isEmpty,
                onSelected: (_) => _selectRank(''),
              ),
              for (final rank in rankOptions) ...[
                SizedBox(width: context.rsi(6)),
                FilterChip(
                  showCheckmark: false,
                  padding: EdgeInsets.symmetric(horizontal: context.rsi(4)),
                  visualDensity: VisualDensity.compact,
                  label: Text(rank, style: tt.labelSmall),
                  selected: _rank == rank,
                  onSelected: (_) => _selectRank(rank),
                ),
              ],
            ],
          ),
        ),
        SizedBox(height: context.rsi(14)),
        Text(
          '일당',
          style: tt.labelMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: cs.onSurfaceVariant,
          ),
        ),
        SizedBox(height: context.rsi(8)),
        TextField(
          controller: _wageCtrl,
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            CurrencyTextInputFormatter.currency(decimalDigits: 0, symbol: ''),
            LengthLimitingTextInputFormatter(22),
          ],
          decoration: InputDecoration(
            suffixText: '원',
            isDense: true,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(context.rsi(12)),
            ),
            contentPadding: EdgeInsets.symmetric(
              horizontal: context.rsi(12),
              vertical: context.rsi(10),
            ),
          ),
        ),
        SizedBox(height: context.rsi(14)),
        WorkerSkillsEditor(
          key: _skillsKey,
          compact: true,
          initialHuman: human,
          readOnlyUntilEdit: false,
        ),
        SizedBox(height: context.rsi(12)),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(
              onPressed: _saving ? null : _cancelEdit,
              child: const Text('취소'),
            ),
            SizedBox(width: context.rsi(8)),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: Text(_saving ? '저장 중…' : '저장'),
            ),
          ],
        ),
      ],
    );
  }
}
