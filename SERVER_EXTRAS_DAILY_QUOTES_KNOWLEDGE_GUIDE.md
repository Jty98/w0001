# 부가기능 서버 구현 가이드

이 문서는 앱에 연결된 **오늘의 명언 CRUD/일일 선정 API**와 이후 추가할
**자재·용어 사전, 베스트·워스트 시공 사례**의 서버 계약을 정의한다.

앱은 모든 경로 앞에 환경별 `base_url`을 붙이며, 아래 경로를 그대로 호출한다.

## 1. 오늘의 명언 핵심 정책

- 명언 원본은 DB의 `daily_quotes` 테이블에서 CRUD한다.
- 모든 명언에는 서버가 발급한 `BIGINT id`가 있다.
- `is_active = false`인 명언은 자동 선정하지 않지만 관리 목록에는 표시할 수 있다.
- 회사/조직의 날짜는 `Asia/Seoul` 기준으로 계산한다.
- 하루에 선정된 값은 `daily_quote_days`에 **문구 스냅샷**으로 저장한다.
- 원본 수정/삭제 후에도 과거 및 당일 문구는 바뀌지 않는다.
- 관리자 직접 지정은 해당 날짜에만 적용하고 다음 날에는 자동 모드로 복귀한다.
- 자정에 반드시 배치 작업을 실행할 필요는 없다. 첫 `GET /today` 요청에서
  해당 날짜 행을 원자적으로 생성하는 lazy 방식을 기본으로 한다.
- 여러 요청이 동시에 들어와도 `(organization_id, quote_date)` UNIQUE 제약으로
  하루 한 건만 생성되어야 한다.

멀티 테넌트 서버가 아니라면 `organization_id = 1` 고정값을 사용해도 된다.
멀티 테넌트라면 요청 body/query에서 조직 ID를 받지 말고 JWT의 사용자 소속에서 결정한다.

## 2. DB 스키마

MySQL 8 기준 예시다. PostgreSQL은 `AUTO_INCREMENT`를 `GENERATED ... AS IDENTITY`,
`DATETIME(6)`을 `TIMESTAMPTZ`로 바꾸면 된다.

```sql
CREATE TABLE daily_quotes (
    id BIGINT NOT NULL AUTO_INCREMENT,
    author VARCHAR(100) NOT NULL,
    author_profile VARCHAR(100) NOT NULL DEFAULT '',
    message VARCHAR(500) NOT NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    deleted_at DATETIME(6) NULL,
    created_by VARCHAR(255) NULL,
    updated_by VARCHAR(255) NULL,
    created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    updated_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6)
        ON UPDATE CURRENT_TIMESTAMP(6),
    PRIMARY KEY (id),
    INDEX ix_daily_quotes_active (is_active, deleted_at),
    INDEX ix_daily_quotes_author (author)
);

CREATE TABLE daily_quote_settings (
    organization_id BIGINT NOT NULL,
    mode VARCHAR(20) NOT NULL DEFAULT 'random',
    recent_history_limit INT NOT NULL DEFAULT 30,
    timezone VARCHAR(64) NOT NULL DEFAULT 'Asia/Seoul',
    last_quote_id BIGINT NULL,
    updated_by VARCHAR(255) NULL,
    updated_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6)
        ON UPDATE CURRENT_TIMESTAMP(6),
    PRIMARY KEY (organization_id),
    CONSTRAINT ck_daily_quote_mode
        CHECK (mode IN ('random', 'sequential')),
    CONSTRAINT ck_daily_quote_history_limit
        CHECK (recent_history_limit BETWEEN 1 AND 365),
    CONSTRAINT fk_daily_quote_settings_last
        FOREIGN KEY (last_quote_id) REFERENCES daily_quotes(id)
        ON DELETE SET NULL
);

CREATE TABLE daily_quote_days (
    id BIGINT NOT NULL AUTO_INCREMENT,
    organization_id BIGINT NOT NULL,
    quote_date DATE NOT NULL,
    source VARCHAR(20) NOT NULL,
    quote_id BIGINT NULL,
    author_snapshot VARCHAR(100) NOT NULL,
    author_profile_snapshot VARCHAR(100) NOT NULL DEFAULT '',
    message_snapshot VARCHAR(500) NOT NULL,
    overridden_by VARCHAR(255) NULL,
    created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    updated_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6)
        ON UPDATE CURRENT_TIMESTAMP(6),
    PRIMARY KEY (id),
    UNIQUE KEY uq_daily_quote_day (organization_id, quote_date),
    INDEX ix_daily_quote_day_history
        (organization_id, quote_date DESC, quote_id),
    CONSTRAINT ck_daily_quote_day_source
        CHECK (source IN ('pool', 'override')),
    CONSTRAINT fk_daily_quote_day_quote
        FOREIGN KEY (quote_id) REFERENCES daily_quotes(id)
        ON DELETE SET NULL
);
```

