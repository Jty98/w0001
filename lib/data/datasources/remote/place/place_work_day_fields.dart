/// [POST /place-work-days] · [PATCH /place-work-days/:id] 요청 바디 필드.
/// 트러블 페어 재시도 키는 **백엔드 스펙과 반드시 일치**시키세요.
abstract final class PlaceWorkDayFields {
  PlaceWorkDayFields._();

  /// `true`일 때 서버가 경고를 확인한 투입으로 처리해 409 없이 저장하는 경우에만 동작합니다.
  static const String acknowledgeTroublePair = 'acknowledge_trouble_pair';
}
