import 'package:flutter/material.dart';
import 'package:w0001/ui/widget/hammer_loading_indicator.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:w0001/data/model/place_info_model.dart';
import 'package:w0001/data/model/place_site_guide_model.dart';
import 'package:w0001/presentation/viewmodel/place_site_guide_providers.dart';
import 'package:w0001/util/funtions.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:w0001/util/responsive_layout.dart';
import 'package:w0001/ui/widget/app_text_field.dart';

/// 현장 기본 정보(주소·기간) + 인수인계(출입·열쇠·주차) — 앱바에서 연다.
Future<void> showPlaceSiteInfoDialog(
  BuildContext context, {
  required WidgetRef ref,
  required PlaceInfoModel place,
  required bool showManagementMoney,
}) {
  return showDialog<void>(
    context: context,
    builder: (dCtx) => _PlaceSiteInfoDialogBody(
      ref: ref,
      place: place,
      showManagementMoney: showManagementMoney,
    ),
  );
}

class _PlaceSiteInfoDialogBody extends ConsumerStatefulWidget {
  const _PlaceSiteInfoDialogBody({
    required this.ref,
    required this.place,
    required this.showManagementMoney,
  });

  final WidgetRef ref;
  final PlaceInfoModel place;
  final bool showManagementMoney;

  @override
  ConsumerState<_PlaceSiteInfoDialogBody> createState() =>
      _PlaceSiteInfoDialogBodyState();
}