삭제 API는 실제 row를 바로 지우기보다 `deleted_at = now(), is_active = false`로
soft delete하는 방식을 권장한다. 목록 및 자동 선정 쿼리에는 항상
`deleted_at IS NULL` 조건을 사용한다.

## 3. 앱이 사용하는 JSON 모델

### 명언

```json
{
  "id": 42,
  "author": "소크라테스",
  "author_profile": "철학자",
  "message": "반성되지 않는 삶은 인간으로서 살 가치가 없다.",
  "is_active": true,
  "created_at": "2026-07-19T10:00:00+09:00",
  "updated_at": "2026-07-19T10:00:00+09:00"
}
```

### 오늘의 명언

```json
{
  "date": "2026-07-19",
  "source": "pool",
  "quote": {
    "id": 42,
    "author": "소크라테스",
    "author_profile": "철학자",
    "message": "반성되지 않는 삶은 인간으로서 살 가치가 없다.",
    "is_active": true
  },
  "next_refresh_at": "2026-07-20T00:00:00+09:00"
}
```

직접 지정된 문구는 명언 풀 row가 아니므로 `quote.id`를 `0`으로 반환한다.
`source`는 `override`가 된다.

## 4. CRUD 및 설정 API

모든 API는 로그인 JWT가 필요하다. 조회 중 `GET /today`만 모든 승인 사용자에게
허용하고 나머지는 `admin/super_admin` 또는 서버의 management 역할만 허용한다.

### 목록

```http
GET /extras/daily-quotes?page=1&page_size=30&q=소크라테스&is_active=true
Authorization: Bearer ...
```

```json
{
  "items": [],
  "page": 1,
  "page_size": 30,
  "total": 0
}
```

- `q`: `message`, `author`, `author_profile` 부분 검색
- `is_active`: 생략 시 활성/비활성 모두
- 정렬: `id DESC`
- `page_size`: 최대 200

### 생성

```http
POST /extras/daily-quotes
Content-Type: application/json

{
  "author": "소크라테스",
  "author_profile": "철학자",
  "message": "반성되지 않는 삶은 인간으로서 살 가치가 없다.",
  "is_active": true
}
```

- 성공: `201 Created`와 생성된 명언 JSON
- 검증 실패: `422`

### 수정

```http
PATCH /extras/daily-quotes/{id}
```

앱은 현재 네 필드를 모두 보내지만 서버는 부분 수정도 허용한다.
성공 시 수정된 명언 JSON을 반환한다.

### 삭제

```http
DELETE /extras/daily-quotes/{id}
```

- soft delete 처리 후 `204 No Content`
- 존재하지 않거나 이미 삭제됨: `404`
- 오늘 스냅샷은 삭제하지 않는다.

### 자동 선정 설정

```http
GET /extras/daily-quotes/settings
PUT /extras/daily-quotes/settings
```

```json
{
  "mode": "random",
  "recent_history_limit": 30,
  "timezone": "Asia/Seoul"
}
```

PUT body와 response 형식은 같다. 클라이언트가 임의 timezone을 변경하지 못하게
하려면 서버에서 허용 목록을 검증한다.

### 오늘 조회

```http
GET /extras/daily-quotes/today
```

해당 날짜 스냅샷이 있으면 그대로 반환하고, 없으면 아래 알고리즘으로 생성 후 반환한다.
활성 명언이 하나도 없으면 `404` 대신 다음처럼 `204 No Content`를 반환할 수도 있지만,
현재 Flutter 모델은 JSON을 기대하므로 **`404` + 명확한 error detail**을 권장한다.

### 오늘만 직접 지정

```http
PUT /extras/daily-quotes/today/override

{
  "author": "현장 관리자",
  "author_profile": "",
  "message": "안전은 타협하지 않습니다."
}
```

