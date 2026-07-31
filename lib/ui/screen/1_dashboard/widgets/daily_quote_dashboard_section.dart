import 'package:flutter/material.dart';
import 'package:w0001/ui/widget/app_loading_indicator.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:w0001/data/model/daily_quote_models.dart';
import 'package:w0001/presentation/viewmodel/daily_quote_providers.dart';
import 'package:w0001/theme/app_section_card.dart';
import 'package:w0001/theme/app_theme_colors.dart';
import 'package:w0001/util/responsive_layout.dart';

/// 관리자 상황판 최상단 — 접었다 펼 수 있는 오늘의 한마디 카드.
///
/// 접힘 상태는 [dailyQuoteCardExpandedProvider]('admin')로 로컬 저장된다.
class CollapsibleDailyQuoteCard extends ConsumerWidget {
  const CollapsibleDailyQuoteCard({super.key, this.onOpenSettings});

  final VoidCallback? onOpenSettings;

  static const _screenKey = 'admin';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final expanded = ref.watch(dailyQuoteCardExpandedProvider(_screenKey));
    final radius = AppSectionCardStyles.borderRadius(context);

    return DecoratedBox(
      decoration: AppSectionCardStyles.cardDecoration(context),
      child: ClipRRect(
        borderRadius: radius,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            InkWell(
              onTap: () => ref
                  .read(dailyQuoteCardExpandedProvider(_screenKey).notifier)
                  .toggle(),
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  context.rsi(16),
                  context.rsi(10),
                  context.rsi(8),
                  context.rsi(10),
                ),
                child: Row(
                  children: [
                    Container(
                      width: context.rs(36),
                      height: context.rs(36),
                      alignment: Alignment.center,
                      decoration: AppSectionCardStyles.iconBadgeDecoration(
                        context,
                        cs,
                      ),
                      child: Icon(
                        Icons.format_quote_rounded,
                        color: cs.primary,
                        size: context.rs(19),
                      ),
                    ),
                    SizedBox(width: context.rsi(12)),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '오늘의 한마디',
                            style: tt.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.2,
                              height: 1.25,
                            ),
                          ),
                          if (!expanded) ...[
                            SizedBox(height: context.rsi(2)),
                            Text(
                              '오늘의 한마디 보기',
                              style: tt.bodySmall?.copyWith(
                                color: cs.onSurfaceVariant,
                                fontWeight: FontWeight.w500,
                                height: 1.3,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (onOpenSettings != null)
                      IconButton(
                        tooltip: '명언 관리',
                        visualDensity: VisualDensity.compact,
                        onPressed: onOpenSettings,
                        icon: Icon(
                          Icons.settings_outlined,
                          size: context.rsi(20),
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    IconButton(
                      tooltip: expanded ? '접기' : '펼치기',
                      visualDensity: VisualDensity.compact,
                      onPressed: () => ref
                          .read(
                            dailyQuoteCardExpandedProvider(_screenKey).notifier,
                          )
                          .toggle(),
                      icon: AnimatedRotation(
                        turns: expanded ? 0.5 : 0,
                        duration: const Duration(milliseconds: 200),
                        child: Icon(
                          Icons.keyboard_arrow_down_rounded,
                          size: context.rsi(24),
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeInOut,
              alignment: Alignment.topCenter,
              child: expanded
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Divider(height: 1, thickness: 1, color: cs.appDivider),
                        Padding(
                          padding: EdgeInsets.fromLTRB(
                            context.rsi(16),
                            context.rsi(12),
                            context.rsi(16),
                            context.rsi(14),
                          ),
                          child: const DailyQuoteCardBody(),
                        ),
                      ],
                    )
                  : const SizedBox(width: double.infinity),
            ),
          ],
        ),
      ),
    );
  }
}

/// 작업자 대시보드 최상단 — 인사말과 오늘의 한마디를 한 카드로 묶은 배너.
///
/// 접힘 상태는 [dailyQuoteCardExpandedProvider]('worker')로 로컬 저장된다.
class WorkerWelcomeQuoteBanner extends ConsumerWidget {
  const WorkerWelcomeQuoteBanner({super.key, required this.name});

  final String name;

  static const _screenKey = 'worker';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final expanded = ref.watch(dailyQuoteCardExpandedProvider(_screenKey));
    final radius = AppSectionCardStyles.borderRadius(context);

    return DecoratedBox(
      decoration: AppSectionCardStyles.cardDecoration(context),
      child: ClipRRect(
        borderRadius: radius,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            InkWell(
              onTap: () => ref
                  .read(dailyQuoteCardExpandedProvider(_screenKey).notifier)
                  .toggle(),
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  context.rsi(16),
                  context.rsi(12),
                  context.rsi(8),
                  context.rsi(12),
                ),
                child: Row(
                  children: [
                    Container(
                      width: context.rs(44),
                      height: context.rs(44),
                      alignment: Alignment.center,
                      decoration: AppSectionCardStyles.iconBadgeDecoration(
                        context,
                        cs,
                      ),
                      child: Icon(
                        Icons.waving_hand_rounded,
                        color: cs.primary,
                        size: context.rs(22),
                      ),
                    ),
                    SizedBox(width: context.rsi(12)),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$name님, 안녕하세요',
                            style: tt.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: cs.onSurface,
                              height: 1.25,
                            ),
                          ),
                          SizedBox(height: context.rsi(2)),
                          Text(
                            '오늘도 안전한 하루 되세요!',
                            style: tt.bodySmall?.copyWith(
                              color: cs.onSurfaceVariant,
                              fontWeight: FontWeight.w500,
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: expanded ? '오늘의 한마디 접기' : '오늘의 한마디 펼치기',
                      visualDensity: VisualDensity.compact,
                      onPressed: () => ref
                          .read(
                            dailyQuoteCardExpandedProvider(_screenKey).notifier,
                          )
                          .toggle(),
                      icon: AnimatedRotation(
                        turns: expanded ? 0.5 : 0,
                        duration: const Duration(milliseconds: 200),
                        child: Icon(
                          Icons.keyboard_arrow_down_rounded,
                          size: context.rsi(24),
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeInOut,
              alignment: Alignment.topCenter,
              child: expanded
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Divider(height: 1, thickness: 1, color: cs.appDivider),
                        Padding(
                          padding: EdgeInsets.fromLTRB(
                            context.rsi(16),
                            context.rsi(12),
                            context.rsi(16),
                            context.rsi(14),
                          ),
                          child: const DailyQuoteCardBody(
                            showOverrideBadge: false,
                          ),
                        ),
                      ],
                    )
                  : const SizedBox(width: double.infinity),
            ),
          ],
        ),
      ),
    );
  }
}

