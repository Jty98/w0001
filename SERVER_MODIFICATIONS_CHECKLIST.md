# 서버 수정사항 체크리스트

**작성일**: 2026-07-21  
**기준**: 클라이언트 구현 완료 버전

---

## 🔴 필수 수정사항

### 1. 데이터베이스 스키마 변경

#### A. 타입 변경 (중요!)

**현재 (잘못됨)**:
```sql
type VARCHAR(20) CHECK (type IN ('material', 'term', 'best_case', 'worst_case'))
```

**수정 후**:
```sql
type VARCHAR(20) CHECK (type IN ('material', 'term', 'construction_case'))
```

**마이그레이션 스크립트**:
```sql
-- 1. 체크 제약 제거
ALTER TABLE field_knowledge_entries
DROP CONSTRAINT valid_type;

-- 2. 기존 데이터 변환
UPDATE field_knowledge_entries
SET type = 'construction_case'
WHERE type IN ('best_case', 'worst_case');

-- 3. 새 체크 제약 추가
ALTER TABLE field_knowledge_entries
ADD CONSTRAINT valid_type 
CHECK (type IN ('material', 'term', 'construction_case'));
```

#### B. categories 필드 추가 (필수!)

```sql
-- 카테고리 컬럼 추가
ALTER TABLE field_knowledge_entries
ADD COLUMN categories TEXT[] DEFAULT '{}';

-- 또는 별도 테이블로 정규화 (추천)
CREATE TABLE field_knowledge_categories (
  id SERIAL PRIMARY KEY,
  entry_id INT NOT NULL REFERENCES field_knowledge_entries(id) ON DELETE CASCADE,
  category VARCHAR(100) NOT NULL,
  created_at TIMESTAMP DEFAULT NOW(),
  UNIQUE(entry_id, category)
);

CREATE INDEX idx_fk_categories_entry_id ON field_knowledge_categories(entry_id);
CREATE INDEX idx_fk_categories_category ON field_knowledge_categories(category);
```

**기존 데이터 마이그레이션**:
```sql
-- 자재사전 → "기타" 카테고리
INSERT INTO field_knowledge_categories (entry_id, category)
SELECT id, '기타'
FROM field_knowledge_entries
WHERE type = 'material';

-- 용어사전 → "시공 용어" 카테고리
INSERT INTO field_knowledge_categories (entry_id, category)
SELECT id, '시공 용어'
FROM field_knowledge_entries
WHERE type = 'term';
```

#### C. construction_examples 필드 추가

```sql
-- 시공사례 전용 JSONB 필드
ALTER TABLE field_knowledge_entries
ADD COLUMN construction_examples JSONB;

-- 예시 데이터 구조:
/*
{
  "best_examples": [
    {
      "image_urls": ["https://..."],
      "description": "깔끔한 줄눈 처리",
      "tips": ["레벨기 사용", "스페이서 필수"]
    }
  ],
  "worst_examples": [
    {
      "image_urls": ["https://..."],
      "description": "들뜬 타일 하자",
      "tips": ["접착제 충분히 바르기"]
    }
  ]
}
*/
```

---

### 2. API 엔드포인트 변경

#### A. Base Path 변경

**현재**: `/api/v1/field-knowledge`  
**변경**: `/api/extras/field-knowledge`

**Python/FastAPI 예시**:
```python
# 변경 전
@router.get("/api/v1/field-knowledge/entries")

# 변경 후
@router.get("/api/extras/field-knowledge/entries")
```

#### B. PUT → PATCH 변경 (부분 수정)

**현재**: `PUT /api/v1/field-knowledge/entries/:id` (전체 교체)  
**변경**: `PATCH /api/extras/field-knowledge/entries/:id` (부분 수정)

```python
# 변경 후
@router.patch("/entries/{id}")
async def update_entry(
    id: int,
    data: dict,  # 모든 필드 optional
    db: Session = Depends(get_db),
    current_user: User = Depends(require_admin)
):
    entry = db.query(FieldKnowledgeEntry).filter_by(id=id).first()
    if not entry:
        raise HTTPException(status_code=404)
    
    # 제공된 필드만 업데이트
    if 'title' in data:
        entry.title = data['title']
    if 'content' in data:
        entry.content = data['content']
    if 'is_active' in data:
        entry.is_active = data['is_active']
    if 'image_urls' in data:
        entry.image_urls = data['image_urls']
    if 'categories' in data:
        # 카테고리 업데이트
        db.query(FieldKnowledgeCategory).filter_by(entry_id=id).delete()
        for category in data['categories']:
            db.add(FieldKnowledgeCategory(entry_id=id, category=category))
    if 'tags' in data:
        # 태그 업데이트
        db.query(FieldKnowledgeTag).filter_by(entry_id=id).delete()
        for tag in data['tags']:
            db.add(FieldKnowledgeTag(entry_id=id, tag=tag))
    if 'construction_examples' in data:
        entry.construction_examples = data['construction_examples']
    
    entry.updated_at = datetime.now()
    
    # 검색 벡터 업데이트
    entry.search_vector = func.to_tsvector('korean', f"{entry.title} {entry.content}")
    
    db.commit()
    db.refresh(entry)
    
    return serialize_entry_detail(entry)
```

