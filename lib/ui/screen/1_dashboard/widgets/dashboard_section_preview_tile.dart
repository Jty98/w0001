import 'package:flutter/material.dart';
import 'package:w0001/util/responsive_layout.dart';

enum DashboardSectionPreviewKind {
  quote,
  schedule,
  announcement,
  kpi,
  welcome,
  today,
  checklist,
  generic,
}

class DashboardSectionPreviewTile extends StatelessWidget {
  const DashboardSectionPreviewTile({
    super.key,
    required this.title,
    required this.icon,
    required this.onTap,
    this.previewKind = DashboardSectionPreviewKind.generic,
  });

  final String title;
  final IconData icon;
  final VoidCallback onTap;
  final DashboardSectionPreviewKind previewKind;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest.withValues(alpha: 0.34),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: cs.outlineVariant),
          ),
          padding: EdgeInsets.fromLTRB(
            context.rsi(12),
            context.rsi(10),
            context.rsi(12),
            context.rsi(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(icon, size: context.rsi(18), color: cs.primary),
                  SizedBox(width: context.rsi(8)),
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  SizedBox(width: context.rsi(6)),
                  InkResponse(
                    radius: context.rsi(16),
                    onTap: onTap,
                    child: Icon(
                      Icons.add_circle_outline_rounded,
                      size: context.rsi(18),
                      color: cs.primary,
                    ),
                  ),
                ],
              ),
              SizedBox(height: context.rsi(8)),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: cs.surface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: cs.outlineVariant.withValues(alpha: 0.7),
                    ),
                  ),
                  padding: EdgeInsets.all(context.rsi(7)),
                  child: _previewByKind(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _line(BuildContext context, {required double widthFactor}) {
    final cs = Theme.of(context).colorScheme;
    return FractionallySizedBox(
      widthFactor: widthFactor,
      child: Container(
        height: context.rsi(7),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(999),
        ),
      ),
    );
  }

  Widget _previewByKind(BuildContext context) {
    switch (previewKind) {
      case DashboardSectionPreviewKind.quote:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _line(context, widthFactor: 0.18),
            SizedBox(height: context.rsi(5)),
            _line(context, widthFactor: 0.9),
            SizedBox(height: context.rsi(5)),
            _line(context, widthFactor: 0.62),
          ],
        );
      case DashboardSectionPreviewKind.schedule:
      case DashboardSectionPreviewKind.today:
        return Column(
          children: [
            Row(
              children: [
                _dot(context),
                SizedBox(width: context.rsi(6)),
                Expanded(child: _line(context, widthFactor: 1)),
              ],
            ),
            SizedBox(height: context.rsi(6)),
            Row(
              children: [
                _dot(context),
                SizedBox(width: context.rsi(6)),
                Expanded(child: _line(context, widthFactor: 0.78)),
              ],
            ),
          ],
        );
      case DashboardSectionPreviewKind.announcement:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _line(context, widthFactor: 0.84),
            SizedBox(height: context.rsi(6)),
            _line(context, widthFactor: 0.66),
            SizedBox(height: context.rsi(6)),
            Row(
              children: [
                _chip(context),
                SizedBox(width: context.rsi(6)),
                _chip(context),
              ],
            ),
          ],
        );
      case DashboardSectionPreviewKind.kpi:
        return Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            _bar(context, 0.42),
            SizedBox(width: context.rsi(4)),
            _bar(context, 0.78),
            SizedBox(width: context.rsi(4)),
            _bar(context, 0.56),
            SizedBox(width: context.rsi(4)),
            _bar(context, 0.92),
          ],
        );
      case DashboardSectionPreviewKind.welcome:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _line(context, widthFactor: 0.58),
            SizedBox(height: context.rsi(6)),
            _line(context, widthFactor: 0.86),
          ],
        );
      case DashboardSectionPreviewKind.checklist:
        return Column(
          children: [
            Row(
              children: [
                _checkBox(context),
                SizedBox(width: context.rsi(6)),
                Expanded(child: _line(context, widthFactor: 0.92)),
              ],
            ),
            SizedBox(height: context.rsi(6)),
            Row(
              children: [
                _checkBox(context),
                SizedBox(width: context.rsi(6)),
                Expanded(child: _line(context, widthFactor: 0.67)),
              ],
            ),
          ],
        );
      case DashboardSectionPreviewKind.generic:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _line(context, widthFactor: 0.78),
            SizedBox(height: context.rsi(5)),
            _line(context, widthFactor: 0.54),
          ],
        );
    }
  }

  Widget _dot(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: context.rsi(7),
      height: context.rsi(7),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(999),
      ),
    );
  }

  Widget _chip(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: context.rsi(28),
      height: context.rsi(10),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(999),
      ),
    );
  }

  Widget _bar(BuildContext context, double heightFactor) {
    final cs = Theme.of(context).colorScheme;
    return Expanded(
      child: Align(
        alignment: Alignment.bottomCenter,
        child: FractionallySizedBox(
          heightFactor: heightFactor,
          child: Container(
            decoration: BoxDecoration(
              color: cs.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ),
      ),
    );
  }

  Widget _checkBox(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: context.rsi(10),
      height: context.rsi(10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(2),
        border: Border.all(color: cs.surfaceContainerHigh, width: 1.4),
      ),
    );
  }
}