class _PlaceSiteInfoDialogBodyState
    extends ConsumerState<_PlaceSiteInfoDialogBody> {
  final _doorCtrl = TextEditingController();
  final _keyCtrl = TextEditingController();
  final _restroomCtrl = TextEditingController();
  final _parkingCtrl = TextEditingController();
  var _dirty = false;
  var _hydratedGeneration = 0;
  var _handledAccessDenied = false;

  int? get _pid => widget.place.pid;

  @override
  void initState() {
    super.initState();
    final pid = _pid;
    if (pid == null) return;

    // ✅ 즉시 로드 시작 (캐시가 있으면 스킵, 없으면 로딩)
    // microtask로 실행해서 build 중 state 변경 방지
    Future.microtask(() {
      if (!mounted) return;
      ref.read(placeSiteGuideByPidProvider(pid).notifier).load();
    });
  }

  void _applyModel(PlaceSiteGuideModel? model) {
    final m = model ?? PlaceSiteGuideModel.empty(_pid ?? 0);
    _doorCtrl.text = m.doorAccess;
    _keyCtrl.text = m.keyLocation;
    _restroomCtrl.text = m.restroomAccess;
    _parkingCtrl.text = m.parkingInfo;
    _dirty = false;
  }

  @override
  void dispose() {
    _doorCtrl.dispose();
    _keyCtrl.dispose();
    _restroomCtrl.dispose();
    _parkingCtrl.dispose();
    super.dispose();
  }

  void _markDirty() {
    if (!_dirty) setState(() => _dirty = true);
  }

  PlaceSiteGuideModel _draftFromFields() {
    final pid = _pid ?? 0;
    final door = _doorCtrl.text;
    final key = _keyCtrl.text;
    return PlaceSiteGuideModel(
      pid: pid,
      accessMode: PlaceSiteAccessMode.infer(
        doorAccess: door,
        keyLocation: key,
      ),
      doorAccess: door,
      keyLocation: key,
      restroomAccess: _restroomCtrl.text,
      parkingInfo: _parkingCtrl.text,
      updatedAt: ref.read(placeSiteGuideByPidProvider(pid)).guide?.updatedAt,
      updatedByUid:
          ref.read(placeSiteGuideByPidProvider(pid)).guide?.updatedByUid,
    );
  }

  Future<void> _save() async {
    final pid = _pid;
    if (pid == null) return;
    final ok = await ref
        .read(placeSiteGuideByPidProvider(pid).notifier)
        .save(_draftFromFields());
    if (!mounted) return;
    if (ok) {
      final updated = ref.read(placeSiteGuideByPidProvider(pid));
      _hydratedGeneration = updated.loadGeneration;
      _applyModel(updated.guide);
      setState(() => _dirty = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('인수인계를 저장했습니다.')),
      );
      return;
    }
    final msg = ref.read(placeSiteGuideByPidProvider(pid)).errorMessage;
    if (msg != null && msg.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  void _copyAddress(String value) {
    final t = value.trim();
    if (t.isEmpty) return;
    Clipboard.setData(ClipboardData(text: t));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('주소를 복사했습니다.')),
    );
  }

  String _formatSavedAt(DateTime dt) {
    final local = dt.toLocal();
    return '${local.year}년 ${local.month}월 ${local.day}일 '
        '${local.hour.toString().padLeft(2, '0')}시 '
        '${local.minute.toString().padLeft(2, '0')}분';
  }

  String _savedAtLine(PlaceSiteGuideModel stored) {
    final at = stored.updatedAt;
    if (at == null) return '';
    return '마지막 저장: ${_formatSavedAt(at)}';
  }

  void _syncFormFromGuideState(PlaceSiteGuideByPidState guideState) {
    if (guideState.isLoading ||
        guideState.accessDenied ||
        !guideState.hasLoadedOnce) {
      return;
    }
    if (guideState.loadGeneration == _hydratedGeneration) return;
    _hydratedGeneration = guideState.loadGeneration;
    if (!_dirty) {
      _applyModel(guideState.guide);
    }
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {});
    });
  }

  void _maybeHandleAccessDenied(PlaceSiteGuideByPidState guideState) {
    if (!guideState.accessDenied || _handledAccessDenied) return;
    _handledAccessDenied = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final msg = guideState.errorMessage ?? '이 현장에 접근할 수 없습니다.';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      Navigator.of(context).pop();
    });
  }

  @override
  Widget build(BuildContext context) {
    final pid = _pid;
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    final guideState = pid != null
        ? ref.watch(placeSiteGuideByPidProvider(pid))
        : const PlaceSiteGuideByPidState();
    final stored = guideState.guide;

    _maybeHandleAccessDenied(guideState);

    if (pid != null) {
      ref.listen<PlaceSiteGuideByPidState>(
        placeSiteGuideByPidProvider(pid),
        (_, next) => _syncFormFromGuideState(next),
      );
    }

    final addr = widget.place.paddress.trim();
    final pendSafe =
        widget.place.pend.trim().isEmpty ? '0' : widget.place.pend.trim();
    final periodLine = formatDuration(widget.place.pstart, pendSafe);

    return Dialog(
      insetPadding:
          ResponsiveLayout.symmetric(context, horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.88,
          maxWidth: context.rs(520),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding:
                  ResponsiveLayout.only(context, left: 20, top: 18, right: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '현장 정보 · 인수인계',
                          style: tt.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.4,
                          ),
                        ),
                        rsV(context, 4),
                        Text(
                          widget.place.pname,
                          style: tt.bodyMedium?.copyWith(
                            color: cs.onSurfaceVariant,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: '닫기',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: ResponsiveLayout.only(context,
                    left: 20, top: 14, right: 20, bottom: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (guideState.errorMessage != null &&
                        !guideState.accessDenied) ...[
                      Material(
                        color: cs.errorContainer.withValues(alpha: 0.65),
                        borderRadius: BorderRadius.circular(context.rs(12)),
                        child: Padding(
                          padding: ResponsiveLayout.all(context, 12),
                          child: Text(
                            guideState.errorMessage!,
                            style: tt.bodySmall?.copyWith(
                              color: cs.onErrorContainer,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      rsV(context, 12),
                    ],
                    _UnifiedInfoSection(
                      address: addr,
                      periodLine: periodLine,
                      showMoney: widget.showManagementMoney,
                      place: widget.place,
                      onCopyAddress:
                          addr.isEmpty ? null : () => _copyAddress(addr),
                    ),
                    rsV(context, 18),
                    Text(
                      '인수인계',
                      style: tt.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: cs.primary,
                      ),
                    ),
                    if (stored?.updatedAt != null) ...[
                      rsV(context, 8),
                      Text(
                        _savedAtLine(stored!),
                        style: tt.labelSmall?.copyWith(
                          color: cs.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    rsV(context, 12),
                    Skeletonizer(
                      enabled: guideState.isLoading,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _GuideFieldCard(
                            icon: Icons.door_front_door_outlined,
                            title: '출입 비밀번호',
                            hint: '공동현관·현장 출입 번호 등',
                            controller: _doorCtrl,
                            onChanged: guideState.isLoading
                                ? null
                                : (_) => _markDirty(),
                          ),
                          rsV(context, 10),
                          _GuideFieldCard(
                            icon: Icons.vpn_key_outlined,
                            title: '열쇠·키 위치',
                            hint: '보관 장소, 담당자, 반납 방법 등',
                            controller: _keyCtrl,
                            maxLines: 3,
                            onChanged: guideState.isLoading
                                ? null
                                : (_) => _markDirty(),
                          ),
                          rsV(context, 10),
                          _GuideFieldCard(
                            icon: Icons.wc_outlined,
                            title: '화장실 비밀번호',
                            hint: '화장실 출입 번호',
                            controller: _restroomCtrl,
                            onChanged: guideState.isLoading
                                ? null
                                : (_) => _markDirty(),
                          ),
                          rsV(context, 10),
                          _GuideFieldCard(
                            icon: Icons.local_parking_outlined,
                            title: '주차 안내',
                            hint: '주차 위치, 요금, 차량 등록 방법 등',
                            controller: _parkingCtrl,
                            maxLines: 4,
                            onChanged: guideState.isLoading
                                ? null
                                : (_) => _markDirty(),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: ResponsiveLayout.only(context,
                  left: 16, top: 8, right: 16, bottom: 16),
              child: Row(
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('닫기'),
                  ),
                  const Spacer(),
                  FilledButton.icon(
                    onPressed: pid == null ||
                            !_dirty ||
                            guideState.isLoading ||
                            guideState.isSaving ||
                            guideState.accessDenied
                        ? null
                        : _save,
                    icon: guideState.isSaving
                        ? SizedBox(
                            width: context.rs(20),
                            height: context.rs(20),
                            child: const HammerLoadingIndicator(size: 20),
                          )
                        : Icon(Icons.save_outlined, size: context.rsi(20)),
                    label: Text(guideState.isSaving ? '저장 중…' : '저장'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 주소·기간·(관리자) 금액을 한 카드에 표시. 복사는 주소만.
class _UnifiedInfoSection extends StatelessWidget {
  const _UnifiedInfoSection({
    required this.address,
    required this.periodLine,
    required this.showMoney,
    required this.place,
    required this.onCopyAddress,
  });

  final String address;
  final String periodLine;
  final bool showMoney;
  final PlaceInfoModel place;
  final VoidCallback? onCopyAddress;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final addrEmpty = address.isEmpty;

    return Material(
      color: cs.surfaceContainerLow.withValues(alpha: 0.5),
      borderRadius: BorderRadius.circular(context.rs(14)),
      child: Padding(
        padding: ResponsiveLayout.only(context,
            left: 14, top: 12, right: 10, bottom: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '현장 정보',
              style: tt.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: cs.primary,
              ),
            ),
            rsV(context, 10),
            _InfoLine(
              icon: Icons.place_outlined,
              label: '주소',
              value: addrEmpty ? '주소 미등록' : address,
              muted: addrEmpty,
              trailing: onCopyAddress == null
                  ? null
                  : IconButton(
                      tooltip: '주소 복사',
                      onPressed: onCopyAddress,
                      icon: Icon(Icons.copy_outlined, size: context.rsi(20)),
                      visualDensity: VisualDensity.compact,
                    ),
            ),
            rsV(context, 8),
            _InfoLine(
              icon: Icons.date_range_outlined,
              label: '공사 기간',
              value: periodLine,
            ),
            if (showMoney) ...[
              rsV(context, 12),
              const Divider(height: 1),
              rsV(context, 10),
              _PlaceMoneySummaryBlock(place: place),
            ],
          ],
        ),
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({
    required this.icon,
    required this.label,
    required this.value,
    this.muted = false,
    this.trailing,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool muted;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: context.rsi(20), color: cs.primary),
        rsH(context, 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: tt.labelMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: cs.onSurfaceVariant,
                ),
              ),
              rsV(context, 4),
              Text(
                value,
                style: tt.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: muted ? cs.onSurfaceVariant : cs.onSurface,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

class _PlaceMoneySummaryBlock extends StatelessWidget {
  const _PlaceMoneySummaryBlock({required this.place});

  final PlaceInfoModel place;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final totalRevenue = place.pfirstrevenue + place.totalAdditionalRevenue;
    final balance = (place.pcontractTotal - totalRevenue) < 0
        ? 0
        : (place.pcontractTotal - totalRevenue);
    final totalCost = place.mTotal + place.wTotal;
    final profit = totalRevenue - totalCost;

    String money(int v) => getPrice(price: v);

    Widget row(String label, String val) {
      return Padding(
        padding: ResponsiveLayout.symmetric(context, vertical: 3),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: tt.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Text(
              val,
              style: tt.bodySmall?.copyWith(fontWeight: FontWeight.w800),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '금액 요약',
          style: tt.labelLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
        rsV(context, 6),
        row('공사 금액', money(place.pcontractTotal)),
        row('수금', money(totalRevenue)),
        row('미수', money(balance)),
        row('비용', money(totalCost)),
        row('영업이익', money(profit)),
      ],
    );
  }
}

class _GuideFieldCard extends StatelessWidget {
  const _GuideFieldCard({
    required this.icon,
    required this.title,
    required this.hint,
    required this.controller,
    this.onChanged,
    this.maxLines = 2,
  });

  final IconData icon;
  final String title;
  final String hint;
  final TextEditingController controller;
  final ValueChanged<String>? onChanged;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Material(
      color: cs.surfaceContainerLow.withValues(alpha: 0.65),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(context.rs(14)),
        side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.45)),
      ),
      child: Padding(
        padding: ResponsiveLayout.only(context,
            left: 14, top: 12, right: 14, bottom: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(icon, size: context.rsi(22), color: cs.primary),
                rsH(context, 10),
                Expanded(
                  child: Text(
                    title,
                    style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
            rsV(context, 6),
            AppTextField(
              controller: controller,
              onChanged: onChanged,
              readOnly: onChanged == null,
              maxLines: maxLines,
              minLines: 1,
              decoration: InputDecoration(
                hintText: hint,
                filled: true,
                fillColor: cs.surface,
                border: const OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
