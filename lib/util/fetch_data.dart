import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:w0001/presentation/viewmodel/calendar_view_model.dart';
import 'package:w0001/presentation/viewmodel/place_list_view_model.dart';
import 'package:w0001/presentation/viewmodel/worker_view_model.dart';

/// [main]에서 [UncontrolledProviderScope]와 동일한 컨테이너를 할당해야 함
ProviderContainer? rootProviderContainer;

class FetchData {
  static Future<void> fetchAllData() async {
    final container = rootProviderContainer;
    if (container != null) {
      await container.read(calendarProvider.notifier).refreshForFetchData();
      await container.read(workerProvider.notifier).refreshFromGlobalFetch();
      // 현장관리 탭 리스트도 즉시 갱신 (탭 전환 시 build가 다시 돌지 않는 케이스 대응).
      await container.read(placeListProvider.notifier).fetchAllPlace();
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
