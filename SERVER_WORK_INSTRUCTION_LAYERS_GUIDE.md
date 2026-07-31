# 작업지시 레이어 분리 — 서버 구현 가이드

앱은 **전체 / 공정별 / 개별** 작업지시를 별도 저장·조회하도록 변경되었습니다.  
`place_work_days.instruction_blocks`에 세 레이어를 합쳐 넣지 않습니다.

---

## 1. 테이블 설계

### `place_workday_site_instructions` (전체)

| 컬럼 | 타입 | 설명 |
|------|------|------|
| `id` | PK | |
| `pid` | FK → places | |
| `workdate` | DATE | `YYYY-MM-DD` |
| `instruction_blocks` | JSON | Quill 블록 배열 |
| `updated_at` | TIMESTAMP | |
| `updated_by` | FK → users (선택) | |

**UNIQUE** `(pid, workdate)`

### `place_workday_process_instructions` (공정별)

| 컬럼 | 타입 | 설명 |
|------|------|------|
| `id` | PK | |
| `pid` | FK | |
| `workdate` | DATE | |
| `workrole` | VARCHAR | 공정명 (`place_work_days.workrole`과 동일 문자열) |
| `instruction_blocks` | JSON | |
| `updated_at` | TIMESTAMP | |

**UNIQUE** `(pid, workdate, workrole)`

### `place_work_days` (기존 — 개별만)

- `instruction_blocks` 컬럼은 **해당 인력 행의 개별 작업지시만** 저장합니다.
- API 요청 시 `individual_instruction_blocks` 별칭도 허용합니다 (앱이 둘 다 보냄).

---

## 2. REST API

### 조회 묶음

```
GET /places/{pid}/work-day-instructions?workdate=2025-06-17
```

**Response 200**

```json
{
  "workdate": "2025-06-17",
  "site": {
    "instruction_blocks": [ /* 전체 */ ]
  },
  "process": [
    { "workrole": "타일", "instruction_blocks": [ /* ... */ ] },
    { "workrole": "전기", "instruction_blocks": [ /* ... */ ] }
  ]
}
```

- 행이 없으면 `site: null`, `process: []` 로 응답.
- 미구현 시 **404** — 앱은 구 방식(행에 병합 저장)으로 폴백합니다.

### 전체 upsert

```
PUT /places/{pid}/work-day-instructions/site
```

```json
{
  "workdate": "2025-06-17",
  "instruction_blocks": [ /* 빈 배열이면 삭제 또는 빈 행 유지 — 팀 정책에 맞게 */ ]
}
```

### 공정별 upsert

```
PUT /places/{pid}/work-day-instructions/process
```

```json
{
  "workdate": "2025-06-17",
  "workrole": "타일",
  "instruction_blocks": [ /* ... */ ]
}
```

### 인력 투입 (기존)

```
POST /place-work-days
PATCH /place-work-days/{pwdid}
```

```json
{
  "pid": 1,
  "hid": 2,
  "workdate": "2025-06-17",
  "dailywage": 150000,
  "workrole": "타일",
  "paid": 0,
  "instruction_blocks": [ /* 개별만 */ ],
  "individual_instruction_blocks": [ /* 동일 — 선택 */ ]
}
```

**저장 시**: `instruction_blocks`를 개별 레이어로만 DB에 기록. 전체·공정별은 위 PUT API로만 갱신.

---

## 3. 조회 시 합성 (읽기 전용)

다음 엔드포인트 응답에 **병합 결과**를 포함하면 앱·FCM·작업자 화면이 일관됩니다.

| 엔드포인트 | 필드 |
|------------|------|
| `GET /place-work-days`, `GET /place-work-days/{id}` | 아래 4종 |
| `GET /worker/dashboard/summary` 의 `work_days[]` | 아래 4종 |
| 작업자 일정·캘린더 연동 API | 동일 |

**권장 JSON 필드**

```json
{
  "individual_instruction_blocks": [ /* 이 행 개별 */ ],
  "site_instruction_blocks": [ /* pid+workdate 전체 */ ],
  "process_instruction_blocks": [ /* 이 행 workrole 공정별 */ ],
  "instruction_blocks": [ /* 위 3개 순서대로 병합 — 하위 호환 */ ],
  "instruction_preview": "플레인 텍스트 미리보기 (병합본 기준)"
}
```

**병합 순서**: `site` → `process`(해당 workrole) → `individual`

서버 헬퍼 예시 (의사코드):

```python
def merge_instruction_blocks(pwd_row, site_row, process_row):
    out = []
    for layer in (site_row, process_row, pwd_row):
        blocks = layer.instruction_blocks if layer else []
        if blocks: out.extend(blocks)
    return out
```

---

## 4. FCM

### 기존 타입 유지

| type | 용도 |
|------|------|
| `placeworkday_assignment` | 신규 투입 |
| `placeworkday_instruction` | 작업지시 변경 |

앱 라우터: `workdate`, `pwdid`(선택) → `/calendar` + 일정 새로고침 (`fcm_push_router.dart`).

