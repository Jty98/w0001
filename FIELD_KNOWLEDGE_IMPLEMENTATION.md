# 현장 지식 사전 기능 구현 완료

## 📱 클라이언트 (Flutter) 구현 내용

### 1. 데이터 모델
- `lib/data/model/field_knowledge_models.dart`
  - `KnowledgeEntry`: 항목 모델
  - `KnowledgeEntryType`: 4가지 타입 (자재사전, 용어사전, 베스트, 워스트)
  - `KnowledgePage`: 페이지네이션 결과
  - `KnowledgeFilter`: 검색/필터 옵션

### 2. Repository & API
- `lib/domain/repository/field_knowledge_repository.dart`: Repository 인터페이스
- `lib/data/datasources/remote/field_knowledge_api.dart`: API 클라이언트
- `lib/data/repository/field_knowledge_repository_impl.dart`: Repository 구현

### 3. ViewModel (Riverpod)
- `lib/presentation/viewmodel/field_knowledge_providers.dart`
  - `fieldKnowledgeListProvider`: 리스트 상태 관리
  - `fieldKnowledgeEntryProvider`: 단일 항목 조회
  - `fieldKnowledgeRelatedEntriesProvider`: 연관 항목
  - `fieldKnowledgeTagsProvider`: 태그 목록

### 4. UI 화면
- `lib/ui/screen/extras/field_knowledge_management_hub_screen.dart`
  - 4가지 타입 선택 허브 화면
  
- `lib/ui/screen/extras/field_knowledge_list_screen.dart`
  - 타입별 리스트 화면
  - 이미지 타입: 그리드 뷰 (Pinterest 스타일)
  - 텍스트 타입: 리스트 뷰
  - 검색, 페이지네이션

- `lib/ui/screen/extras/field_knowledge_detail_screen.dart`
  - 상세 화면
  - 이미지 갤러리 (가로 스크롤)
  - 태그 섹션
  - 연관 항목
  - 메타 정보 (조회수, 등록일, 수정일)

- `lib/ui/screen/extras/field_knowledge_editor_screen.dart`
  - 생성/수정 화면
  - 제목, 본문, 이미지, 태그 입력
  - 활성/비활성 토글
  - 삭제 기능

## 🎨 UI/UX 특징

### 참고한 앱 패턴
- **Pinterest**: 이미지 중심 그리드 레이아웃 (자재사전, 시공사례)
- **Notion**: 깔끔한 카드 디자인, 태그 시스템
- **네이버 지식백과**: 상세 화면 구조, 연관 항목
- **Houzz**: 건설/인테리어 콘텐츠 큐레이션

### 디자인 원칙
1. **일관성**: 기존 앱의 `AppSectionCard`, `AppInsetCard` 컴포넌트 활용
2. **가독성**: 네이비/화이트/그레이 톤 유지
3. **효율성**: 페이지네이션으로 성능 최적화
4. **직관성**: 타입별 아이콘과 색상 구분

## 🚀 서버 구현 가이드

`SERVER_FIELD_KNOWLEDGE_GUIDE.md` 파일 참고

주요 내용:
- PostgreSQL 테이블 스키마
- REST API 엔드포인트 (CRUD, 검색, 태그, 연관 항목)
- 이미지 최적화 (썸네일, WebP 변환)
- 캐싱 전략 (Redis, CDN)
- 전문 검색 (PostgreSQL tsvector)
- 페이지네이션 최적화

## 📊 데이터 흐름

```
[Hub Screen]
    ↓ (사용자가 타입 선택)
[List Screen]
    ↓ (검색, 필터, 페이지네이션)
[Detail Screen]
    ↓ (조회수 증가)
[연관 항목 자동 표시]

[Editor Screen]
    ↓ (생성/수정/삭제)
[서버 API 호출]
    ↓ (성공)
[리스트 새로고침]
```

## 🔧 다음 단계 (서버 개발 후)

### 1. 서버 API 연결
- `lib/data/datasources/remote/field_knowledge_api.dart`의 `_basePath` 확인
- 실제 API 엔드포인트 구현

### 2. 이미지 업로드 통합
- 기존 `place_photos` API 재활용
- `FieldKnowledgeApi.uploadImage()` 구현

### 3. 추가 기능 (선택)
- [ ] 즐겨찾기/북마크
- [ ] 댓글/피드백
- [ ] 공유 기능
- [ ] 오프라인 모드 (로컬 캐싱)
- [ ] PDF 내보내기

### 4. 테스트
- [ ] 단위 테스트 (Repository, ViewModel)
- [ ] 위젯 테스트 (UI 컴포넌트)
- [ ] 통합 테스트 (전체 플로우)

## 📈 예상 성능

- **리스트 로딩**: < 500ms (20개 항목, 썸네일)
- **상세 조회**: < 300ms (캐싱 적용 시)
- **검색**: < 800ms (전문 검색 인덱스 사용 시)
- **이미지 로딩**: 썸네일 우선 로드 → 원본 lazy load

## 🎯 사용 시나리오

### 1. 작업자 (현장 인부)
- 자재 이름만 알고 있을 때 → 자재사전에서 사진과 특징 확인
- 용어가 생소할 때 → 용어사전에서 정의 검색
- 잘 시공된 사례 확인 → 베스트 시공 갤러리

### 2. 관리자 (사장님)
- 새로운 자재 등록 → 자재사전에 이미지·특징 추가
- 하자 발생 시 → 워스트 사례에 기록하여 재발 방지
- 지식 공유 → 태그로 분류하여 관리

### 3. 팀 전체
- 회사 내부 위키/노하우 데이터베이스로 활용
- 신입 교육 자료로 사용
- 프로젝트별 자재·용어 공유

## 🛠️ 기술 스택

### 클라이언트
- Flutter 3.x
- Riverpod (상태 관리)
- go_router (네비게이션)
- 기존 HTTP 클라이언트 (`AppHttpClient`)

### 서버 (권장)
- FastAPI / Django / NestJS
- PostgreSQL (전문 검색)
- Redis (캐싱)
- S3 / GCS (이미지 저장)
- CDN (이미지 전송 최적화)

## 📞 지원

서버 개발 시 질문이 있다면:
1. `SERVER_FIELD_KNOWLEDGE_GUIDE.md` 참고
2. API 스펙은 `lib/data/datasources/remote/field_knowledge_api.dart` 참고
3. 데이터 모델은 `lib/data/model/field_knowledge_models.dart` 참고

---

## ✅ 체크리스트

### 클라이언트 (완료)
- [x] 데이터 모델
- [x] Repository 인터페이스
- [x] API 클라이언트
- [x] ViewModel (Riverpod)
- [x] 허브 화면
- [x] 리스트 화면 (그리드/리스트)
- [x] 상세 화면
- [x] 편집 화면
- [x] 검색 & 필터
- [x] 페이지네이션
- [x] 연관 항목

### 서버 (TODO)
- [ ] 데이터베이스 마이그레이션
- [ ] REST API 구현
- [ ] 이미지 업로드 & 썸네일 생성
- [ ] 전문 검색
- [ ] 캐싱
- [ ] 권한 체크
- [ ] 로깅 & 모니터링

구현이 완료되면 실제 API를 연결하고 테스트해주세요! 🎉
