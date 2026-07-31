# 현장 지식 사전 서버 구현 가이드

## 📋 개요

현장 지식 사전은 **자재사전**, **용어사전**, **베스트 시공사례**, **워스트 사례** 4가지 유형의 콘텐츠를 관리하는 기능입니다. 이미지가 포함된 대용량 콘텐츠를 효율적으로 다루기 위한 서버 설계 가이드입니다.

## 🗄️ 데이터베이스 스키마

### 1. `field_knowledge_entries` 테이블

```sql
CREATE TABLE field_knowledge_entries (
  id SERIAL PRIMARY KEY,
  type VARCHAR(20) NOT NULL, -- 'material', 'term', 'best_case', 'worst_case'
  title VARCHAR(200) NOT NULL,
  content TEXT NOT NULL,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  
  -- 이미지 (PostgreSQL의 경우 JSON 배열)
  image_urls JSONB DEFAULT '[]'::jsonb,
  thumbnail_url VARCHAR(500),
  
  -- 검색 최적화
  search_vector tsvector,
  
  -- 메타데이터
  view_count INTEGER NOT NULL DEFAULT 0,
  created_at TIMESTAMP NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMP NOT NULL DEFAULT NOW(),
  
  -- 인덱스
  CONSTRAINT valid_type CHECK (type IN ('material', 'term', 'best_case', 'worst_case'))
);

-- 타입별 필터링 최적화
CREATE INDEX idx_entries_type ON field_knowledge_entries(type, is_active);

-- 전문 검색 인덱스 (PostgreSQL)
CREATE INDEX idx_entries_search ON field_knowledge_entries USING GIN(search_vector);

-- 최신순 정렬 최적화
CREATE INDEX idx_entries_created ON field_knowledge_entries(created_at DESC);

-- 인기순 정렬 최적화
CREATE INDEX idx_entries_popular ON field_knowledge_entries(view_count DESC);
```

### 2. `field_knowledge_tags` 테이블

```sql
CREATE TABLE field_knowledge_tags (
  id SERIAL PRIMARY KEY,
  entry_id INTEGER NOT NULL REFERENCES field_knowledge_entries(id) ON DELETE CASCADE,
  tag VARCHAR(50) NOT NULL,
  
  CONSTRAINT unique_entry_tag UNIQUE(entry_id, tag)
);

-- 태그 검색 최적화
CREATE INDEX idx_tags_tag ON field_knowledge_tags(tag);
CREATE INDEX idx_tags_entry ON field_knowledge_tags(entry_id);
```

### 3. `field_knowledge_relations` 테이블 (연관 항목)

```sql
CREATE TABLE field_knowledge_relations (
  id SERIAL PRIMARY KEY,
  source_id INTEGER NOT NULL REFERENCES field_knowledge_entries(id) ON DELETE CASCADE,
  target_id INTEGER NOT NULL REFERENCES field_knowledge_entries(id) ON DELETE CASCADE,
  created_at TIMESTAMP NOT NULL DEFAULT NOW(),
  
  CONSTRAINT no_self_relation CHECK (source_id != target_id),
  CONSTRAINT unique_relation UNIQUE(source_id, target_id)
);

CREATE INDEX idx_relations_source ON field_knowledge_relations(source_id);
CREATE INDEX idx_relations_target ON field_knowledge_relations(target_id);
```

## 🔌 API 엔드포인트

### 1. 항목 리스트 조회 (페이지네이션)

**GET** `/api/v1/field-knowledge/entries`

**Query Parameters:**
```typescript
{
  type?: 'material' | 'term' | 'best_case' | 'worst_case',
  query?: string,          // 검색 키워드
  tags?: string,           // 쉼표로 구분된 태그
  is_active?: boolean,
  initial?: string,        // 용어사전 초성 (ㄱ~ㅎ)
  sort?: 'recent' | 'popular' | 'title',
  page?: number,           // 기본값: 1
  page_size?: number,      // 기본값: 20
}
```

**Response:**
```typescript
{
  items: KnowledgeEntry[],
  page: number,
  page_size: number,
  total: number
}
```

**최적화 전략:**

