import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:w0001/presentation/viewmodel/calendar_view_model.dart';
import 'package:w0001/presentation/viewmodel/dashboard_schedule_view_model.dart';
import 'package:w0001/presentation/viewmodel/dashboard_view_model.dart';
import 'package:w0001/presentation/viewmodel/place_detail_view_model.dart';
import 'package:w0001/presentation/viewmodel/place_list_view_model.dart';
import 'package:w0001/presentation/viewmodel/worker_view_model.dart';

/// [main]에서 [UncontrolledProviderScope]와 동일한 컨테이너를 할당해야 함
ProviderContainer? rootProviderContainer;

class FetchData {
  /// 비용·현장·일정 등 저장 직후 호출: 캘린더·인건비·현장·**대시보드 요약(KPI·차트 데이터)**·대시보드 일정까지 한 번에 맞춘다.
  static Future<void> fetchAllData() async {
    final container = rootProviderContainer;
    if (container != null) {
      await container.read(calendarProvider.notifier).refreshForFetchData();
      await container.read(workerProvider.notifier).refreshFromGlobalFetch();
      // 현장관리 탭 리스트도 즉시 갱신 (탭 전환 시 build가 다시 돌지 않는 케이스 대응).
      await container.read(placeListProvider.notifier).fetchAllPlace();
      // 대시보드 탭은 별도 Notifier라, 여기서 안 부르면 요약·지표가 옛 데이터로 남음.
      await container.read(dashboardProvider.notifier).fetch();
      await container.read(dashboardScheduleProvider.notifier).refresh();
      // 상세(인건비·자재·수익)는 별도 provider. 무효화(invalidate)하면 [PlaceDetailViewModel]이 dispose되며
      // TextEditingController가 파괴되어 수익 추가 직후 같은 화면에서 크래시가 난다. 이미 켜진 provider만
      // 동일 인스턴스로 데이터만 다시 읽는다.
      final places = container.read(placeListProvider).placeList;
      for (final p in places) {
        final id = p.pid;
        if (id == null) continue;
        final d = placeDetailProvider(id);
        if (!container.exists(d)) continue;
        await container.read(d.notifier).refreshForGlobalFetch();
      }
    }
  }
}

const List<String> categoryList = [
  '식대',
  '숙박',
  '유류비',
  '철물',
  '목재',
  '금속',
  '전기',
  '조명',
  '페인트',
  '설비',
  '타일',
  '공조',
  '소방',
  '유리',
  '조경',
  '필름',
  '사인물',
  '철거',
  '청소',
  '기타주문제작',
  '기타경비',
  '개인경비',
];