class DailyQuoteCardBody extends ConsumerWidget {
  const DailyQuoteCardBody({super.key, this.showOverrideBadge = true});

  /// 관리자만 "오늘 직접 지정" 뱃지를 표시한다.
  final bool showOverrideBadge;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncQuote = ref.watch(todayDailyQuoteProvider);
    return asyncQuote.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 18),
        child: AppLoadingIndicator(size: 52),
      ),
      error: (_, __) => _QuoteStatus(
        message: '오늘의 명언을 불러오지 못했습니다.',
        onRetry: () => ref.read(todayDailyQuoteProvider.notifier).refresh(),
      ),
      data: (today) => today == null
          ? const _QuoteStatus(message: '등록된 명언이 없습니다.')
          : _QuoteContent(
              today: today,
              showOverrideBadge: showOverrideBadge,
            ),
    );
  }
}

class _QuoteContent extends StatelessWidget {
  const _QuoteContent({
    required this.today,
    this.showOverrideBadge = true,
  });

  final TodayDailyQuote today;
  final bool showOverrideBadge;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final quote = today.quote;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Icon(
          Icons.format_quote_rounded,
          color: cs.tertiary.withValues(alpha: 0.55),
          size: context.rsi(28),
        ),
        SizedBox(height: context.rsi(4)),
        Text(
          quote.message,
          textAlign: TextAlign.center,
          style: tt.bodyLarge?.copyWith(
            fontWeight: FontWeight.w700,
            height: 1.55,
            letterSpacing: -0.2,
          ),
        ),
        SizedBox(height: context.rsi(14)),
        Center(
          child: Container(
            width: context.rs(28),
            height: context.rs(2),
            decoration: BoxDecoration(
              color: cs.tertiary.withValues(alpha: 0.45),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        ),
        SizedBox(height: context.rsi(10)),
        Text(
          quote.author,
          textAlign: TextAlign.center,
          style: tt.bodyMedium?.copyWith(
            color: cs.onSurface,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.1,
          ),
        ),
        if (quote.authorProfile.trim().isNotEmpty) ...[
          SizedBox(height: context.rsi(2)),
          Text(
            quote.authorProfile,
            textAlign: TextAlign.center,
            style: tt.labelSmall?.copyWith(
              color: cs.onSurfaceVariant.withValues(alpha: 0.85),
              fontWeight: FontWeight.w500,
              letterSpacing: 0.1,
            ),
          ),
        ],
        if (showOverrideBadge && today.isOverride) ...[
          SizedBox(height: context.rsi(10)),
          Center(
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: context.rsi(7),
                vertical: context.rsi(3),
              ),
              decoration: BoxDecoration(
                color: cs.secondaryContainer,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '오늘 직접 지정',
                style: tt.labelSmall?.copyWith(
                  color: cs.onSecondaryContainer,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _QuoteStatus extends StatelessWidget {
  const _QuoteStatus({required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Expanded(
          child: Text(
            message,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: cs.onSurfaceVariant),
          ),
        ),
        if (onRetry != null)
          TextButton(
            onPressed: onRetry,
            child: const Text('다시 시도'),
          ),
      ],
    );
  }
}