```python
# 예시 (Python/FastAPI)
@router.get("/entries")
async def get_entries(
    type: Optional[str] = None,
    query: Optional[str] = None,
    tags: Optional[str] = None,
    is_active: Optional[bool] = None,
    sort: str = "recent",
    page: int = 1,
    page_size: int = 20,
    db: Session = Depends(get_db)
):
    # 기본 쿼리
    q = db.query(FieldKnowledgeEntry)
    
    # 필터 적용
    if type:
        q = q.filter(FieldKnowledgeEntry.type == type)
    if is_active is not None:
        q = q.filter(FieldKnowledgeEntry.is_active == is_active)
    
    # 전문 검색 (PostgreSQL)
    if query:
        q = q.filter(
            FieldKnowledgeEntry.search_vector.match(query)
        )
    
    # 태그 필터
    if tags:
        tag_list = [t.strip() for t in tags.split(',')]
        q = q.join(FieldKnowledgeTag).filter(
            FieldKnowledgeTag.tag.in_(tag_list)
        ).distinct()
    
    # 정렬
    if sort == "recent":
        q = q.order_by(FieldKnowledgeEntry.created_at.desc())
    elif sort == "popular":
        q = q.order_by(FieldKnowledgeEntry.view_count.desc())
    elif sort == "title":
        q = q.order_by(FieldKnowledgeEntry.title)
    
    # 총 개수 (최적화: 캐싱 권장)
    total = q.count()
    
    # 페이지네이션
    offset = (page - 1) * page_size
    items = q.offset(offset).limit(page_size).all()
    
    return {
        "items": [serialize_entry(e) for e in items],
        "page": page,
        "page_size": page_size,
        "total": total
    }
```

#### 용어사전 정렬·초성 필터

앱 용어사전은 아래를 사용합니다.

| 기능 | 쿼리 | 담당 |
|------|------|------|
| 가나다순 | `sort=title` | 서버 (ICU `ko-KR-x-icu` 권장) |
| 초성 칩 | `initial=ㄱ` … `ㅎ` | 서버 |
| 페이징 | `page`, `page_size` | 서버 |
| 검색창 복합 초성(예: `ㄱㅅ`) | — | 클라이언트 로컬 |

```bash
GET /extras/field-knowledge/entries?type=term&sort=title&page=1&page_size=20
GET /extras/field-knowledge/entries?type=term&sort=title&initial=ㄱ&page=1&page_size=20
GET /extras/field-knowledge/entries?type=term&sort=title&initial=ㅅ&query=목&page=1
```

서버 구현 시 한글 정렬:

```sql
ORDER BY title COLLATE "ko-KR-x-icu"
```

초성 필터는 title 범위(`가`~`나` 등)로 처리합니다. 클라이언트는 초성 칩 선택 시 `initial`을 넣어 다시 1페이지부터 조회합니다.

### 2. 단일 항목 조회 (조회수 증가)

**GET** `/api/v1/field-knowledge/entries/:id`

**Response:** `KnowledgeEntry`

```python
@router.get("/entries/{id}")
async def get_entry(
    id: int,
    db: Session = Depends(get_db)
):
    entry = db.query(FieldKnowledgeEntry).filter_by(id=id).first()
    if not entry:
        raise HTTPException(status_code=404, detail="Not found")
    
    # 조회수 증가 (비동기 처리 권장)
    db.execute(
        "UPDATE field_knowledge_entries SET view_count = view_count + 1 WHERE id = :id",
        {"id": id}
    )
    db.commit()
    
    return serialize_entry_detail(entry)
```

### 3. 항목 생성

**POST** `/api/v1/field-knowledge/entries`

**Body:**
```typescript
{
  type: 'material' | 'term' | 'best_case' | 'worst_case',
  title: string,
  content: string,
  is_active: boolean,
  image_urls: string[],
  tags: string[]
}
```

**Response:** `KnowledgeEntry`

```python
@router.post("/entries")
async def create_entry(
    data: CreateEntryRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    # 권한 체크
    if not current_user.can_manage_extras:
        raise HTTPException(status_code=403, detail="Permission denied")
    
    # 항목 생성
    entry = FieldKnowledgeEntry(
        type=data.type,
        title=data.title,
        content=data.content,
        is_active=data.is_active,
        image_urls=data.image_urls,
    )
    
    # 썸네일 자동 생성 (이미지가 있는 경우)
    if entry.image_urls:
        entry.thumbnail_url = generate_thumbnail(entry.image_urls[0])
    
    # 검색 벡터 생성 (PostgreSQL)
    entry.search_vector = func.to_tsvector('korean', f"{data.title} {data.content}")
    
    db.add(entry)
    db.flush()
    
    # 태그 추가
    for tag in data.tags:
        db.add(FieldKnowledgeTag(entry_id=entry.id, tag=tag))
    
    db.commit()
    db.refresh(entry)
    
    return serialize_entry_detail(entry)
```

### 4. 항목 수정

**PUT** `/api/v1/field-knowledge/entries/:id`

### 5. 항목 삭제

**DELETE** `/api/v1/field-knowledge/entries/:id`

### 6. 태그 목록 조회

**GET** `/api/v1/field-knowledge/tags`

**Query Parameters:**
```typescript
{
  type?: string,
  query?: string  // 태그 검색
}
```

**Response:**
```typescript
Array<{
  tag: string,
  count: number
}>
```

