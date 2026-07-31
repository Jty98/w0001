# 현장 작업 체크리스트 — 서버 구현 가이드

앱은 **현장별 · 날짜별 작업 체크리스트**를 서버 API와 연동합니다.  
(초기 프로토타입의 로컬 `SharedPreferences` 저장은 제거되었습니다.)

---

## 1. 기능 요약

| 항목 | 설명 |
|------|------|
| 단위 | `pid` + `work_date` (`YYYY-MM-DD`) |
| 항목 | 공정표 공정명(`process_group`) 아래 작업 텍스트(`title`) |
| 상태 | `active` · `checked` · `deferred` |
| 미루기 | 원본 `deferred`, 대상일에 새 항목 생성, `deferrals` 기록 |
| 권한 | 관리자·작업자 동일 — 추가·수정·체크·미루기 모두 허용 |
| 제외 | 일정 메모의 시간·알림 없음 |

**향후(앱 v2):** 체크리스트 텍스트 ↔ 공정표 작업 자동 매칭 — 본 가이드 범위 밖.

---

## 2. 테이블 설계

### `place_checklist_items`

| 컬럼 | 타입 | 설명 |
|------|------|------|
| `id` | VARCHAR(64) PK | 클라이언트 생성 UUID/로컬 ID |
| `pid` | FK → places | |
| `work_date` | DATE | |
| `title` | VARCHAR(200) | 작업 내용 (예: 덕트시공) |
| `process_group` | VARCHAR(100) | 공정표 행 이름 (예: 주방설비). 빈 문자열 = 기타 |
| `process_task_id` | FK nullable | 공정표 `tasks.id` (선택, 자동매칭용 예약) |
| `status` | VARCHAR(16) | `active` \| `checked` \| `deferred` |
| `sort_order` | INT | 그룹 내 정렬 |
| `created_at_ms` | BIGINT | |
| `updated_at_ms` | BIGINT | |
| `created_by` | FK → users nullable | 감사용 |
| `updated_by` | FK → users nullable | |

**인덱스:** `(pid, work_date)`, `(pid, work_date, process_group)`

### `place_checklist_deferrals`

| 컬럼 | 타입 | 설명 |
|------|------|------|
| `id` | VARCHAR(64) PK | |
| `pid` | FK | |
| `source_item_id` | FK → place_checklist_items | 미룬 원본 행 |
| `carried_item_id` | FK nullable | 대상일에 생성된 행 |
| `from_date` | DATE | |
| `to_date` | DATE | |
| `title` | VARCHAR(200) | 스냅샷 |
| `process_group` | VARCHAR(100) | 스냅샷 |
| `reason` | VARCHAR(500) | 선택 사유 |
| `created_at_ms` | BIGINT | |
| `created_by` | FK nullable | |

---

## 3. REST API

### 조회 (날짜 범위)

```
GET /places/{pid}/checklist?from=2025-06-01&to=2025-06-30
```

**Response 200**

```json
{
  "items": [
    {
      "id": "abc123",
      "work_date": "2025-06-24",
      "title": "덕트시공",
      "process_group": "주방설비",
      "process_task_id": 42,
      "status": "active",
      "sort_order": 0,
      "created_at_ms": 1719200000000,
      "updated_at_ms": 1719200000000
    }
  ],
  "deferrals": [
    {
      "id": "def456",
      "item_id": "abc122",
      "from_date": "2025-06-23",
      "to_date": "2025-06-24",
      "title": "덕트시공",
      "process_group": "주방설비",
      "reason": "자재 미도착",
      "created_at_ms": 1719113600000
    }
  ]
}
```

- 미구현 시 **404** — 앱은 오류 메시지 표시.

### 항목 생성

```
POST /places/{pid}/checklist/items
```

```json
{
  "work_date": "2025-06-24",
  "title": "덕트시공",
  "process_group": "주방설비",
  "sort_order": 0
}
```

**Response 201** — 생성된 item 객체 (`id` 서버 발급 또는 클라 `id` 수용).

### 항목 수정 (체크·제목·공정 변경)

```
PATCH /places/{pid}/checklist/items/{id}
```

```json
{
  "title": "덕트시공",
  "process_group": "주방설비",
  "status": "checked",
  "sort_order": 1
}
```

### 항목 삭제

```
DELETE /places/{pid}/checklist/items/{id}
```

### 미루기 (원자적)

```
POST /places/{pid}/checklist/items/{id}/defer
```

```json
{
  "to_date": "2025-06-25",
  "reason": "자재 미도착"
}
```

**서버 처리 (트랜잭션):**

1. 원본 `status = deferred`, `updated_at_ms` 갱신  
2. `to_date`에 새 item (`active`) 생성 — `title`·`process_group` 복사  
3. `place_checklist_deferrals` 행 추가 (`source_item_id`, `carried_item_id`)

**Response 200**

```json
{
  "deferral": { /* ... */ },
  "carried_item": { /* 새 항목 */ }
}
```

**검증**

- `status`가 `checked` 또는 `deferred`이면 409  
- `to_date == work_date` 이면 400  
- `to_date`에 동일 `title`+`process_group` 중복 정책은 팀 선택(허용 또는 409)

---

## 4. 권한

- `GET` / `POST` / `PATCH` / `DELETE` / `defer`: 해당 `pid`에 접근 가능한 **모든 역할** (관리자·작업자 동일).
- 기존 `GET /places/me` 멤버십 규칙과 동일하게 적용.

---

## 5. 앱 ↔ 서버 동기화

- 앱 `PlaceChecklistRemoteRepository`가 API를 직접 호출합니다.
- 조회: 선택일 기준 **±90일** (`GET ?from=&to=`).
- 생성·수정·삭제·미루기 후 해당 범위를 재조회합니다.

---

## 6. 공정표 연동

- `process_group`은 공정표 `tasks[].name`과 **문자열 일치**로 그룹핑 (현재 앱).
- 선택 필드 `process_task_id`에 공정표 task PK 저장 시, 공정명 변경에도 추적 가능.
- 앱은 선택 날짜에 공정표 `days`에 포함된 공정에 **「공정 예정」** 배지 표시.

---

## 7. 앱 JSON 스키마 (API 응답 — 참고)

```json
{
  "123": {
    "items": [
      {
        "id": "...",
        "work_date": "2025-06-24",
        "title": "덕트시공",
        "process_group": "주방설비",
        "sort_order": 0,
        "status": "active",
        "created_at_ms": 0,
        "updated_at_ms": 0
      }
    ],
    "deferrals": [
      {
        "id": "...",
        "item_id": "...",
        "from_date": "2025-06-24",
        "to_date": "2025-06-25",
        "title": "덕트시공",
        "process_group": "주방설비",
        "reason": "자재 미도착",
        "created_at_ms": 0
      }
    ]
  }
}
```

키 `"123"` = `pid`.

---

## 8. 체크리스트

- [ ] `place_checklist_items` / `place_checklist_deferrals` 마이그레이션
- [ ] GET 범위 조회
- [ ] CRUD + defer 트랜잭션
- [ ] 현장 멤버 권한
- [ ] (선택) bulk sync 엔드포인트
- [x] 앱 `PlaceChecklistRemoteRepository` 연결