---

### 3. API 응답 구조 변경

#### A. 항목 생성/수정 요청

**Request Body 추가 필드**:
```typescript
{
  type: 'material' | 'term' | 'construction_case',  // 변경됨
  title: string,
  content: string,
  is_active: boolean,
  image_urls: string[],
  categories: string[],  // 추가
  tags: string[],
  construction_examples?: {  // 추가 (construction_case 타입만)
    best_examples: Array<{
      image_urls: string[];
      description: string;
      tips: string[];
    }>;
    worst_examples: Array<{
      image_urls: string[];
      description: string;
      tips: string[];
    }>;
  }
}
```

#### B. 상세 조회 응답에 related_entries 포함

**현재**: 별도 API 호출 필요  
**변경**: 상세 조회 시 자동 포함

```python
@router.get("/entries/{id}")
async def get_entry(
    id: int,
    db: Session = Depends(get_db)
):
    entry = db.query(FieldKnowledgeEntry).filter_by(id=id).first()
    if not entry:
        raise HTTPException(status_code=404)
    
    # 조회수 증가
    db.execute(
        "UPDATE field_knowledge_entries SET view_count = view_count + 1 WHERE id = :id",
        {"id": id}
    )
    db.commit()
    
    # 연관 항목 조회 (자동 포함)
    related_entries = get_related_entries_internal(db, id, limit=5)
    
    # 응답에 포함
    result = serialize_entry_detail(entry)
    result['related_entries'] = [serialize_entry(e) for e in related_entries]
    
    return result
```

**응답 구조**:
```json
{
  "id": 1,
  "type": "construction_case",
  "title": "타일 시공",
  "content": "...",
  "categories": ["바닥재"],
  "tags": ["타일", "시공"],
  "image_urls": ["https://..."],
  "thumbnail_url": "https://...",
  "construction_examples": {
    "best_examples": [...],
    "worst_examples": [...]
  },
  "related_entries": [
    {
      "id": 2,
      "type": "material",
      "title": "타일 접착제",
      "thumbnail_url": "...",
      "tags": ["타일"]
    }
  ],
  "is_active": true,
  "view_count": 43,
  "created_at": "2026-07-21T10:00:00+09:00",
  "updated_at": "2026-07-21T10:00:00+09:00"
}
```

---

### 4. 검색/필터 파라미터 추가

#### categories 파라미터 추가

```python
@router.get("/entries")
async def get_entries(
    type: Optional[str] = None,
    categories: Optional[str] = None,  # 추가
    tags: Optional[str] = None,
    query: Optional[str] = None,
    is_active: Optional[bool] = None,
    sort: str = "recent",
    page: int = 1,
    page_size: int = 20,
    db: Session = Depends(get_db)
):
    q = db.query(FieldKnowledgeEntry)
    
    # 타입 필터
    if type:
        q = q.filter(FieldKnowledgeEntry.type == type)
    
    # 카테고리 필터 (추가)
    if categories:
        category_list = [c.strip() for c in categories.split(',')]
        q = q.join(FieldKnowledgeCategory).filter(
            FieldKnowledgeCategory.category.in_(category_list)
        ).distinct()
    
    # 태그 필터
    if tags:
        tag_list = [t.strip() for t in tags.split(',')]
        q = q.join(FieldKnowledgeTag).filter(
            FieldKnowledgeTag.tag.in_(tag_list)
        ).distinct()
    
    # ... 나머지 필터 및 정렬
    
    return paginated_result
```

---

### 5. 검색 벡터 업데이트 (카테고리 포함)

```sql
-- 트리거 수정: 카테고리도 검색에 포함
CREATE OR REPLACE FUNCTION update_search_vector()
RETURNS TRIGGER AS $$
DECLARE
  category_text TEXT;
  tag_text TEXT;
BEGIN
  -- 카테고리 조회
  SELECT string_agg(category, ' ')
  INTO category_text
  FROM field_knowledge_categories
  WHERE entry_id = NEW.id;
  
  -- 태그 조회
  SELECT string_agg(tag, ' ')
  INTO tag_text
  FROM field_knowledge_tags
  WHERE entry_id = NEW.id;
  
  -- 검색 벡터 업데이트 (제목 + 내용 + 카테고리 + 태그)
  NEW.search_vector := to_tsvector('korean',
    COALESCE(NEW.title, '') || ' ' ||
    COALESCE(NEW.content, '') || ' ' ||
    COALESCE(category_text, '') || ' ' ||
    COALESCE(tag_text, '')
  );
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;
```

