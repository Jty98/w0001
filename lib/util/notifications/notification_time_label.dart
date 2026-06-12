/// 알림함 목록용 상대·절대 시각 라벨.
String notificationTimeLabel(DateTime createdAt, {DateTime? now}) {
  final n = now ?? DateTime.now();
  final local = createdAt.toLocal();
  final diff = n.difference(local);
  if (diff.isNegative || diff.inSeconds < 60) return '방금 전';
  if (diff.inMinutes < 60) return '${diff.inMinutes}분 전';
  if (diff.inHours < 24 && _isSameCalendarDay(n, local)) {
    final h = local.hour.toString().padLeft(2, '0');
    final m = local.minute.toString().padLeft(2, '0');
    return '오늘 $h:$m';
  }
  if (diff.inDays < 7) return '${diff.inDays}일 전';
  return '${local.month}월 ${local.day}일 '
      '${local.hour.toString().padLeft(2, '0')}:'
      '${local.minute.toString().padLeft(2, '0')}';
}

bool _isSameCalendarDay(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}