오늘의 `daily_quote_days` row를 `source = override`, `quote_id = NULL`로 upsert한다.
응답은 오늘의 명언 JSON이다.

### 직접 지정 해제

```http
DELETE /extras/daily-quotes/today/override
```

오늘 row가 override일 때 삭제한 뒤 즉시 자동 선정하여 그 결과 JSON을 반환한다.
pool source인 경우에도 idempotent하게 현재 값을 반환해도 된다.

## 5. FastAPI/SQLAlchemy 구현 구조

권장 파일:

```text
app/
  models/daily_quote.py
  schemas/daily_quote.py
  repositories/daily_quote_repository.py
  services/daily_quote_service.py
  api/routes/daily_quotes.py
```

Pydantic 요청 스키마:

```python
from typing import Literal
from pydantic import BaseModel, Field

class DailyQuoteWrite(BaseModel):
    author: str = Field(min_length=1, max_length=100)
    author_profile: str = Field(default="", max_length=100)
    message: str = Field(min_length=1, max_length=500)
    is_active: bool = True

class DailyQuoteSettingsWrite(BaseModel):
    mode: Literal["random", "sequential"]
    recent_history_limit: int = Field(ge=1, le=365)
    timezone: str = "Asia/Seoul"

class DailyQuoteOverrideWrite(BaseModel):
    author: str = Field(min_length=1, max_length=100)
    author_profile: str = Field(default="", max_length=100)
    message: str = Field(min_length=1, max_length=500)
```

라우터 골격:

```python
router = APIRouter(prefix="/extras/daily-quotes", tags=["daily-quotes"])

@router.get("/today")
def get_today(
    db: Session = Depends(get_db),
    user: User = Depends(require_approved_user),
):
    return service.resolve_today(db, organization_id=user.organization_id)

@router.get("")
def list_quotes(
    page: int = Query(1, ge=1),
    page_size: int = Query(30, ge=1, le=200),
    q: str = "",
    is_active: bool | None = None,
    db: Session = Depends(get_db),
    user: User = Depends(require_management_user),
):
    return repository.list(db, page, page_size, q, is_active)

@router.post("", status_code=201)
def create_quote(
    body: DailyQuoteWrite,
    db: Session = Depends(get_db),
    user: User = Depends(require_management_user),
):
    return repository.create(db, body, actor=user.uid)

@router.patch("/{quote_id}")
def update_quote(...): ...

@router.delete("/{quote_id}", status_code=204)
def delete_quote(...): ...

@router.get("/settings")
def get_settings(...): ...

@router.put("/settings")
def update_settings(...): ...

@router.put("/today/override")
def override_today(...): ...

@router.delete("/today/override")
def clear_override(...): ...
```

주의: FastAPI에서는 `/{quote_id}` 동적 경로보다 `/settings`, `/today` 고정 경로를
먼저 등록하거나 `quote_id: int`로 타입을 제한한다.

## 6. 일일 선정 알고리즘

```python
def resolve_today(db: Session, organization_id: int):
    settings = get_or_create_settings(db, organization_id)
    tz = ZoneInfo(settings.timezone)
    now = datetime.now(tz)
    today = now.date()

    existing = find_day(db, organization_id, today)
    if existing:
        return serialize_day(existing, now)

    recent_ids = select_recent_quote_ids(
        db,
        organization_id=organization_id,
        since=today - timedelta(days=settings.recent_history_limit),
    )
    candidates = select_active_quotes_excluding(db, recent_ids)

    # 명언 개수가 중복 방지 기간보다 적으면 전체 활성 풀로 재선정한다.
    if not candidates:
        candidates = select_all_active_quotes(db)
    if not candidates:
        raise HTTPException(404, "활성 명언이 없습니다.")

    if settings.mode == "sequential":
        picked = select_next_by_id(candidates, settings.last_quote_id)
    else:
        picked = secrets.choice(candidates)

    day = DailyQuoteDay(
        organization_id=organization_id,
        quote_date=today,
        source="pool",
        quote_id=picked.id,
        author_snapshot=picked.author,
        author_profile_snapshot=picked.author_profile,
        message_snapshot=picked.message,
    )
    db.add(day)
    settings.last_quote_id = picked.id

    try:
        db.commit()
    except IntegrityError:
        # 다른 요청이 같은 날짜를 먼저 생성했다.
        db.rollback()
        day = find_day(db, organization_id, today)

    return serialize_day(day, now)
```

