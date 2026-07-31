import 'package:flutter/material.dart';
import 'package:w0001/ui/widget/app_loading_indicator.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:w0001/access/user_role_capabilities.dart';
import 'package:w0001/data/model/daily_quote_models.dart';
import 'package:w0001/presentation/viewmodel/auth_providers.dart';
import 'package:w0001/presentation/viewmodel/daily_quote_providers.dart';
import 'package:w0001/theme/app_section_card.dart';
import 'package:w0001/ui/screen/1_dashboard/widgets/daily_quote_dashboard_section.dart';
import 'package:w0001/ui/widget/app_refresh_indicator.dart';
import 'package:w0001/ui/widget/app_text_field.dart';
import 'package:w0001/util/responsive_layout.dart';

class DailyQuoteManagementScreen extends ConsumerWidget {
  const DailyQuoteManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authSessionProvider).asData?.value;
    if (user != null && !user.role.canManageExtras) {
      return Scaffold(
        appBar: AppBar(title: const Text('오늘의 명언 관리')),
        body: const Center(child: Text('이 기능을 관리할 권한이 없습니다.')),
      );
    }

    final state = ref.watch(dailyQuoteAdminProvider);
    final notifier = ref.read(dailyQuoteAdminProvider.notifier);
    final cs = Theme.of(context).colorScheme;

    ref.listen(dailyQuoteAdminProvider, (previous, next) {
      if (next.error == null || next.error == previous?.error) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(next.error!)),
      );
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('오늘의 명언 관리'),
        actions: [
          IconButton(
            tooltip: '새로고침',
            onPressed: state.isLoading ? null : () => notifier.load(),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: state.isSaving
            ? null
            : () => _openQuoteEditor(context, ref, existing: null),
        icon: const Icon(Icons.add_rounded),
        label: const Text('명언 추가'),
      ),
      body: AppRefreshIndicator(
        enabled: !state.isLoading,
        onRefresh: () => notifier.load(),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(
            context.rsi(16),
            context.rsi(12),
            context.rsi(16),
            MediaQuery.paddingOf(context).bottom + context.rsi(96),
          ),
          children: [
            AppSectionCard(
              title: '오늘 표시 중',
              icon: Icons.today_outlined,
              subtitle: state.today?.isOverride == true
                  ? '관리자가 오늘만 직접 지정한 내용입니다.'
                  : '활성 명언 풀에서 자동 선정된 내용입니다.',
              child: Padding(
                padding: EdgeInsets.all(context.rsi(16)),
                child: state.isLoading && state.today == null
                    ? const AppLoadingIndicator()
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const DailyQuoteCardBody(),
                          SizedBox(height: context.rsi(14)),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (state.today?.isOverride == true) ...[
                                TextButton.icon(
                                  onPressed: state.isSaving
                                      ? null
                                      : () => _clearOverride(context, ref),
                                  icon: const Icon(Icons.restart_alt_rounded),
                                  label: const Text('자동으로 되돌리기'),
                                ),
                                SizedBox(width: context.rsi(12)),
                              ],
                              FilledButton.tonalIcon(
                                onPressed: state.isSaving
                                    ? null
                                    : () => _openTodayEditor(context, ref),
                                icon: const Icon(Icons.edit_calendar_outlined),
                                label: const Text('오늘만 직접 지정'),
                              ),
                            ],
                          ),
                        ],
                      ),
              ),
            ),
            SizedBox(height: context.rsi(24)),
            AppSectionCard(
              title: '자동 표시 설정',
              icon: Icons.autorenew_rounded,
              subtitle: '매일 00:00(Asia/Seoul)에 새 명언으로 전환됩니다.',
              child: Padding(
                padding: EdgeInsets.all(context.rsi(16)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      '선정 방식',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    SizedBox(height: context.rsi(10)),
                    SegmentedButton<DailyQuoteRotationMode>(
                      segments: const [
                        ButtonSegment(
                          value: DailyQuoteRotationMode.random,
                          icon: Icon(Icons.shuffle_rounded),
                          label: Text('랜덤'),
                        ),
                        ButtonSegment(
                          value: DailyQuoteRotationMode.sequential,
                          icon: Icon(Icons.sort_rounded),
                          label: Text('순차'),
                        ),
                      ],
                      selected: {state.settings.mode},
                      onSelectionChanged: state.isSaving
                          ? null
                          : (selection) {
                              notifier.updateSettings(
                                state.settings.copyWith(mode: selection.first),
                              );
                            },
                    ),
                    SizedBox(height: context.rsi(12)),
                    DropdownButtonFormField<int>(
                      value: state.settings.recentHistoryLimit,
                      decoration: const InputDecoration(
                        labelText: '중복 방지 기간',
                        prefixIcon: Icon(Icons.history_rounded),
                      ),
                      items: ({
                        7,
                        14,
                        30,
                        60,
                        90,
                        state.settings.recentHistoryLimit,
                      }.toList()
                            ..sort())
                          .map(
                            (days) => DropdownMenuItem(
                              value: days,
                              child: Text('최근 $days일 동안 같은 명언 제외'),
                            ),
                          )
                          .toList(),
                      onChanged: state.isSaving
                          ? null
                          : (value) {
                              if (value == null) return;
                              notifier.updateSettings(
                                state.settings
                                    .copyWith(recentHistoryLimit: value),
                              );
                            },
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: context.rsi(24)),
            AppSectionCard(
              title: '명언 풀',
              icon: Icons.format_quote_rounded,
              subtitle: '총 ${state.items.length}개 · 비활성 명언은 자동 선정에서 제외',
              child: Column(
                children: [
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      context.rsi(16),
                      context.rsi(16),
                      context.rsi(16),
                      context.rsi(8),
                    ),
                    child: Column(
                      children: [
                        AppTextField(
                          textInputAction: TextInputAction.search,
                          decoration: InputDecoration(
                            hintText: '내용 또는 저자 검색',
                            prefixIcon: const Icon(Icons.search_rounded),
                            suffixIcon: state.query.isEmpty
                                ? null
                                : IconButton(
                                    tooltip: '검색 초기화',
                                    onPressed: () => notifier.search(''),
                                    icon: const Icon(Icons.close_rounded),
                                  ),
                          ),
                          onSubmitted: notifier.search,
                        ),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          value: state.showInactive,
                          title: const Text('비활성 명언 함께 보기'),
                          onChanged: notifier.setShowInactive,
                        ),
                      ],
                    ),
                  ),
                  if (state.isLoading)
                    Padding(
                      padding: EdgeInsets.symmetric(vertical: context.rsi(36)),
                      child: const AppLoadingIndicator(),
                    )
                  else if (state.items.isEmpty)
                    _EmptyQuotes(onAdd: () => _openQuoteEditor(context, ref))
                  else
                    Padding(
                      padding: EdgeInsets.fromLTRB(
                        context.rsi(16),
                        0,
                        context.rsi(16),
                        context.rsi(16),
                      ),
                      child: Column(
                        children: state.items
                            .map(
                              (quote) => Padding(
                                padding:
                                    EdgeInsets.only(bottom: context.rsi(10)),
                                child: _QuoteListCard(
                                  quote: quote,
                                  onSetToday: () =>
                                      _setQuoteAsToday(context, ref, quote),
                                  onEdit: () => _openQuoteEditor(context, ref,
                                      existing: quote),
                                  onToggleActive: () => notifier.saveQuote(
                                    quote.copyWith(isActive: !quote.isActive),
                                  ),
                                  onDelete: () =>
                                      _deleteQuote(context, ref, quote),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ),
                  if (state.isSaving)
                    Padding(
                      padding: EdgeInsets.only(top: context.rsi(8)),
                      child: LinearProgressIndicator(color: cs.primary),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openQuoteEditor(
    BuildContext context,
    WidgetRef ref, {
    DailyQuote? existing,
  }) async {
    final value = await showDialog<DailyQuote>(
      context: context,
      builder: (_) => _QuoteEditDialog(existing: existing),
    );
    if (value == null || !context.mounted) return;
    final ok =
        await ref.read(dailyQuoteAdminProvider.notifier).saveQuote(value);
    if (ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(existing == null ? '명언을 추가했습니다.' : '명언을 수정했습니다.')),
      );
    }
  }

  Future<void> _openTodayEditor(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final current = ref.read(dailyQuoteAdminProvider).today?.quote;
    final value = await showDialog<DailyQuote>(
      context: context,
      builder: (_) => _QuoteEditDialog(
        existing: current,
        title: '오늘만 직접 지정',
        hideActive: true,
      ),
    );
    if (value == null || !context.mounted) return;
    final ok = await ref.read(dailyQuoteAdminProvider.notifier).overrideToday(
          author: value.author,
          authorProfile: value.authorProfile,
          message: value.message,
        );
    if (ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('오늘의 명언을 지정했습니다. 내일은 자동 모드로 돌아갑니다.')),
      );
    }
  }

  Future<void> _clearOverride(BuildContext context, WidgetRef ref) async {
    final ok =
        await ref.read(dailyQuoteAdminProvider.notifier).clearTodayOverride();
    if (ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('오늘 명언을 자동 선정으로 되돌렸습니다.')),
      );
    }
  }

  Future<void> _setQuoteAsToday(
    BuildContext context,
    WidgetRef ref,
    DailyQuote quote,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('오늘의 명언으로 지정'),
        content: Text(
          '「${quote.message}」\n\n이 명언을 오늘 표시할 내용으로 지정할까요?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('취소'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(dialogContext, true),
            icon: const Icon(Icons.today_outlined),
            label: const Text('오늘 지정'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final ok = await ref.read(dailyQuoteAdminProvider.notifier).overrideToday(
          author: quote.author,
          authorProfile: quote.authorProfile,
          message: quote.message,
        );
    if (ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('선택한 명언을 오늘의 명언으로 지정했습니다.'),
        ),
      );
    }
  }

  Future<void> _deleteQuote(
    BuildContext context,
    WidgetRef ref,
    DailyQuote quote,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('명언 삭제'),
        content: Text('「${quote.message}」을(를) 삭제할까요?\n사용 이력은 유지됩니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final ok =
        await ref.read(dailyQuoteAdminProvider.notifier).deleteQuote(quote.id);
    if (ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('명언을 삭제했습니다.')),
      );
    }
  }
}

