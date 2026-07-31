import 'package:flutter/material.dart';
import 'package:w0001/ui/widget/app_loading_indicator.dart';
import 'package:w0001/util/responsive_layout.dart';

class BulkAssignmentSheetHeader extends StatelessWidget {
  const BulkAssignmentSheetHeader({
    super.key,
    required this.placeName,
    required this.onClose,
  });

  final String? placeName;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        context.rsi(16),
        context.rsi(4),
        context.rsi(8),
        context.rsi(10),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '기간별 일괄 인력투입',
                  style: tt.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (placeName != null) ...[
                  SizedBox(height: context.rsi(2)),
                  Text(
                    placeName!,
                    style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            onPressed: onClose,
            icon: Icon(Icons.close, size: context.rs(22)),
            visualDensity: VisualDensity.compact,
            color: cs.onSurfaceVariant,
          ),
        ],
      ),
    );
  }
}

class BulkAssignmentStepIndicator extends StatelessWidget {
  const BulkAssignmentStepIndicator({
    super.key,
    required this.currentStep,
  });

  final int currentStep;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    const labels = ['공정·기간', '인력', '확인'];

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: context.rsi(16)),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++) ...[
            if (i > 0)
              Expanded(
                child: Container(
                  height: 1,
                  margin: EdgeInsets.symmetric(horizontal: context.rsi(4)),
                  color: currentStep >= i
                      ? cs.primary.withValues(alpha: 0.45)
                      : cs.outlineVariant.withValues(alpha: 0.5),
                ),
              ),
            _StepChip(
              step: i,
              label: labels[i],
              currentStep: currentStep,
            ),
          ],
        ],
      ),
    );
  }
}

class _StepChip extends StatelessWidget {
  const _StepChip({
    required this.step,
    required this.label,
    required this.currentStep,
  });

  final int step;
  final String label;
  final int currentStep;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final isDone = currentStep > step;
    final isCurrent = currentStep == step;
    final active = isDone || isCurrent;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: context.rs(22),
          height: context.rs(22),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: active ? cs.primary : cs.surfaceContainerHighest,
            border: Border.all(
              color: active
                  ? cs.primary
                  : cs.outlineVariant.withValues(alpha: 0.55),
            ),
          ),
          child: Center(
            child: isDone
                ? Icon(Icons.check, size: context.rs(13), color: cs.onPrimary)
                : Text(
                    '${step + 1}',
                    style: tt.labelSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: isCurrent ? cs.onPrimary : cs.onSurfaceVariant,
                      fontSize: context.rs(11),
                    ),
                  ),
          ),
        ),
        SizedBox(width: context.rsi(5)),
        Text(
          label,
          style: tt.labelSmall?.copyWith(
            fontWeight: isCurrent ? FontWeight.w800 : FontWeight.w600,
            color: isCurrent ? cs.onSurface : cs.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class BulkAssignmentFinancialSummary extends StatelessWidget {
  const BulkAssignmentFinancialSummary({
    super.key,
    required this.loadingFinancialData,
    required this.placeRevenue,
    required this.totalExpenses,
    required this.selectedLaborCost,
    required this.formatCurrency,
  });

  final bool loadingFinancialData;
  final int placeRevenue;
  final int totalExpenses;
  final int selectedLaborCost;
  final String Function(int amount) formatCurrency;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    final currentCost = totalExpenses;
    final projectedCost = currentCost + selectedLaborCost;
    final remainingMargin = placeRevenue - projectedCost;
    final isOverBudget = remainingMargin < 0;

    if (loadingFinancialData) {
      return Container(
        padding: ResponsiveLayout.all(context, 20),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(context.rs(12)),
        ),
        child: const AppLoadingIndicator(
          size: 64,
          label: '재무 데이터 계산 중...',
        ),
      );
    }

    return Container(
      padding: EdgeInsets.all(context.rsi(12)),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(context.rs(10)),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '현장 재무 현황',
            style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          SizedBox(height: context.rsi(10)),
          _FinancialRow(
            icon: Icons.assignment_outlined,
            label: '공사금액',
            amount: placeRevenue,
            formatCurrency: formatCurrency,
          ),
          SizedBox(height: context.rsi(8)),
          _FinancialRow(
            icon: Icons.receipt_long_outlined,
            label: '현재 공사 원가',
            amount: currentCost,
            formatCurrency: formatCurrency,
          ),
          SizedBox(height: context.rsi(8)),
          _FinancialRow(
            icon: Icons.payments_outlined,
            label: '이번 투입 인건비',
            amount: selectedLaborCost,
            highlight: true,
            formatCurrency: formatCurrency,
          ),
          Divider(
              height: context.rsi(18),
              color: cs.outlineVariant.withValues(alpha: 0.4)),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '투입 후 공사 원가',
                style: tt.bodySmall?.copyWith(fontWeight: FontWeight.w700),
              ),
              Text(
                '${formatCurrency(projectedCost)}원',
                style: tt.bodyMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
            ],
          ),
          SizedBox(height: context.rsi(8)),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '잔여 마진',
                style: tt.bodySmall?.copyWith(fontWeight: FontWeight.w700),
              ),
              Text(
                '${isOverBudget ? '-' : ''}${formatCurrency(remainingMargin.abs())}원',
                style: tt.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: isOverBudget ? cs.error : cs.onSurface,
                ),
              ),
            ],
          ),
          if (isOverBudget) ...[
            SizedBox(height: context.rsi(8)),
            Text(
              '예산 초과 — 공사금액보다 원가가 높습니다.',
              style: tt.labelSmall?.copyWith(
                color: cs.error,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _FinancialRow extends StatelessWidget {
  const _FinancialRow({
    required this.icon,
    required this.label,
    required this.amount,
    required this.formatCurrency,
    this.highlight = false,
  });

  final IconData icon;
  final String label;
  final int amount;
  final bool highlight;
  final String Function(int amount) formatCurrency;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Icon(icon, color: cs.onSurfaceVariant, size: context.rs(16)),
            SizedBox(width: context.rsi(8)),
            Text(
              label,
              style: tt.bodySmall?.copyWith(
                color: cs.onSurfaceVariant,
                fontWeight: highlight ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
        Text(
          '${formatCurrency(amount)}원',
          style: tt.bodyMedium?.copyWith(
            fontWeight: FontWeight.w800,
            color: highlight ? cs.onSurface : cs.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
