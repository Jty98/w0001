import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:w0001/presentation/viewmodel/worker_personal_dashboard_notifier.dart';
import 'package:w0001/ui/screen/1_dashboard/widgets/worker_earnings_summary_section.dart';
import 'package:w0001/ui/widget/app_refresh_indicator.dart';
import 'package:w0001/util/responsive_layout.dart';

/// 작업자 설정 — 근로·정산 상세 (기간별 합계·현장별 투입·차트).
class WorkerEarningsScreen extends ConsumerWidget {
  const WorkerEarningsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('근로·정산'),
      ),
      body: AppRefreshIndicator(
        onRefresh: () async {
          await ref.read(workerPersonalDashboardProvider.notifier).reload(
                silent: true,
              );
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(
            context.rsi(16),
            context.rsi(12),
            context.rsi(16),
            MediaQuery.viewPaddingOf(context).bottom + context.rsi(32),
          ),
          child: const WorkerEarningsSummarySection(),
        ),
      ),
    );
  }
}
