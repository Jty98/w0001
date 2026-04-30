import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:w0001/data/model/place_info_model.dart';

class PlaceDetailScreen extends StatelessWidget {
  final PlaceInfoModel placeInfo;

  const PlaceDetailScreen({super.key, required this.placeInfo});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(placeInfo.pname)),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _BranchCardButton(
              title: '현장 금액관리',
              subtitle: '인건비, 자재비, 추가수익 등 금액 데이터 관리',
              icon: Icons.request_quote_outlined,
              startColor: cs.primaryContainer,
              endColor: cs.primary.withValues(alpha: 0.22),
              onTap: () => context.push('/place/detail/cost', extra: placeInfo),
            ),
            const SizedBox(height: 14),
            _BranchCardButton(
              title: '현장 사진관리',
              subtitle: '일자별 사진 묶음 등록 및 확인',
              icon: Icons.photo_library_outlined,
              startColor: cs.secondaryContainer,
              endColor: cs.secondary.withValues(alpha: 0.22),
              onTap: () =>
                  context.push('/place/detail/images', extra: placeInfo),
            ),
            const SizedBox(height: 14),
            _BranchCardButton(
              title: '인테리어 공정표',
              subtitle: '날짜·공정 매트릭스로 일정 조회',
              icon: Icons.view_timeline_outlined,
              startColor: cs.tertiaryContainer,
              endColor: cs.tertiary.withValues(alpha: 0.22),
              onTap: () => context.push('/place/detail/process-schedule',
                  extra: placeInfo),
            ),
          ],
        ),
      ),
    );
  }
}

class _BranchCardButton extends StatelessWidget {
  const _BranchCardButton({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.startColor,
    required this.endColor,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color startColor;
  final Color endColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Ink(
          height: 128,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [startColor, endColor],
            ),
            border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.5)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: cs.surface.withValues(alpha: 0.75),
                  child: Icon(icon, color: cs.onSurface),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 13,
                          color: cs.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: cs.onSurfaceVariant),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
