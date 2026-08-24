/// 작업지시 탭에서 현장 상세가 열린 상태의 시스템 뒤로가기 처리.
///
/// `/add` 는 쉘 탭 루트라 [GoRouter.pop]이 없고, 부모 [ShellTabRootBackScope]가
/// 뒤로가기를 앱 종료 확인으로 가로챈다. 허브가 이 핸들러를 등록해 첫 화면으로 돌린다.
bool Function()? workInstructionHubSystemBackHandler;

/// 현장이 선택된 상태면 목록으로 돌리고 `true`.
bool consumeWorkInstructionHubBackNavigation() {
  final fn = workInstructionHubSystemBackHandler;
  if (fn == null) return false;
  return fn();
}