---

## 🟡 권장 수정사항

### 1. 카테고리 통계 API 추가

```python
@router.get("/categories/stats")
async def get_category_stats(
    type: Optional[str] = None,
    db: Session = Depends(get_db)
):
    """카테고리별 항목 수 통계"""
    q = db.query(
        FieldKnowledgeCategory.category,
        func.count(FieldKnowledgeCategory.id).label('count')
    ).join(FieldKnowledgeEntry)
    
    if type:
        q = q.filter(FieldKnowledgeEntry.type == type)
    
    results = q.filter(FieldKnowledgeEntry.is_active == True)\
               .group_by(FieldKnowledgeCategory.category)\
               .order_by(func.count(FieldKnowledgeCategory.id).desc())\
               .all()
    
    return [
        {
            "category": category,
            "count": count
        }
        for category, count in results
    ]
```

### 2. 태그 API에 limit 파라미터 추가

```python
@router.get("/tags")
async def get_tags(
    type: Optional[str] = None,
    query: Optional[str] = None,
    limit: int = 50,  # 추가 (기본값 50)
    db: Session = Depends(get_db)
):
    # ... 기존 로직
    
    results = q.group_by(FieldKnowledgeTag.tag)\
               .order_by(func.count(FieldKnowledgeTag.id).desc())\
               .limit(limit)\
               .all()
    
    # items 키로 래핑 (클라이언트 기대 구조)
    return {
        "items": [{"tag": tag, "count": count} for tag, count in results]
    }
```

### 3. 연관 항목 API에 limit 파라미터 추가

```python
@router.get("/entries/{id}/related")
async def get_related_entries(
    id: int,
    limit: int = 5,  # 기본값 5
    db: Session = Depends(get_db)
):
    related = get_related_entries_internal(db, id, limit)
    
    # items 키로 래핑 (클라이언트 기대 구조)
    return {
        "items": [serialize_entry(e) for e in related]
    }
```

---

## 📋 전체 체크리스트

### 데이터베이스
- [ ] type 제약 조건 변경 (best_case, worst_case → construction_case)
- [ ] 기존 데이터 마이그레이션 (타입 변환)
- [ ] categories 필드 추가 (배열 또는 별도 테이블)
- [ ] construction_examples 필드 추가 (JSONB)
- [ ] 기존 데이터에 기본 카테고리 할당
- [ ] 검색 벡터 트리거 업데이트 (카테고리 포함)
- [ ] 카테고리 검색 인덱스 추가

### API 엔드포인트
- [ ] Base path 변경 (/api/v1 → /api/extras)
- [ ] PUT → PATCH 변경 (부분 수정 지원)
- [ ] categories 파라미터 추가 (검색/필터)
- [ ] 상세 조회 시 related_entries 자동 포함
- [ ] Request/Response에 categories, construction_examples 필드 추가
- [ ] 태그 API limit 파라미터 추가
- [ ] 연관 항목 API limit 파라미터 추가
- [ ] 응답에 items 키 래핑 (태그, 연관 항목)

### 추가 API (선택)
- [ ] 카테고리 통계 API (`GET /categories/stats`)
- [ ] 카테고리별 인기 항목 API (`GET /categories/:category/popular`)

---

## 🚀 마이그레이션 스크립트 (전체)

