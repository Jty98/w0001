import 'package:currency_text_input_formatter/currency_text_input_formatter.dart';
import 'package:flutter/material.dart';
import 'package:w0001/ui/widget/hammer_loading_indicator.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:w0001/data/model/worker_rank_wage_settings.dart';
import 'package:w0001/presentation/viewmodel/worker_rank_wage_settings_providers.dart';
import 'package:w0001/util/funtions.dart';
import 'package:w0001/util/responsive_layout.dart';
import 'package:w0001/util/worker_mgmt_messages.dart';
import 'package:w0001/theme/app_theme_colors.dart';
import 'package:w0001/ui/widget/app_loading_indicator.dart';
import 'package:w0001/ui/widget/app_refresh_indicator.dart';
import 'package:w0001/theme/app_section_card.dart';
import 'package:w0001/ui/widget/app_text_field.dart';

/// 설정 → 작업자 관리 — 현장 역할별 기본 일당.
class WorkerRankWageSettingsScreen extends ConsumerStatefulWidget {
  const WorkerRankWageSettingsScreen({super.key});

  @override
  ConsumerState<WorkerRankWageSettingsScreen> createState() =>
      _WorkerRankWageSettingsScreenState();
}

class _WorkerRankWageSettingsScreenState
    extends ConsumerState<WorkerRankWageSettingsScreen> {
  final _controllers = <String, TextEditingController>{};
  final _rankOrder = <String>[];
  var _dirty = false;
  var _saving = false;
  int? _appliedUpdatedAtMs;

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _applySettingsIfNeeded(WorkerRankWageSettings settings) {
    if (_dirty || !mounted) return;
    final stamp = settings.updatedAtMs;
    if (_appliedUpdatedAtMs == stamp && _rankOrder.isNotEmpty) return;

    final ranks = settings.orderedRanks();
    final wages = settings.normalizedWages();
    setState(() {
      _rankOrder
        ..clear()
        ..addAll(ranks);
      for (final rank in ranks) {
        final wage = wages[rank] ?? 0;
        final c = _controllers.putIfAbsent(rank, TextEditingController.new);
        final formatted = wage > 0 ? formatIntegerWithComma(wage) : '';
        if (c.text != formatted) c.text = formatted;
      }
      _appliedUpdatedAtMs = stamp;
    });
  }

  Map<String, int> _collectWages() {
    return {
      for (final rank in _rankOrder)
        rank: int.tryParse(
              _controllers[rank]?.text.replaceAll(RegExp(r'\D'), '') ?? '',
            ) ??
            0,
    };
  }

  Future<void> _save() async {
    if (_saving || _rankOrder.isEmpty) return;
    setState(() => _saving = true);
    final ok = await ref.read(workerRankWageSettingsProvider.notifier).save(
          rankOrder: List<String>.from(_rankOrder),
          wagesByRank: _collectWages(),
        );
    if (!mounted) return;
    setState(() {
      _saving = false;
      if (ok) {
        _dirty = false;
        _appliedUpdatedAtMs = null;
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok ? '역할별 기본 일당을 저장했습니다.' : '저장에 실패했습니다.'),
      ),
    );
  }

  Future<void> _showAddRankDialog() async {
    final nameCtrl = TextEditingController();
    final wageCtrl = TextEditingController();
    final added = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('역할 추가'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppTextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                  labelText: '역할명',
                  hintText: '예: 특수기공',
                ),
                textInputAction: TextInputAction.next,
              ),
              SizedBox(height: ctx.rsi(12)),
              AppTextField(
                controller: wageCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  CurrencyTextInputFormatter.currency(
                    locale: 'ko',
                    symbol: '',
                    decimalDigits: 0,
                  ),
                ],
                decoration: const InputDecoration(
                  labelText: '기본 일당',
                  suffixText: '원',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('취소'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('추가'),
            ),
          ],
        );
      },
    );
    if (added != true || !mounted) {
      nameCtrl.dispose();
      wageCtrl.dispose();
      return;
    }

    final name = nameCtrl.text.trim();
    final wage = int.tryParse(wageCtrl.text.replaceAll(RegExp(r'\D'), '')) ?? 0;
    nameCtrl.dispose();
    wageCtrl.dispose();

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('역할명을 입력해 주세요.')),
      );
      return;
    }
    if (_rankOrder.contains(name)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('이미 있는 역할입니다.')),
      );
      return;
    }

    setState(() {
      _rankOrder.add(name);
      final c = TextEditingController(
        text: wage > 0 ? formatIntegerWithComma(wage) : '',
      );
      _controllers[name] = c;
      _dirty = true;
    });
  }

  void _removeRank(String rank) {
    setState(() {
      _rankOrder.remove(rank);
      _controllers.remove(rank)?.dispose();
      _dirty = true;
    });
  }

  void _onReorder(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex -= 1;
      final item = _rankOrder.removeAt(oldIndex);
      _rankOrder.insert(newIndex, item);
      _dirty = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(workerRankWageSettingsProvider);
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    ref.listen(workerRankWageSettingsProvider, (prev, next) {
      final settings = next.value;
      if (settings != null) {
        _applySettingsIfNeeded(settings);
      }
    });

    final settings = async.value;
    if (settings != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _applySettingsIfNeeded(settings);
      });
    }

    return Scaffold(
      appBar: AppBar(
        centerTitle: false,
        title: const Text('역할별 기본 일당'),
        actions: [
          TextButton(
            onPressed: _saving || !_dirty ? null : _save,
            child: _saving
                ? SizedBox(
                    width: context.rsi(18),
                    height: context.rsi(18),
                    child: const HammerLoadingIndicator(size: 18),
                  )
                : const Text('저장'),
          ),
        ],
      ),
      body: async.when(
        loading: () => const AppLoadingIndicator(label: '역할별 일당 불러오는 중...'),
        error: (e, _) => Center(
          child: Padding(
            padding: EdgeInsets.all(context.rsi(24)),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  workerMgmtUserMessage(e),
                  textAlign: TextAlign.center,
                  style: tt.bodyMedium?.copyWith(color: cs.error),
                ),
                SizedBox(height: context.rsi(12)),
                FilledButton(
                  onPressed: () => ref
                      .read(workerRankWageSettingsProvider.notifier)
                      .refresh(),
                  child: const Text('다시 시도'),
                ),
              ],
            ),
          ),
        ),
        data: (settings) => AppRefreshIndicator(
          onRefresh: () async {
            await ref.read(workerRankWageSettingsProvider.notifier).refresh();
            if (mounted) {
              setState(() {
                _dirty = false;
                _appliedUpdatedAtMs = null;
              });
            }
          },
          child: ListView(
            padding: EdgeInsets.fromLTRB(
              context.rsi(16),
              context.rsi(12),
              context.rsi(16),
              context.rsi(24),
            ),
            children: [
              AppInsetTile(
                backgroundColor: cs.appIconBadge,
                padding: EdgeInsets.all(context.rsi(14)),
                child: Text(
                  '현장 역할을 선택하면 인력 일당 기본값으로 적용됩니다. '
                  '목록을 길게 눌러 순서를 바꿀 수 있고, 하단에서 역할을 추가할 수 있습니다.',
                  style: tt.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                    height: 1.45,
                  ),
                ),
              ),
              SizedBox(height: context.rsi(16)),
              if (_rankOrder.isEmpty)
                Padding(
                  padding: EdgeInsets.symmetric(vertical: context.rsi(24)),
                  child: Text(
                    '등록된 역할이 없습니다.\n아래 버튼으로 역할을 추가해 주세요.',
                    textAlign: TextAlign.center,
                    style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                  ),
                )
              else
                ReorderableListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  buildDefaultDragHandles: false,
                  onReorder: _onReorder,
                  itemCount: _rankOrder.length,
                  itemBuilder: (context, index) {
                    final rank = _rankOrder[index];
                    return _RankWageRow(
                      key: ValueKey(rank),
                      rank: rank,
                      index: index,
                      controller: _controllers.putIfAbsent(
                        rank,
                        TextEditingController.new,
                      ),
                      onChanged: () {
                        if (!_dirty) setState(() => _dirty = true);
                      },
                      onDelete: () => _removeRank(rank),
                    );
                  },
                ),
              SizedBox(height: context.rsi(16)),
              OutlinedButton.icon(
                onPressed: _showAddRankDialog,
                icon: const Icon(Icons.add_rounded),
                label: const Text('역할 추가'),
                style: OutlinedButton.styleFrom(
                  minimumSize: Size.fromHeight(context.rsi(48)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(context.rsi(12)),
                  ),
                ),
              ),
              SizedBox(height: context.rsi(12)),
              FilledButton.icon(
                onPressed:
                    _saving || !_dirty || _rankOrder.isEmpty ? null : _save,
                icon: const Icon(Icons.save_outlined),
                label: Text(_saving ? '저장 중…' : '저장'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RankWageRow extends StatelessWidget {
  const _RankWageRow({
    super.key,
    required this.rank,
    required this.index,
    required this.controller,
    required this.onChanged,
    required this.onDelete,
  });

  final String rank;
  final int index;
  final TextEditingController controller;
  final VoidCallback onChanged;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Padding(
      key: key,
      padding: EdgeInsets.only(bottom: context.rsi(10)),
      child: AppInsetTile(
        borderRadius: BorderRadius.circular(context.rsi(14)),
        padding: EdgeInsets.symmetric(
          horizontal: context.rsi(8),
          vertical: context.rsi(6),
        ),
        child: Row(
          children: [
            ReorderableDragStartListener(
              index: index,
              child: Padding(
                padding: EdgeInsets.all(context.rsi(6)),
                child: Icon(
                  Icons.drag_handle_rounded,
                  color: cs.onSurfaceVariant,
                  size: context.rs(22),
                ),
              ),
            ),
            Container(
              width: context.rsi(36),
              height: context.rsi(36),
              alignment: Alignment.center,
              decoration: AppSectionCardStyles.iconBadgeDecoration(context, cs),
              child: Text(
                rank.isNotEmpty ? rank[0] : '?',
                style: tt.labelLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: cs.primary,
                ),
              ),
            ),
            SizedBox(width: context.rsi(10)),
            Expanded(
              child: Text(
                rank,
                style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            SizedBox(
              width: context.rsi(120),
              child: AppTextField(
                controller: controller,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  CurrencyTextInputFormatter.currency(
                    locale: 'ko',
                    symbol: '',
                    decimalDigits: 0,
                  ),
                ],
                textAlign: TextAlign.right,
                style: tt.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
                decoration: InputDecoration(
                  isDense: true,
                  hintText: '0',
                  suffixText: '원',
                  suffixStyle: tt.labelMedium?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(context.rsi(10)),
                  ),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: context.rsi(10),
                    vertical: context.rsi(10),
                  ),
                ),
                onChanged: (_) => onChanged(),
              ),
            ),
            IconButton(
              tooltip: '삭제',
              visualDensity: VisualDensity.compact,
              onPressed: onDelete,
              icon: Icon(
                Icons.close_rounded,
                size: context.rs(20),
                color: cs.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