class _QuoteListCard extends StatelessWidget {
  const _QuoteListCard({
    required this.quote,
    required this.onSetToday,
    required this.onEdit,
    required this.onToggleActive,
    required this.onDelete,
  });

  final DailyQuote quote;
  final VoidCallback onSetToday;
  final VoidCallback onEdit;
  final VoidCallback onToggleActive;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Card(
      margin: EdgeInsets.zero,
      color: quote.isActive ? null : cs.surfaceContainerLowest,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          context.rsi(16),
          context.rsi(14),
          context.rsi(8),
          context.rsi(12),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: context.rsi(34),
              height: context.rsi(34),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: quote.isActive
                    ? cs.tertiaryContainer
                    : cs.surfaceContainerHighest,
                shape: BoxShape.circle,
              ),
              child: Text(
                '#${quote.id}',
                style: tt.labelSmall?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
            SizedBox(width: context.rsi(12)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    quote.message,
                    style: tt.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      height: 1.4,
                      color: quote.isActive ? null : cs.onSurfaceVariant,
                    ),
                  ),
                  SizedBox(height: context.rsi(10)),
                  Container(
                    width: context.rsi(24),
                    height: context.rsi(2),
                    decoration: BoxDecoration(
                      color: cs.tertiary.withValues(alpha: 0.45),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  SizedBox(height: context.rsi(8)),
                  Text(
                    quote.author,
                    style: tt.bodySmall?.copyWith(
                      color:
                          quote.isActive ? cs.onSurface : cs.onSurfaceVariant,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (quote.authorProfile.trim().isNotEmpty) ...[
                    SizedBox(height: context.rsi(2)),
                    Text(
                      quote.authorProfile,
                      style: tt.labelSmall?.copyWith(
                        color: cs.onSurfaceVariant.withValues(alpha: 0.85),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                  SizedBox(height: context.rsi(10)),
                  _StatusBadge(isActive: quote.isActive),
                ],
              ),
            ),
            PopupMenuButton<String>(
              onSelected: (value) {
                switch (value) {
                  case 'today':
                    onSetToday();
                    return;
                  case 'edit':
                    onEdit();
                    return;
                  case 'toggle':
                    onToggleActive();
                    return;
                  case 'delete':
                    onDelete();
                    return;
                }
              },
              itemBuilder: (_) => [
                const PopupMenuItem(
                  value: 'today',
                  child: Row(
                    children: [
                      Icon(Icons.today_outlined),
                      SizedBox(width: 10),
                      Text('오늘의 명언으로 지정'),
                    ],
                  ),
                ),
                const PopupMenuDivider(),
                const PopupMenuItem(value: 'edit', child: Text('수정')),
                PopupMenuItem(
                  value: 'toggle',
                  child: Text(quote.isActive ? '비활성화' : '활성화'),
                ),
                const PopupMenuDivider(),
                const PopupMenuItem(value: 'delete', child: Text('삭제')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.isActive});

  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: context.rsi(8),
        vertical: context.rsi(3),
      ),
      decoration: BoxDecoration(
        color: isActive ? cs.primaryContainer : cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        isActive ? '활성' : '비활성',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: isActive ? cs.onPrimaryContainer : cs.onSurfaceVariant,
              fontWeight: FontWeight.w800,
            ),
      ),
    );
  }
}

class _EmptyQuotes extends StatelessWidget {
  const _EmptyQuotes({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: context.rsi(32)),
      child: Column(
        children: [
          Icon(
            Icons.format_quote_rounded,
            size: context.rsi(40),
            color: Theme.of(context).colorScheme.outline,
          ),
          SizedBox(height: context.rsi(8)),
          const Text('조건에 맞는 명언이 없습니다.'),
          TextButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add_rounded),
            label: const Text('첫 명언 추가'),
          ),
        ],
      ),
    );
  }
}

