/// `GET /dashboard/calendar-workforce-dots` 파싱 결과.
class DashboardCalendarWorkforceDots {
  const DashboardCalendarWorkforceDots({
    required this.byDay,
    required this.costDayKeys,
  });

  /// 날짜(`yyyy-MM-dd`) → 공정·투입 플래그.
  final Map<String, ({bool sch, bool work})> byDay;

  /// 인건비·자재비가 있는 날 (`yyyy-MM-dd`).
  final Set<String> costDayKeys;
}
