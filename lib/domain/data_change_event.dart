/// 저장·삭제 후 갱신 범위를 좁히기 위한 이벤트.
enum DataChangeKind {
  workCost,
  materialCost,
  place,
  human,
  revenue,
  photo,
  schedule,
  processSchedule,
}

class DataChangeEvent {
  const DataChangeEvent(
    this.kind, {
    this.pid,
    this.hid,
    this.date,
    this.refreshCalendar = true,
  });

  final DataChangeKind kind;
  final int? pid;
  final int? hid;
  final DateTime? date;

  /// `false`이면 캘린더 provider 갱신을 생략한다(해당 화면에서 이미 반영한 경우).
  final bool refreshCalendar;

  static const workCostSaved = DataChangeEvent(DataChangeKind.workCost);
  static const materialCostSaved = DataChangeEvent(DataChangeKind.materialCost);
  static const placeSaved = DataChangeEvent(DataChangeKind.place);
  static const humanSaved = DataChangeEvent(DataChangeKind.human);
  static const revenueSaved = DataChangeEvent(DataChangeKind.revenue);
  static const photoSaved = DataChangeEvent(DataChangeKind.photo);
  static const scheduleSaved = DataChangeEvent(DataChangeKind.schedule);
  static const processScheduleSaved =
      DataChangeEvent(DataChangeKind.processSchedule);

  DataChangeEvent withPid(int placeId) => DataChangeEvent(
        kind,
        pid: placeId,
        hid: hid,
        date: date,
        refreshCalendar: refreshCalendar,
      );

  DataChangeEvent withDate(DateTime d) => DataChangeEvent(
        kind,
        pid: pid,
        hid: hid,
        date: DateTime(d.year, d.month, d.day),
        refreshCalendar: refreshCalendar,
      );

  DataChangeEvent withoutCalendarRefresh() => DataChangeEvent(
        kind,
        pid: pid,
        hid: hid,
        date: date,
        refreshCalendar: false,
      );
}