```python
@router.get("/tags")
async def get_tags(
    type: Optional[str] = None,
    query: Optional[str] = None,
    db: Session = Depends(get_db)
):
    q = db.query(
        FieldKnowledgeTag.tag,
        func.count(FieldKnowledgeTag.id).label('count')
    ).join(FieldKnowledgeEntry)
    
    if type:
        q = q.filter(FieldKnowledgeEntry.type == type)
    if query:
        q = q.filter(FieldKnowledgeTag.tag.ilike(f"%{query}%"))
    
    results = q.group_by(FieldKnowledgeTag.tag)\
               .order_by(func.count(FieldKnowledgeTag.id).desc())\
               .limit(50)\
               .all()
    
    return [{"tag": tag, "count": count} for tag, count in results]
```

### 7. 연관 항목 조회

**GET** `/api/v1/field-knowledge/entries/:id/related`

**Query Parameters:**
```typescript
{
  limit?: number  // 기본값: 5
}
```

**Response:** `KnowledgeEntry[]`

```python
@router.get("/entries/{id}/related")
async def get_related_entries(
    id: int,
    limit: int = 5,
    db: Session = Depends(get_db)
):
    # 1. 명시적 연결
    explicit = db.query(FieldKnowledgeEntry)\
        .join(FieldKnowledgeRelation, 
              FieldKnowledgeRelation.target_id == FieldKnowledgeEntry.id)\
        .filter(FieldKnowledgeRelation.source_id == id)\
        .limit(limit)\
        .all()
    
    if len(explicit) >= limit:
        return [serialize_entry(e) for e in explicit]
    
    # 2. 태그 기반 추천 (명시적 연결이 부족할 때)
    current_entry = db.query(FieldKnowledgeEntry).filter_by(id=id).first()
    if not current_entry:
        return []
    
    current_tags = [t.tag for t in current_entry.tags]
    if not current_tags:
        return [serialize_entry(e) for e in explicit]
    
    tag_based = db.query(FieldKnowledgeEntry)\
        .join(FieldKnowledgeTag)\
        .filter(
            FieldKnowledgeTag.tag.in_(current_tags),
            FieldKnowledgeEntry.id != id,
            FieldKnowledgeEntry.is_active == True
        )\
        .distinct()\
        .limit(limit - len(explicit))\
        .all()
    
    all_related = explicit + tag_based
    return [serialize_entry(e) for e in all_related[:limit]]
```

## 🚀 최적화 전략

### 1. 이미지 최적화

#### A. 썸네일 자동 생성

```python
from PIL import Image
import io

def generate_thumbnail(image_url: str, size=(400, 400)) -> str:
    """
    원본 이미지에서 썸네일 생성
    - 리스트 뷰에서는 썸네일만 로드 (용량 절감)
    - CDN에 업로드하여 원본과 별도 관리
    """
    # 이미지 다운로드
    response = requests.get(image_url)
    img = Image.open(io.BytesIO(response.content))
    
    # 리사이즈 (aspect ratio 유지)
    img.thumbnail(size, Image.Resampling.LANCZOS)
    
    # CDN 업로드
    thumbnail_buffer = io.BytesIO()
    img.save(thumbnail_buffer, format='JPEG', quality=85, optimize=True)
    thumbnail_url = upload_to_cdn(
        thumbnail_buffer.getvalue(),
        f"thumbnails/{uuid.uuid4()}.jpg"
    )
    
    return thumbnail_url
```

#### B. WebP 변환

```python
# 업로드 시 WebP로 자동 변환 (파일 크기 30-50% 감소)
def convert_to_webp(image_url: str) -> str:
    response = requests.get(image_url)
    img = Image.open(io.BytesIO(response.content))
    
    webp_buffer = io.BytesIO()
    img.save(webp_buffer, format='WEBP', quality=85)
    
    webp_url = upload_to_cdn(
        webp_buffer.getvalue(),
        f"images/{uuid.uuid4()}.webp"
    )
    
    return webp_url
```

### 2. 캐싱 전략

#### A. Redis 캐싱

```python
import redis
import json

redis_client = redis.Redis(host='localhost', port=6379, db=0)

@router.get("/entries")
async def get_entries(...):
    # 캐시 키 생성
    cache_key = f"knowledge:list:{type}:{query}:{page}:{page_size}"
    
    # 캐시 확인
    cached = redis_client.get(cache_key)
    if cached:
        return json.loads(cached)
    
    # DB 조회
    result = {...}  # DB 쿼리
    
    # 캐시 저장 (5분)
    redis_client.setex(cache_key, 300, json.dumps(result))
    
    return result
```

#### B. CDN 캐싱

