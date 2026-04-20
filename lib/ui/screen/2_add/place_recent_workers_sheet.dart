import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:w0001/data/model/human_model.dart';
import 'package:w0001/presentation/viewmodel/add_cost_view_model.dart';
import 'package:w0001/util/funtions.dart';
import 'package:w0001/util/text_style.dart';

const List<String> kKoreanInitialIndex = <String>[
  'ㄱ',
  'ㄴ',
  'ㄷ',
  'ㄹ',
  'ㅁ',
  'ㅂ',
  'ㅅ',
  'ㅇ',
  'ㅈ',
  'ㅊ',
  'ㅋ',
  'ㅌ',
  'ㅍ',
  'ㅎ',
];

String initialIndexKeyForName(String name) {
  final trimmed = name.trim();
  if (trimmed.isEmpty) return '#';
  final code = trimmed.runes.first;
  // Hangul syllables: AC00..D7A3
  if (code >= 0xAC00 && code <= 0xD7A3) {
    final sIndex = code - 0xAC00;
    final lIndex = sIndex ~/ 588; // 21*28
    // 19 leading consonants
    const leads = <String>[
      'ㄱ',
      'ㄲ',
      'ㄴ',
      'ㄷ',
      'ㄸ',
      'ㄹ',
      'ㅁ',
      'ㅂ',
      'ㅃ',
      'ㅅ',
      'ㅆ',
      'ㅇ',
      'ㅈ',
      'ㅉ',
      'ㅊ',
      'ㅋ',
      'ㅌ',
      'ㅍ',
      'ㅎ',
    ];
    return leads[lIndex];
  }
  final ch = String.fromCharCode(code).toUpperCase();
  final isAZ = ch.codeUnitAt(0) >= 65 && ch.codeUnitAt(0) <= 90;
  return isAZ ? ch : '#';
}

Future<void> showPlaceRecentWorkersSheet({
  required BuildContext context,
  required WidgetRef ref,
}) async {
  final vm = ref.read(addCostProvider.notifier);
  var all = ref.read(addCostProvider).placeRecentWorkers;

  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (ctx) {
      var groupMode = 0; // 0: 초성, 1: 역할

      return DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.78,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (ctx, scrollController) {
          return StatefulBuilder(
            builder: (ctx, setModalState) {
              void syncAllFromState() {
                all = ref.read(addCostProvider).placeRecentWorkers;
              }

              Map<String, List<HumanModel>> buildSections() {
                final sections = <String, List<HumanModel>>{};
                if (groupMode == 1) {
                  for (final h in all) {
                    final role = h.hdefaultRole.trim();
                    final k = role.isEmpty ? '역할 미지정' : role;
                    (sections[k] ??= <HumanModel>[]).add(h);
                  }
                } else {
                  for (final h in all) {
                    final k = initialIndexKeyForName(h.hname);
                    (sections[k] ??= <HumanModel>[]).add(h);
                  }
                }
                return sections;
              }

              List<String> buildOrderedKeys(
                Map<String, List<HumanModel>> sections,
              ) {
                if (groupMode == 1) {
                  final keys = sections.keys.toList()..sort();
                  if (keys.remove('역할 미지정')) keys.add('역할 미지정');
                  return keys;
                }
                return <String>[
                  ...kKoreanInitialIndex.where(sections.containsKey),
                  ...sections.keys
                      .where((k) => !kKoreanInitialIndex.contains(k) && k != '#')
                      .toList()
                    ..sort(),
                  if (sections.containsKey('#')) '#',
                ];
              }

              final sections = buildSections();
              final orderedKeys = buildOrderedKeys(sections);
              final headerKeys = {for (final k in orderedKeys) k: GlobalKey()};

              Future<void> jumpTo(String key) async {
                final k = headerKeys[key];
                final c = k?.currentContext;
                if (c == null) return;
                await Scrollable.ensureVisible(
                  c,
                  alignment: 0,
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                );
              }

              Widget personTile(HumanModel h) {
                final cs = Theme.of(ctx).colorScheme;
                final role = h.hdefaultRole.trim();
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: cs.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: cs.outlineVariant.withValues(alpha: 0.65),
                    ),
                  ),
                  child: ListTile(
                    dense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 2,
                    ),
                    title: Text(h.hname, style: bold14Style),
                    subtitle: Text(
                      [
                        '일당 ${getPrice(price: h.hdailyWage)}',
                        if (role.isNotEmpty) role,
                      ].join(' · '),
                      style: smallStyle,
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.add_circle_outline),
                        const SizedBox(width: 6),
                        PopupMenuButton<String>(
                          tooltip: '더보기',
                          itemBuilder: (_) => const [
                            PopupMenuItem(
                              value: 'remove',
                              child: Text('이 목록에서 제거'),
                            ),
                          ],
                          onSelected: (v) async {
                            if (v != 'remove') return;
                            final ok = await showDialog<bool>(
                              context: ctx,
                              builder: (dctx) => AlertDialog(
                                title: const Text('목록에서 제거'),
                                content: Text('${h.hname} 님을 이 현장 목록에서 제거할까요?'),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.of(dctx).pop(false),
                                    child: const Text('취소'),
                                  ),
                                  TextButton(
                                    onPressed: () => Navigator.of(dctx).pop(true),
                                    child: const Text(
                                      '제거',
                                      style: TextStyle(color: Colors.red),
                                    ),
                                  ),
                                ],
                              ),
                            );
                            if (ok != true) return;
                            final hid = h.hid;
                            if (hid == null) return;
                            await vm.deletePlaceRecentWorker(hid);
                            if (!ctx.mounted) return;
                            setModalState(() {
                              syncAllFromState();
                            });
                          },
                        ),
                      ],
                    ),
                    onTap: () async {
                      await vm.tapPlaceRecentWorker(context, h);
                      if (!ctx.mounted) return;
                      Navigator.of(ctx).pop();
                    },
                  ),
                );
              }

              return SafeArea(
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              '이 현장에서 일했던 인원 (${all.length})',
                              style: Theme.of(ctx).textTheme.titleMedium,
                            ),
                          ),
                          SegmentedButton<int>(
                            segments: const [
                              ButtonSegment(value: 0, label: Text('초성')),
                              ButtonSegment(value: 1, label: Text('역할')),
                            ],
                            selected: {groupMode},
                            onSelectionChanged: (s) => setModalState(() {
                              groupMode = s.first;
                            }),
                            showSelectedIcon: false,
                          ),
                        ],
                      ),
                    ),
                    SizedBox(
                      height: 42,
                      child: ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        scrollDirection: Axis.horizontal,
                        itemCount: orderedKeys.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (_, i) {
                          final k = orderedKeys[i];
                          return ActionChip(
                            label: Text(k),
                            onPressed: () => jumpTo(k),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: ListView.builder(
                        controller: scrollController,
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        itemCount: orderedKeys.length,
                        itemBuilder: (_, i) {
                          final key = orderedKeys[i];
                          final list = sections[key] ?? const <HumanModel>[];
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Padding(
                                key: headerKeys[key],
                                padding: const EdgeInsets.only(top: 14, bottom: 6),
                                child: Text(
                                  key,
                                  style: Theme.of(ctx).textTheme.labelLarge,
                                ),
                              ),
                              for (final h in list) personTile(h),
                            ],
                          );
                        },
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      );
    },
  );
}

