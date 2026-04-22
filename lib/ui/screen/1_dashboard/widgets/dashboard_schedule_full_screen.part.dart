part of 'dashboard_schedule_section.dart';

/// 전체 일정: 1주·2주는 화살표로 주 이동, 1달은 월 스와이프. 아래는 선택 범위의 일정만 표시.
class DashboardScheduleFullScreen extends ConsumerStatefulWidget {
  const DashboardScheduleFullScreen({super.key});

  @override
  ConsumerState<DashboardScheduleFullScreen> createState() =>
      _DashboardScheduleFullScreenState();
}

class _DashboardScheduleFullScreenState
    extends ConsumerState<DashboardScheduleFullScreen> {
  /// 0 = 1주, 1 = 2주, 2 = 1달
  int _spanIndex = 0;
  int _weekNavDirection = 1;
  late DateTime _monthViewMonth;
  var _fullScreenMemosRequested = false;

  PageController? _monthPageCtrl;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_fullScreenMemosRequested) {
      _fullScreenMemosRequested = true;
      final st = ref.read(dashboardScheduleProvider);
      _monthViewMonth = DateTime(st.weekStart.year, st.weekStart.month, 1);
      Future.microtask(() {
        ref.read(dashboardScheduleProvider.notifier).loadFullMemosIfNeeded();
      });
    }
  }

  String _selectedDayHeading(DateTime d) {
    final wd = _weekdayKo[d.weekday - 1];
    return '${d.year}년 ${d.month}월 ${d.day}일 ($wd)';
  }

  void _goAdjacentMonth(int delta) {
    final c = _monthPageCtrl;
    if (c == null) return;
    final i = _monthPageIndexFromDate(_monthViewMonth);
    final t = i + delta;
    if (t < 0 || t >= _scheduleMonthPageCount) return;
    void animate() {
      if (!mounted) return;
      _monthPageCtrl?.animateToPage(
        t,
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
      );
    }

    if (c.hasClients) {
      animate();
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) => animate());
    }
  }

  void _onHorizontalSwipe(
    DragEndDetails details,
    DashboardScheduleViewModel vm,
  ) {
    final vx = details.primaryVelocity ?? 0;
    if (vx.abs() < 420) return;
    if (_spanIndex == 2) {
      _goAdjacentMonth(vx < 0 ? 1 : -1);
      return;
    }
    _moveWeek(vm, vx < 0 ? 1 : -1);
  }

  Future<void> _sharePickedDay(BuildContext context) async {
    final state = ref.read(dashboardScheduleProvider);
    final weekStart = scheduleDateOnly(state.weekStart);
    final selected = scheduleDateOnly(state.selectedDay);
    final picked = await showModalBottomSheet<DateTime>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        return Padding(
          padding: const EdgeInsets.fromLTRB(14, 4, 14, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                '공유할 날짜 선택',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 10),
              ...List.generate(7, (i) {
                final day = weekStart.add(Duration(days: i));
                final key = scheduleDateKey(day);
                final count =
                    (state.fullMemos ?? const <ScheduleMemoModel>[])
                        .where((m) => m.taskDate == key)
                        .length;
                final isSelected = _scheduleIsSameDay(day, selected);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => Navigator.pop(ctx, day),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: isSelected
                            ? cs.primaryContainer
                            : cs.surfaceContainerHighest.withValues(alpha: 0.4),
                        border: Border.all(
                          color: isSelected
                              ? cs.primary
                              : cs.outlineVariant.withValues(alpha: 0.55),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              _dayTitleLine(day),
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: isSelected
                                    ? cs.onPrimaryContainer
                                    : cs.onSurface,
                              ),
                            ),
                          ),
                          Text(
                            count == 0 ? '일정 없음' : '$count개',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: isSelected
                                  ? cs.onPrimaryContainer
                                  : cs.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ],
          ),
        );
      },
    );

    if (picked == null || !context.mounted) return;
    final day = scheduleDateOnly(picked);
    final key = scheduleDateKey(day);
    final memos = (state.fullMemos ?? const <ScheduleMemoModel>[])
        .where((m) => m.taskDate == key)
        .toList()
      ..sort((a, b) {
        final aTime = a.taskTime.trim();
        final bTime = b.taskTime.trim();
        final aHasTime = aTime.isNotEmpty;
        final bHasTime = bTime.isNotEmpty;
        if (aHasTime != bHasTime) return aHasTime ? -1 : 1;
        if (aTime != bTime) return aTime.compareTo(bTime);
        return a.title.compareTo(b.title);
      });
    final header =
        '## 일정표\n### ${day.year}년 ${day.month}월 ${day.day}일 (${_weekdayKo[day.weekday - 1]})';
    final text = memos.isEmpty
        ? '$header\n---\n- 등록된 일정이 없습니다.'
        : '$header\n---\n${memos.asMap().entries.map((entry) {
            final i = entry.key + 1;
            final m = entry.value;
            final time =
                m.taskTime.trim().isEmpty ? '--:--' : m.taskTime.trim();
            final memo = m.memo.trim().isEmpty ? '-' : m.memo.trim();
            return '### $i\n$time [${m.title.trim()}]\n$memo';
          }).join('\n\n')}';

    final box = context.findRenderObject() as RenderBox?;
    await Share.share(
      text,
      sharePositionOrigin:
          box == null ? null : box.localToGlobal(Offset.zero) & box.size,
    );
  }

  void _moveWeek(DashboardScheduleViewModel vm, int delta) {
    _weekNavDirection = delta >= 0 ? 1 : -1;
    vm.goWeek(delta);
  }

  @override
  void dispose() {
    _monthPageCtrl?.dispose();
    super.dispose();
  }

  Widget _buildMonthSwiper(
    ColorScheme cs,
    DashboardScheduleViewModel vm,
  ) {
    final idx = _monthPageIndexFromDate(_monthViewMonth);
    _monthPageCtrl ??= PageController(initialPage: idx);
    final pageI = _monthPageIndexFromDate(_monthViewMonth);
    return SizedBox(
      height: 48,
      child: Row(
        children: [
          IconButton(
            tooltip: '이전 달',
            onPressed: pageI > 0 ? () => _goAdjacentMonth(-1) : null,
            icon: Icon(
              Icons.chevron_left_rounded,
              size: 28,
              color: cs.onSurface,
            ),
          ),
          Expanded(
            child: PageView.builder(
              controller: _monthPageCtrl,
              itemCount: _scheduleMonthPageCount,
              onPageChanged: (i) {
                final m = _monthDateFromPageIndex(i);
                setState(() => _monthViewMonth = m);
                final firstMon =
                    scheduleStartOfWeekMonday(DateTime(m.year, m.month, 1));
                vm.setWeekPageIndex(vm.weekPageIndexFor(firstMon));
              },
              itemBuilder: (context, i) {
                final d = _monthDateFromPageIndex(i);
                return Center(
                  child: Text(
                    '${d.year}년 ${d.month}월',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                      color: cs.onSurface,
                    ),
                  ),
                );
              },
            ),
          ),
          IconButton(
            tooltip: '다음 달',
            onPressed: pageI < _scheduleMonthPageCount - 1
                ? () => _goAdjacentMonth(1)
                : null,
            icon: Icon(
              Icons.chevron_right_rounded,
              size: 28,
              color: cs.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeekSpanNav(ColorScheme cs) {
    final state = ref.watch(dashboardScheduleProvider);
    final vm = ref.read(dashboardScheduleProvider.notifier);
    final pageIdx = vm.weekPageIndexFor(state.weekStart);
    final mon =
        scheduleDateOnly(scheduleStartOfWeekMonday(state.weekStart));
    final label = _spanIndex == 0
        ? _weekRangeLine(mon)
        : _twoWeekSingleRangeLine(mon);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragEnd: (d) => _onHorizontalSwipe(d, vm),
      child: SizedBox(
        height: 48,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            IconButton(
              tooltip: '이전 주',
              onPressed: pageIdx > 0 && !state.isWeekLoading
                  ? () => _moveWeek(vm, -1)
                  : null,
              icon: Icon(
                Icons.chevron_left_rounded,
                size: 28,
                color: cs.onSurface,
              ),
            ),
            Expanded(
              child: Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                  color: cs.onSurface,
                ),
              ),
            ),
            IconButton(
              tooltip: '다음 주',
              onPressed: pageIdx < DashboardScheduleViewModel.weekPageCount - 1 &&
                      !state.isWeekLoading
                  ? () => _moveWeek(vm, 1)
                  : null,
              icon: Icon(
                Icons.chevron_right_rounded,
                size: 28,
                color: cs.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final state = ref.watch(dashboardScheduleProvider);
    final vm = ref.read(dashboardScheduleProvider.notifier);
    final today = scheduleDateOnly(DateTime.now());

    return Scaffold(
      appBar: AppBar(
        title: const Text('전체 일정'),
        actions: [
          IconButton(
            tooltip: '일정 공유',
            onPressed: () => _sharePickedDay(context),
            icon: const Icon(Icons.share_outlined),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'dashboard_schedule_full_fab',
        tooltip: '일정 추가',
        onPressed: state.isWeekLoading
            ? null
            : () => openDashboardMemoEditor(
                  context,
                  ref,
                  existing: null,
                  initialDateOverride: state.selectedDay,
                ),
        child: const Icon(Icons.add),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Material(
            color: cs.surfaceContainerLow,
            elevation: 0,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SegmentedButton<int>(
                    segments: const [
                      ButtonSegment(
                        value: 0,
                        label: Text('1주'),
                        tooltip: '1주 보기',
                      ),
                      ButtonSegment(
                        value: 1,
                        label: Text('2주'),
                        tooltip: '2주 보기',
                      ),
                      ButtonSegment(
                        value: 2,
                        label: Text('1달'),
                        tooltip: '1달 보기',
                      ),
                    ],
                    selected: {_spanIndex},
                    onSelectionChanged: (next) {
                      if (next.isEmpty) return;
                      final v = next.first;
                      setState(() {
                        _spanIndex = v;
                        if (v == 2) {
                          final st = ref.read(dashboardScheduleProvider);
                          _monthViewMonth = DateTime(
                            st.weekStart.year,
                            st.weekStart.month,
                            1,
                          );
                        } else {
                          _monthPageCtrl?.dispose();
                          _monthPageCtrl = null;
                        }
                      });
                      if (v == 2) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (!mounted || _spanIndex != 2) return;
                          final t = _monthPageIndexFromDate(_monthViewMonth);
                          final c = _monthPageCtrl;
                          if (c != null && c.hasClients) {
                            c.jumpToPage(t);
                          }
                        });
                      }
                    },
                    showSelectedIcon: false,
                    style: const ButtonStyle(
                      visualDensity: VisualDensity.compact,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (_spanIndex == 2)
                    _buildMonthSwiper(cs, vm)
                  else
                    _buildWeekSpanNav(cs),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Icon(Icons.today_outlined, size: 18, color: cs.primary),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          '${_selectedDayHeading(state.selectedDay)} 기준',
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          vm.setWeekPageIndex(
                            vm.weekPageIndexFor(
                              scheduleStartOfWeekMonday(today),
                            ),
                          );
                          vm.selectDay(today);
                          setState(() {
                            _monthViewMonth =
                                DateTime(today.year, today.month, 1);
                          });
                          if (_spanIndex == 2) {
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              if (!mounted || _spanIndex != 2) return;
                              final t = _monthPageIndexFromDate(_monthViewMonth);
                              final c = _monthPageCtrl;
                              if (c != null && c.hasClients) {
                                c.jumpToPage(t);
                              }
                            });
                          }
                        },
                        child: const Text('이번주'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          Divider(
            height: 1,
            color: cs.outlineVariant.withValues(alpha: 0.45),
          ),
          Expanded(
            child: _spanIndex == 2
                ? _buildScrollBody(context, ref, state, cs)
                : AnimatedSwitcher(
                      duration: const Duration(milliseconds: 220),
                      switchInCurve: Curves.easeOutCubic,
                      switchOutCurve: Curves.easeInCubic,
                      layoutBuilder: (currentChild, previousChildren) {
                        return Stack(
                          fit: StackFit.expand,
                          children: [
                            ...previousChildren,
                            if (currentChild != null) currentChild,
                          ],
                        );
                      },
                      transitionBuilder: (child, animation) {
                        final enterFrom = Offset(
                          _weekNavDirection > 0 ? 0.10 : -0.10,
                          0,
                        );
                        return ClipRect(
                          child: SlideTransition(
                            position: Tween<Offset>(
                              begin: enterFrom,
                              end: Offset.zero,
                            ).animate(animation),
                            child: FadeTransition(
                              opacity: animation,
                              child: child,
                            ),
                          ),
                        );
                      },
                      child: KeyedSubtree(
                        key: ValueKey(
                          '${_spanIndex}_${scheduleDateKey(state.weekStart)}',
                        ),
                        child: _buildScrollBody(context, ref, state, cs),
                      ),
                    ),
          ),
        ],
      ),
    );
  }

  Widget _buildScrollBody(
    BuildContext context,
    WidgetRef ref,
    DashboardScheduleState state,
    ColorScheme cs,
  ) {
    if (state.isFullLoading || state.fullMemos == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final mon = scheduleDateOnly(scheduleStartOfWeekMonday(state.weekStart));

    late final Widget scrollContent;
    if (_spanIndex == 0) {
      final memos = state.memosOnFullListForWeekMonday(mon);
      scrollContent = SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),
        child: _FullWeekBlock(
          weekStart: mon,
          memos: memos,
          weekRangeLabel: _weekRangeLine(mon),
        ),
      );
    } else if (_spanIndex == 1) {
      final mon2 = mon.add(const Duration(days: 7));
      scrollContent = SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _FullWeekBlock(
              weekStart: mon,
              memos: state.memosOnFullListForWeekMonday(mon),
              weekRangeLabel: _weekRangeLine(mon),
            ),
            const SizedBox(height: 10),
            _FullWeekBlock(
              weekStart: mon2,
              memos: state.memosOnFullListForWeekMonday(mon2),
              weekRangeLabel: _weekRangeLine(mon2),
            ),
          ],
        ),
      );
    } else {
      final mondays = _mondaysOverlappingMonth(_monthViewMonth);
      final blocks = mondays
          .where((mo) => state.memosOnFullListForWeekMonday(mo).isNotEmpty)
          .toList();
      if (blocks.isEmpty) {
        scrollContent = Padding(
          padding: const EdgeInsets.only(bottom: 88),
          child: Center(
            child: Text(
              '이 달에는 등록된 일정이 없습니다.',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: cs.onSurfaceVariant,
              ),
            ),
          ),
        );
      } else {
        scrollContent = SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < blocks.length; i++) ...[
                _FullWeekBlock(
                  weekStart: blocks[i],
                  memos: state.memosOnFullListForWeekMonday(blocks[i]),
                  weekRangeLabel: _weekRangeLine(blocks[i]),
                ),
                if (i < blocks.length - 1) const SizedBox(height: 10),
              ],
            ],
          ),
        );
      }
    }

    return scrollContent;
  }
}