```sql
-- ============================================
-- 현장 지식 사전 스키마 업데이트
-- ============================================

BEGIN;

-- 1. 타입 제약 조건 변경
ALTER TABLE field_knowledge_entries
DROP CONSTRAINT IF EXISTS valid_type;

UPDATE field_knowledge_entries
SET type = 'construction_case'
WHERE type IN ('best_case', 'worst_case');

ALTER TABLE field_knowledge_entries
ADD CONSTRAINT valid_type 
CHECK (type IN ('material', 'term', 'construction_case'));

-- 2. 카테고리 테이블 생성
CREATE TABLE IF NOT EXISTS field_knowledge_categories (
  id SERIAL PRIMARY KEY,
  entry_id INT NOT NULL REFERENCES field_knowledge_entries(id) ON DELETE CASCADE,
  category VARCHAR(100) NOT NULL,
  created_at TIMESTAMP DEFAULT NOW(),
  UNIQUE(entry_id, category)
);

CREATE INDEX IF NOT EXISTS idx_fk_categories_entry_id 
ON field_knowledge_categories(entry_id);

CREATE INDEX IF NOT EXISTS idx_fk_categories_category 
ON field_knowledge_categories(category);

-- 3. 기존 데이터에 기본 카테고리 할당
INSERT INTO field_knowledge_categories (entry_id, category)
SELECT id, '기타'
FROM field_knowledge_entries
WHERE type = 'material'
ON CONFLICT (entry_id, category) DO NOTHING;

INSERT INTO field_knowledge_categories (entry_id, category)
SELECT id, '시공 용어'
FROM field_knowledge_entries
WHERE type = 'term'
ON CONFLICT (entry_id, category) DO NOTHING;

-- 4. construction_examples 필드 추가
ALTER TABLE field_knowledge_entries
ADD COLUMN IF NOT EXISTS construction_examples JSONB;

-- 5. 검색 벡터 트리거 업데이트
DROP TRIGGER IF EXISTS entries_search_vector_update ON field_knowledge_entries;
DROP FUNCTION IF EXISTS update_search_vector();

CREATE FUNCTION update_search_vector()
RETURNS TRIGGER AS $$
DECLARE
  category_text TEXT;
  tag_text TEXT;
BEGIN
  -- 카테고리 조회
  SELECT string_agg(category, ' ')
  INTO category_text
  FROM field_knowledge_categories
  WHERE entry_id = NEW.id;
  
  -- 태그 조회
  SELECT string_agg(tag, ' ')
  INTO tag_text
  FROM field_knowledge_tags
  WHERE entry_id = NEW.id;
  
  -- 검색 벡터 업데이트
  NEW.search_vector := to_tsvector('korean',
    COALESCE(NEW.title, '') || ' ' ||
    COALESCE(NEW.content, '') || ' ' ||
    COALESCE(category_text, '') || ' ' ||
    COALESCE(tag_text, '')
  );
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER entries_search_vector_update
  BEFORE INSERT OR UPDATE ON field_knowledge_entries
  FOR EACH ROW
  EXECUTE FUNCTION update_search_vector();

-- 6. 기존 항목들의 검색 벡터 재생성
UPDATE field_knowledge_entries SET updated_at = updated_at;

COMMIT;
```

---

## 📝 Python 모델 예시

```python
from sqlalchemy import Column, Integer, String, Boolean, Text, DateTime, ForeignKey, ARRAY
from sqlalchemy.dialects.postgresql import JSONB, TSVECTOR
from sqlalchemy.orm import relationship

class FieldKnowledgeEntry(Base):
    __tablename__ = 'field_knowledge_entries'
    
    id = Column(Integer, primary_key=True)
    type = Column(String(20), nullable=False)
    title = Column(String(200), nullable=False)
    content = Column(Text, nullable=False)
    is_active = Column(Boolean, default=True)
    
    image_urls = Column(JSONB, default=[])
    thumbnail_url = Column(String(500))
    construction_examples = Column(JSONB)  # 추가
    
    search_vector = Column(TSVECTOR)
    view_count = Column(Integer, default=0)
    created_at = Column(DateTime, default=datetime.now)
    updated_at = Column(DateTime, default=datetime.now, onupdate=datetime.now)
    
    # 관계
    categories = relationship('FieldKnowledgeCategory', back_populates='entry')
    tags = relationship('FieldKnowledgeTag', back_populates='entry')

class FieldKnowledgeCategory(Base):
    __tablename__ = 'field_knowledge_categories'
    
    id = Column(Integer, primary_key=True)
    entry_id = Column(Integer, ForeignKey('field_knowledge_entries.id', ondelete='CASCADE'))
    category = Column(String(100), nullable=False)
    created_at = Column(DateTime, default=datetime.now)
    
    entry = relationship('FieldKnowledgeEntry', back_populates='categories')

class FieldKnowledgeTag(Base):
    __tablename__ = 'field_knowledge_tags'
    
    id = Column(Integer, primary_key=True)
    entry_id = Column(Integer, ForeignKey('field_knowledge_entries.id', ondelete='CASCADE'))
    tag = Column(String(50), nullable=False)
    
    entry = relationship('FieldKnowledgeEntry', back_populates='tags')
```

---

## 🎯 우선순위 요약

### 즉시 (P0)
1. ✅ 타입 변경 (best_case, worst_case → construction_case)
2. ✅ categories 필드 추가
3. ✅ Base path 변경 (/api/extras)
4. ✅ PATCH 엔드포인트 구현

### 중요 (P1)
5. ✅ construction_examples 필드 추가
6. ✅ 상세 조회 시 related_entries 포함
7. ✅ categories 파라미터 지원 (검색/필터)

### 권장 (P2)
8. ⚡ 카테고리 통계 API
9. ⚡ 응답에 items 키 래핑

---

**모든 변경사항을 반영하면 클라이언트와 완벽하게 호환됩니다! 🎉**

