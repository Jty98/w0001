# 대시보드(상황판) 공유 및 위젯 개발 계획서

사용자가 요청하신 대시보드(상황판)의 "일정 및 메모" 영역을 카카오톡/SNS로 공유하는 기능과, 잠금화면/홈화면에서 1주 단위의 일정을 확인할 수 있는 위젯 기능을 개발하기 위한 가이드 및 실행 계획입니다.

## User Review Required

> [!WARNING]
> **iOS 위젯 설정 관련**
> iOS 위젯을 구현하려면 Apple Developer 계정 설정에서 `App Groups` 기능이 활성화되어 있어야 합니다. 이 기능은 메인 앱과 위젯 간에 데이터를 공유하기 위해 필수적입니다. 개발 과정 중에 XCode를 통해 이 권한을 추가해야 정상 작동합니다.

> [!IMPORTANT]
> **Android 위젯 UI (Jetpack Compose vs XML)**
> 안드로이드 위젯 UI는 기본적으로 `XML Layout`을 통해 구현하거나 최근 기술인 `Jetpack Compose Glance`를 사용할 수 있습니다. Flutter의 `home_widget` 패키지와 연동하기엔 XML이 구조가 단순하고 안정적이어서 **XML을 기본으로 진행**하고자 합니다.

## Open Questions

> [!TIP]
> 1. **공유 기능 (Share)**: 이미지를 카카오톡으로 공유할 때, 시스템 기본 공유 시트(Share Sheet)를 띄워서 사용자가 카카오톡을 선택하게 하는 방식이면 충분할까요? 아니면 카카오톡 전용 버튼을 누르면 템플릿(카카오링크)으로 공유되는 방식이 필요하신가요? (전자는 `share_plus` 패키지로 쉽게 구현 가능하며 범용성이 높습니다. 후자는 `kakao_flutter_sdk_share` 연동 및 카카오 개발자 센터 등록이 필요합니다.)
> 2. **위젯 디자인**: 1주일 단위 일정 및 메모를 보여주는 위젯의 대략적인 디자인(예: 리스트 형태, 주간 달력 형태 등)을 원하시는 방향이 있나요?
> 3. **잠금화면 위젯**: iOS 16 이상의 잠금화면 위젯은 보통 좁은 영역에 표시됩니다. 홈화면(크게 표시됨)과 잠금화면(아이콘 및 텍스트 1~2줄)에 표시할 데이터의 형태를 다르게 가져가는 것이 좋습니다. 이 점 동의하시나요?

## Proposed Changes

이 계획은 크게 두 파트로 나뉩니다. 첫째는 대시보드 화면 캡처 및 공유 기능이고, 둘째는 `home_widget`을 사용한 네이티브 플랫폼 연동입니다.

### 1. 패키지 의존성 추가 (Dependencies)

#### [MODIFY] pubspec.yaml
- `screenshot`: ^2.3.0 (특정 위젯 영역을 이미지로 캡처하기 위해 사용)
- `home_widget`: ^0.3.1 (Flutter 앱의 데이터를 iOS 및 Android 위젯으로 전송하기 위해 사용)
- `shared_preferences`: ^2.2.3 (로컬 데이터 캐싱 및 `home_widget`과 연동)

---

### 2. Flutter UI 및 데이터 로직 업데이트

#### [MODIFY] lib/ui/screen/1_dashboard/... (대시보드 UI 파일)
- 일정 및 메모를 감싸는 영역에 `Screenshot` 또는 `RepaintBoundary` 위젯 적용
- "공유하기" 버튼 추가: 클릭 시 해당 영역을 캡처하고 `share_plus`를 통해 공유

#### [NEW] lib/util/widget_data_manager.dart
- 앱이 실행되거나 일정이 변경될 때, 이번 주 1주일치 일정/메모 데이터를 가져와서 JSON 문자열로 변환
- `HomeWidget.saveWidgetData` 함수를 사용하여 네이티브(iOS/Android) 쪽에 데이터 전송
- `HomeWidget.updateWidget` 함수로 위젯 리프레시 요청 트리거

---

### 3. Android 네이티브 작업 (Kotlin & XML)

#### [MODIFY] android/app/src/main/AndroidManifest.xml
- `AppWidgetProvider`를 등록하기 위한 receiver 추가

#### [NEW] android/app/src/main/res/xml/widget_info.xml
- 안드로이드 위젯의 메타데이터(크기, 업데이트 주기 등) 정의 파일

#### [NEW] android/app/src/main/res/layout/widget_layout.xml
- 안드로이드 홈화면 위젯의 UI 레이아웃 설계 (1주 단위 일정을 보여주는 리스트 또는 텍스트 뷰)

#### [NEW] android/app/src/main/java/.../ScheduleWidgetProvider.kt
- Kotlin으로 작성되는 위젯 프로바이더
- Flutter가 저장한 `SharedPreferences` 데이터를 읽어와서 `widget_layout.xml`의 각 요소에 데이터를 매핑하고 업데이트

---

### 4. iOS 네이티브 작업 (SwiftUI)

#### [NEW] ios/Runner.xcodeproj & ios/ScheduleWidgetExtension
- XCode 상에서 `Widget Extension` 타겟 생성 (이 작업은 CLI로 완벽히 설정하기 까다로울 수 있으나, 필요한 파일을 생성해 드립니다.)
- `App Groups` Capability를 앱과 위젯 타겟에 모두 추가 (com.yourcompany.app.widgetgroup 형태)

#### [NEW] ios/ScheduleWidgetExtension/ScheduleWidgetExtension.swift
- SwiftUI를 사용한 위젯 UI 개발
- `TimelineProvider`를 구현하여 Flutter의 `UserDefaults` (AppGroup 기반) 데이터를 파싱하여 1주 단위 일정 로드
- 홈 화면용 뷰와 잠금 화면용 뷰(액세서리 뷰) 분리 구현

## Verification Plan

### Automated Tests
- 없음 (UI 및 네이티브 연동에 집중)

### Manual Verification
1. **공유 기능 테스트**: 대시보드 화면에서 공유 버튼을 눌러 카카오톡에 정상적으로 이미지가 전송되는지 확인.
2. **데이터 동기화 테스트**: 앱 내에서 일정/메모를 추가했을 때, 해당 내용이 `home_widget`을 통해 네이티브 데이터 저장소에 정상 기록되는지 로그 확인.
3. **Android 위젯 테스트**: 홈 화면에 위젯을 추가하고 1주 일정이 잘 나오는지 확인. 앱 내 수정 사항이 위젯에 반영되는지 확인.
4. **iOS 위젯 테스트**: 홈 화면 및 잠금 화면에 위젯 추가 후 데이터 및 UI 확인. (이 부분은 XCode 빌드가 필요합니다.)

**위 계획을 읽어보시고 Open Questions에 대해 답변해 주시면, 제가 직접 각 파일들을 수정/생성하여 기능 구현을 진행하겠습니다.**
