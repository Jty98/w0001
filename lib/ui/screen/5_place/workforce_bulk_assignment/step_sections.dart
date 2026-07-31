import 'package:flutter/material.dart';
import 'package:w0001/util/responsive_layout.dart';

class BulkStep0Section extends StatelessWidget {
  const BulkStep0Section({
    super.key,
    required this.stepTitle,
    required this.onAddProcess,
    required this.processList,
  });

  final String stepTitle;
  final VoidCallback onAddProcess;
  final Widget processList;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    stepTitle,
                    style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  SizedBox(height: context.rsi(2)),
                  Text(
                    '공정을 선택하고 투입 기간을 지정하세요',
                    style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: onAddProcess,
              icon: const Icon(Icons.add),
              tooltip: '공정 추가',
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
        SizedBox(height: context.rsi(12)),
        processList,
      ],
    );
  }
}

class BulkStep1Section extends StatelessWidget {
  const BulkStep1Section({
    super.key,
    required this.stepTitle,
    required this.isSearching,
    required this.recentWorkerCount,
    required this.searchHintText,
    required this.searchQuery,
    required this.onSearchChanged,
    required this.onClearSearch,
    required this.onShowSearchFilter,
    required this.onAddWorker,
    required this.onShowRecentWorkersFullList,
    required this.showRecentWorkersFullList,
    required this.workersGrid,
    this.selectedSummary,
  });

  final String stepTitle;
  final bool isSearching;
  final int recentWorkerCount;
  final String searchHintText;
  final String searchQuery;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onClearSearch;
  final VoidCallback onShowSearchFilter;
  final VoidCallback onAddWorker;
  final VoidCallback onShowRecentWorkersFullList;
  final bool showRecentWorkersFullList;
  final Widget workersGrid;
  final Widget? selectedSummary;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    stepTitle,
                    style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  SizedBox(height: context.rsi(2)),
                  Text(
                    isSearching
                        ? '전체 인력 검색'
                        : '이 현장에서 일했던 인력 ($recentWorkerCount명)',
                    style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            if (showRecentWorkersFullList)
              TextButton(
                onPressed: onShowRecentWorkersFullList,
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.symmetric(horizontal: context.rsi(8)),
                ),
                child: const Text('전체보기'),
              ),
          ],
        ),
        SizedBox(height: context.rsi(10)),
        Row(
          children: [
            Expanded(
              child: TextField(
                onChanged: onSearchChanged,
                decoration: InputDecoration(
                  hintText: searchHintText,
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: onClearSearch,
                        )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(context.rs(12)),
                  ),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: context.rsi(12),
                    vertical: context.rsi(10),
                  ),
                ),
              ),
            ),
            SizedBox(width: context.rsi(6)),
            IconButton.outlined(
              onPressed: onShowSearchFilter,
              icon: const Icon(Icons.tune_rounded, size: 20),
              tooltip: '검색 방식',
              visualDensity: VisualDensity.compact,
            ),
            SizedBox(width: context.rsi(4)),
            IconButton.outlined(
              onPressed: onAddWorker,
              icon: const Icon(Icons.person_add_alt_1, size: 20),
              tooltip: '인원 추가',
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
        SizedBox(height: context.rsi(10)),
        Text(
          '인력을 길게 누르면 상세 정보를 볼 수 있습니다.',
          style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
        ),
        SizedBox(height: context.rsi(8)),
        workersGrid,
        if (selectedSummary != null) ...[
          SizedBox(height: context.rsi(10)),
          selectedSummary!,
        ],
      ],
    );
  }
}

class BulkStep2Section extends StatelessWidget {
  const BulkStep2Section({
    super.key,
    required this.stepTitle,
    required this.financialSummary,
    required this.assignmentSummary,
    required this.workerDetails,
    required this.workInstruction,
    required this.saveError,
  });

  final String stepTitle;
  final Widget financialSummary;
  final Widget assignmentSummary;
  final Widget workerDetails;
  final Widget workInstruction;
  final String saveError;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          stepTitle,
          style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
        SizedBox(height: context.rsi(4)),
        Text(
          '투입 내용을 확인하고 완료하세요',
          style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
        ),
        SizedBox(height: context.rsi(14)),
        financialSummary,
        SizedBox(height: context.rsi(14)),
        assignmentSummary,
        SizedBox(height: context.rsi(14)),
        workerDetails,
        SizedBox(height: context.rsi(20)),
        workInstruction,
        if (saveError.isNotEmpty) ...[
          SizedBox(height: context.rsi(16)),
          Container(
            padding: ResponsiveLayout.all(context, 12),
            decoration: BoxDecoration(
              color: cs.errorContainer,
              borderRadius: BorderRadius.circular(context.rs(8)),
            ),
            child: Row(
              children: [
                Icon(Icons.error_outline, color: cs.error),
                SizedBox(width: context.rsi(8)),
                Expanded(
                  child: Text(
                    saveError,
                    style: tt.bodyMedium?.copyWith(color: cs.onErrorContainer),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