순차 모드에서 `recent_ids`를 제외한 후보만 정렬한 뒤
`id > last_quote_id` 중 최소 ID를 선택하고, 없으면 후보의 최소 ID로 순환한다.
랜덤 선정에는 예측 불가능성이 중요하지 않으므로 DB `ORDER BY RAND()`도 가능하지만
풀이 커지면 후보 ID만 가져와 `secrets.choice`/`random.choice`하는 편이 낫다.

`next_refresh_at`은 해당 timezone의 다음 날 00:00을 ISO 8601 offset 포함 형식으로 반환한다.

## 7. 초기 데이터 적재

초기 명언은 서버 저장소의 `seed/daily_quotes.json`에 보관하되 런타임 조회는 DB만 사용한다.

```json
[
  {
    "seed_key": "socrates_unexamined_life",
    "author": "소크라테스",
    "author_profile": "철학자",
    "message": "반성되지 않는 삶은 인간으로서 살 가치가 없다."
  }
]
```

운영 중 seed를 여러 번 실행해도 중복되지 않도록 `seed_key` 컬럼을 추가하거나,
`author + message` 해시를 계산해 upsert한다. 사용자가 추가한 명언과 seed 명언을
구분해야 한다면 `source = seed|custom` 컬럼을 추가한다.

## 8. 현장 지식 사전 확장 설계

설정의 `부가기능 > 현장 지식 사전`은 다음 서버 기능을 연결할 예정이다.

### 테이블

```text
knowledge_materials
  id, organization_id(nullable), name, category, unit, summary,
  description, cover_image_url, is_published, sort_order, timestamps

knowledge_material_images
  id, material_id, image_url, sort_order, created_at

knowledge_terms
  id, organization_id(nullable), term, definition, example,
  is_published, sort_order, timestamps

knowledge_material_term_links
  material_id, term_id

knowledge_case_studies
  id, organization_id(nullable), type(best|worst), title, trade,
  place_name, description, is_published, sort_order, timestamps

knowledge_case_images
  id, case_id, image_url, sort_order, created_at
```

이미지는 DB blob으로 저장하지 말고 기존 `/uploads/image` 업로드 결과 URL을 저장한다.
대표 이미지는 목록 최적화를 위해 `cover_image_url`에 중복 저장해도 된다.

### API

```text
GET    /extras/knowledge/summary
GET    /extras/knowledge/search?q=

GET    /extras/knowledge/materials
POST   /extras/knowledge/materials
GET    /extras/knowledge/materials/{id}
PATCH  /extras/knowledge/materials/{id}
DELETE /extras/knowledge/materials/{id}

GET    /extras/knowledge/terms
POST   /extras/knowledge/terms
GET    /extras/knowledge/terms/{id}
PATCH  /extras/knowledge/terms/{id}
DELETE /extras/knowledge/terms/{id}

GET    /extras/knowledge/cases?type=best|worst
POST   /extras/knowledge/cases
GET    /extras/knowledge/cases/{id}
PATCH  /extras/knowledge/cases/{id}
DELETE /extras/knowledge/cases/{id}
```

`organization_id IS NULL`은 플랫폼 기본 콘텐츠, 현재 조직 ID는 회사 커스텀 콘텐츠로
사용한다. 읽기 목록은 두 범위를 합치고 동일 이름 충돌 시 조직 콘텐츠를 우선한다.

## 9. 서버 완료 체크리스트

- [ ] 세 테이블 migration 및 기본 settings row 생성
- [ ] seed 명언 upsert
- [ ] CRUD 권한 검사
- [ ] 빈 문자열 trim 및 길이 검증
- [ ] soft delete 명언 자동 선정 제외
- [ ] 랜덤/순차 선정 테스트
- [ ] 최근 N일 중복 제외 테스트
- [ ] 후보 소진 시 전체 풀 fallback 테스트
- [ ] 동시 `GET /today` 요청의 UNIQUE race 테스트
- [ ] KST 23:59 → 00:00 날짜 변경 테스트
- [ ] override 생성/해제/다음 날 자동 복귀 테스트
- [ ] 원본 수정·삭제 후 snapshot 불변 테스트
- [ ] 앱 계약과 동일한 snake_case JSON 확인