```nginx
# Nginx 설정
location /api/v1/field-knowledge/entries {
    # GET 요청만 캐싱
    proxy_cache knowledge_cache;
    proxy_cache_valid 200 5m;
    proxy_cache_key "$scheme$request_method$host$request_uri";
    proxy_cache_methods GET HEAD;
    
    proxy_pass http://backend;
}
```

### 3. 데이터베이스 최적화

#### A. 전문 검색 (PostgreSQL)

```sql
-- 검색 벡터 자동 업데이트 트리거
CREATE OR REPLACE FUNCTION update_search_vector()
RETURNS TRIGGER AS $$
BEGIN
  NEW.search_vector := 
    to_tsvector('korean', COALESCE(NEW.title, '') || ' ' || COALESCE(NEW.content, ''));
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER entries_search_vector_update
  BEFORE INSERT OR UPDATE ON field_knowledge_entries
  FOR EACH ROW
  EXECUTE FUNCTION update_search_vector();
```

#### B. 읽기 전용 복제본

```python
# 조회용 쿼리는 읽기 전용 복제본 사용
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

# 마스터 (쓰기)
master_engine = create_engine("postgresql://user:pass@master-db:5432/db")

# 복제본 (읽기)
replica_engine = create_engine("postgresql://user:pass@replica-db:5432/db")

def get_read_db():
    SessionLocal = sessionmaker(bind=replica_engine)
    return SessionLocal()

def get_write_db():
    SessionLocal = sessionmaker(bind=master_engine)
    return SessionLocal()
```

### 4. 페이지네이션 최적화

#### Cursor-based Pagination (큰 데이터셋에 적합)

```python
@router.get("/entries")
async def get_entries(
    cursor: Optional[int] = None,  # 마지막 항목 ID
    page_size: int = 20,
    db: Session = Depends(get_db)
):
    q = db.query(FieldKnowledgeEntry)
    
    if cursor:
        q = q.filter(FieldKnowledgeEntry.id < cursor)
    
    items = q.order_by(FieldKnowledgeEntry.id.desc())\
             .limit(page_size + 1)\
             .all()
    
    has_next = len(items) > page_size
    items = items[:page_size]
    
    next_cursor = items[-1].id if has_next and items else None
    
    return {
        "items": [serialize_entry(e) for e in items],
        "next_cursor": next_cursor,
        "has_next": has_next
    }
```

## 📊 모니터링 & 분석

### 1. 로깅

```python
import logging

logger = logging.getLogger(__name__)

@router.get("/entries")
async def get_entries(...):
    start_time = time.time()
    
    try:
        result = {...}
        
        elapsed = time.time() - start_time
        logger.info(
            f"GET /entries - type={type} page={page} duration={elapsed:.3f}s"
        )
        
        return result
    except Exception as e:
        logger.error(f"GET /entries failed: {e}", exc_info=True)
        raise
```

### 2. 성능 메트릭

```python
from prometheus_client import Counter, Histogram

# 요청 카운터
request_counter = Counter(
    'knowledge_requests_total',
    'Total knowledge API requests',
    ['endpoint', 'method', 'status']
)

# 응답 시간 히스토그램
response_time = Histogram(
    'knowledge_response_seconds',
    'Response time in seconds',
    ['endpoint']
)

@router.get("/entries")
@response_time.labels(endpoint='/entries').time()
async def get_entries(...):
    result = {...}
    request_counter.labels(endpoint='/entries', method='GET', status=200).inc()
    return result
```

## 🔐 보안 고려사항

1. **권한 체크**: 생성/수정/삭제는 `canManageExtras` 권한 필요
2. **입력 검증**: XSS 방지, SQL Injection 방지
3. **이미지 업로드 제한**: 파일 크기, 형식, 개수 제한
4. **Rate Limiting**: API 호출 빈도 제한

```python
from slowapi import Limiter

limiter = Limiter(key_func=get_remote_address)

@router.post("/entries")
@limiter.limit("10/minute")  # 분당 10회 제한
async def create_entry(...):
    ...
```

## 📈 확장성 고려사항

1. **샤딩**: 타입별로 테이블 분리 (material, term, cases)
2. **Elasticsearch**: 대용량 검색 최적화
3. **Object Storage**: S3/GCS를 이용한 이미지 저장
4. **Message Queue**: 썸네일 생성 비동기 처리 (Celery, RabbitMQ)

---

## 🚦 구현 순서 (권장)

1. ✅ 기본 CRUD API (이미지 없이 텍스트만)
2. ✅ 페이지네이션 & 검색
3. ✅ 태그 기능
4. ✅ 이미지 업로드 & 썸네일
5. ✅ 연관 항목
6. ⚡ 캐싱 & 최적화
7. 📊 모니터링 & 로깅

이 가이드를 참고하여 서버를 구현하면, 수천 개의 항목과 이미지를 효율적으로 다룰 수 있습니다! 🎉
