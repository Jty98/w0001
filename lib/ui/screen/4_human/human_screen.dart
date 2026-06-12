import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:w0001/data/model/human_model.dart';
import 'package:w0001/presentation/viewmodel/worker_view_model.dart';
import 'package:w0001/ui/screen/0_auth/widgets/profile_section_chrome.dart';
import 'package:w0001/ui/screen/4_human/widgets/human_editor_dialog.dart';
import 'package:w0001/ui/screen/4_human/widgets/human_list_card.dart';
import 'package:w0001/ui/widget/human_worker_search_bar.dart';
import 'package:w0001/ui/widget/worker_grouped_list/worker_grouped_list_sheet.dart';
import 'package:w0001/util/responsive_layout.dart';

class HumanScreen extends ConsumerStatefulWidget {
  const HumanScreen({super.key});

  @override
  ConsumerState<HumanScreen> createState() => _HumanScreenState();
}

class _HumanScreenState extends ConsumerState<HumanScreen> {
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _prepareScreen();
  }

  Future<void> _prepareScreen() async {
    await ref.read(workerProvider.notifier).prepareHumanManagementScreen();
    if (mounted) setState(() => _loading = false);
  }

  void _openEditor(
    BuildContext context,
    WorkerViewModel vm, {
    required int? listIndex,
    HumanModel? human,
  }) {
    if (listIndex != null && human != null) {
      vm.showWorkerInfo(
        listIndex,
        human.hname,
        human.hnumber,
        human.hdailyWage,
        human.hmemo ?? '',
        human.hdefaultRole,
      );
    } else {
      vm.refreshAction();
    }
    showHumanEditorDialog(
      context: context,
      ref: ref,
      listIndex: listIndex,
    );
  }

  void _openBrowseSheet(BuildContext context, WorkerViewModel vm) {
    final workers = ref.read(workerProvider).filteredWorkerList;
    showWorkerGroupedListSheet(
      context: context,
      title: '인력 찾기 (${workers.length})',
      workers: workers,
      onWorkerTap: (h) {
        final list = ref.read(workerProvider).filteredWorkerList;
        final index = list.indexWhere((w) => w.hid != null && w.hid == h.hid);
        if (index < 0) return;
        _openEditor(context, vm, listIndex: index, human: h);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(workerProvider);
    final vm = ref.read(workerProvider.notifier);
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('인력 관리'),
          actions: [
            IconButton(
              tooltip: '인력 등록',
              onPressed: () => _openEditor(context, vm, listIndex: null),
              icon: const Icon(Icons.add_rounded),
            ),
          ],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  HumanWorkerSearchBar(
                    searchController: vm.searchWorkerDetailTextContoller,
                    onChanged: vm.searchWokerInfo,
                    workerCount: state.filteredWorkerList.length,
                    onBrowseTap: () => _openBrowseSheet(context, vm),
                  ),
                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: vm.fetchWorkerInfo,
                      child: state.filteredWorkerList.isEmpty
                          ? ListView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: EdgeInsets.symmetric(
                                horizontal: context.rsi(16),
                              ),
                              children: [
                                SizedBox(
                                  height:
                                      MediaQuery.sizeOf(context).height * 0.35,
                                  child: Center(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.group_outlined,
                                          size: context.rs(40),
                                          color: cs.onSurfaceVariant
                                              .withValues(alpha: 0.42),
                                        ),
                                        SizedBox(height: context.rsi(10)),
                                        Text(
                                          state.workerInfoList.isEmpty
                                              ? '등록된 사람이 없습니다'
                                              : '검색 결과가 없습니다',
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleSmall
                                              ?.copyWith(
                                            fontWeight: FontWeight.w700,
                                            color: cs.onSurface
                                                .withValues(alpha: 0.85),
                                          ),
                                        ),
                                        SizedBox(height: context.rsi(4)),
                                        Text(
                                          state.workerInfoList.isEmpty
                                              ? '우측 상단 + 로 등록해 주세요'
                                              : '다른 검색어를 입력해 보세요',
                                          style: Theme.of(context)
                                              .textTheme
                                              .labelSmall
                                              ?.copyWith(
                                            color: cs.onSurfaceVariant,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            )
                          : ListView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: EdgeInsets.fromLTRB(
                                context.rsi(16),
                                context.rsi(4),
                                context.rsi(16),
                                context.rsi(24),
                              ),
                              children: [
                                if (state.filteredWorkerList.isNotEmpty) ...[
                                  ProfileSectionTitle(
                                    '인력 ${state.filteredWorkerList.length}명',
                                  ),
                                  SizedBox(height: context.rsi(8)),
                                  ProfileInsetPanel(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: context.rsi(6),
                                      vertical: context.rsi(6),
                                    ),
                                    child: Column(
                                      children: [
                                        for (var index = 0;
                                            index <
                                                state
                                                    .filteredWorkerList.length;
                                            index++) ...[
                                          if (index > 0)
                                            SizedBox(height: context.rsi(4)),
                                          HumanListCard(
                                            index: index,
                                            human: state
                                                .filteredWorkerList[index],
                                            onTap: () => _openEditor(
                                              context,
                                              vm,
                                              listIndex: index,
                                              human: state
                                                  .filteredWorkerList[index],
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