### 발송 규칙 (권장)

| 변경 | 수신자 | payload |
|------|--------|---------|
| `POST /place-work-days` **신규 투입** (행 생성) | 해당 작업자 | `type=placeworkday_assignment`, `pid`, `workdate`, `pwdid`, `pname`(또는 `place_name`) |
| `POST .../workforce/bulk-assign` **기간 일괄 투입** | 해당 작업자 (1회) | 위 필드 + **`endDate`**(또는 `end_date`) — `workdate`=시작일, `endDate`=종료일. 일별 FCM 중복 발송 금지 |
| `PUT .../site` (전체 작업지시 수정) | 그날 그 현장 **모든** 투입 작업자 | `type=placeworkday_instruction`, `pid`, `workdate` (`pwdid` 생략 가능) |
| `PUT .../process` (공정별 지시 수정) | 같은 `pid`+`workdate` 이며 `workrole` 일치하는 행의 작업자 | 동일 |
| `PATCH` 개별 지시만 (기존 투입 행) | 해당 작업자 | `placeworkday_instruction` + `pwdid` |

**알림 설정** (`notification_settings.work_instruction` → `placeworkday_instruction`) 은 그대로 사용.

### assignment vs instruction

- **신규 투입**(`place_work_days` 행 생성, bulk-assign 포함): `placeworkday_assignment` 만 발송.  
  - notification 예: title `작업 배정`, body `{workdate} · {pname}에 투입되었습니다.` (날짜·현장명 포함)
  - **기간 일괄 투입**(`bulk-assign`): 작업자당 **FCM 1회**. payload에 `workdate`(시작), `endDate`(종료) 포함. 앱 표시: `7월 16일 ~ 7월 18일 · {pname}에 투입되었습니다.`
  - 개별·전체·공정별 지시가 함께 저장되어도 **instruction FCM 은 보내지 않음** (중복·오해 방지).
- **기존 투입에 지시만 변경** (site/process/개별 PATCH, 투입 행 신규 생성 없음): `placeworkday_instruction` 만 발송.  
  - notification 예: body `{workdate} · {pname} 작업지시가 변경되었습니다.`
- 같은 요청에서 투입과 지시 변경이 동시에 일어나면 **assignment 만** (instruction 중복 금지).

---

## 5. 데이터 마이그레이션

기존 `place_work_days.instruction_blocks`에 **합쳐진** 데이터가 있을 수 있습니다.

### 단계적 전략

1. **스키마 추가** — site/process 테이블 생성, API 배포.
2. **쓰기 경로 전환** — 앱·관리 UI는 레이어별 API 사용 (이미 반영됨).
3. **읽기 합성** — GET 시 DB 개별 + site + process 병합해 `instruction_blocks` 반환.
4. **(선택) 백필 스크립트**  
   - 동일 `pid+workdate` 그룹에서 바이트 동일한 prefix 블록을 site 후보로 추출하는 것은 어렵습니다.  
   - **실무 권장**: 마이그레이션 이후 새로 입력되는 데이터부터 레이어 분리. 기존 행은 `instruction_blocks` 전체를 **개별**로 두고, 관리자가 필요 시 전체·공정별을 다시 입력.

### 하위 호환

- 레이어 API **404** 인 동안 앱은 예전처럼 `POST` 시 세 레이어를 합쳐 `instruction_blocks` 한 필드로 보냅니다.
- 레이어 필드가 없는 구 응답은 `instruction_blocks` 만으로 표시합니다.

---

## 6. 권한·검증

- `PUT /places/{pid}/work-day-instructions/*` — 현장 관리 권한 있는 admin/super_admin.
- `GET` — 해당 현장 조회 권한.
- 작업자 `GET /worker/dashboard/summary` — 본인 행만, 합성된 `instruction_blocks` 포함.

---

## 7. 체크리스트

- [ ] site/process 테이블 + UNIQUE 제약
- [ ] GET bundle, PUT site, PUT process
- [ ] `place_work_days` POST/PATCH — 개별만 저장
- [ ] 목록·상세·worker dashboard — 레이어 필드 + 병합 `instruction_blocks`
- [ ] FCM: site/process 변경 시 해당 작업자 전원
- [ ] `instruction_preview` 병합본 기준 갱신
- [ ] schedule_memo / assignment 연동이 있다면 동일 병합 로직 공유

---

## 8. 앱 연동 요약

| 파일 | 역할 |
|------|------|
| `place_work_day_instructions_api.dart` | 레이어 API 클라이언트 |
| `place_workforce_editor_sheet.dart` | 저장: site/process PUT → 개별만 POST |
| `work_instruction_layers_merge.dart` | 읽기 시 3레이어 병합 |
| `PlaceWorkDayRead.resolvedInstructionBlocks` | 현장 UI 표시 |
| `WorkerDashboardWorkDay.fromJson` | 작업자 대시보드 병합 |

엔드포인트 상수: `ApiEndpoint.placeWorkDayInstructions(pid)` 등.