class _QuoteEditDialog extends StatefulWidget {
  const _QuoteEditDialog({
    this.existing,
    this.title,
    this.hideActive = false,
  });

  final DailyQuote? existing;
  final String? title;
  final bool hideActive;

  @override
  State<_QuoteEditDialog> createState() => _QuoteEditDialogState();
}

class _QuoteEditDialogState extends State<_QuoteEditDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _messageController;
  late final TextEditingController _authorController;
  late final TextEditingController _profileController;
  late bool _isActive;

  @override
  void initState() {
    super.initState();
    final quote = widget.existing;
    _messageController = TextEditingController(text: quote?.message ?? '');
    _authorController = TextEditingController(text: quote?.author ?? '');
    _profileController =
        TextEditingController(text: quote?.authorProfile ?? '');
    _isActive = quote?.isActive ?? true;
  }

  @override
  void dispose() {
    _messageController.dispose();
    _authorController.dispose();
    _profileController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    Navigator.pop(
      context,
      DailyQuote(
        id: widget.existing?.id ?? 0,
        message: _messageController.text.trim(),
        author: _authorController.text.trim(),
        authorProfile: _profileController.text.trim(),
        isActive: _isActive,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.title ?? (widget.existing == null ? '명언 추가' : '명언 수정'),
      ),
      content: SizedBox(
        width: 520,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppTextFormField(
                  controller: _messageController,
                  minLines: 3,
                  maxLines: 6,
                  maxLength: 500,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: '명언 내용 *',
                    alignLabelWithHint: true,
                  ),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? '내용을 입력해 주세요.'
                      : null,
                ),
                SizedBox(height: context.rsi(10)),
                AppTextFormField(
                  controller: _authorController,
                  maxLength: 100,
                  decoration: const InputDecoration(labelText: '저자 *'),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? '저자를 입력해 주세요.'
                      : null,
                ),
                SizedBox(height: context.rsi(10)),
                AppTextFormField(
                  controller: _profileController,
                  maxLength: 100,
                  decoration: const InputDecoration(
                    labelText: '저자 소개',
                    hintText: '예: 철학자',
                  ),
                ),
                if (!widget.hideActive)
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _isActive,
                    title: const Text('자동 선정에 사용'),
                    subtitle: Text(_isActive ? '활성 상태' : '비활성 상태'),
                    onChanged: (value) => setState(() => _isActive = value),
                  ),
                if (widget.hideActive)
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text('이 설정은 오늘 자정까지만 유지됩니다.'),
                  ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('취소'),
        ),
        FilledButton(onPressed: _submit, child: const Text('저장')),
      ],
    );
  }
}
