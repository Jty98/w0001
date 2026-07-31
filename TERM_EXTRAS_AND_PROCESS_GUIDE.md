# 현장 지식 사전 - 용어사전 확장 & 공정 가이드 추가

**작성일**: 2026-07-21  
**구현 완료**: ✅

---

## 🆕 추가된 기능

### 1️⃣ 용어사전 확장 (TermExtras)

현장에서 사용되는 실제 용어와 표준 명칭을 구분하여 관리합니다.

#### 데이터 구조

```dart
class TermExtras {
  /// 표준 명칭 (예: "나사")
  final String? standardName;
  
  /// 별칭들 (예: ["스크류", "나사못"])
  final List<String> aliases;
  
  /// 작업 분야 (예: "목공", "타일", "미장")
  final String? field;
  
  /// 영문 명칭 (예: "Screw")
  final String? englishName;
  
  /// 연관 용어 (예: ["드릴", "앙카", "타카"])
  final List<String> relatedTerms;
}
```

#### 사용 예시

**현장 용어 → 표준 명칭 매핑**:
```json
{
  "id": 103,
  "type": "term",
  "title": "피스",
  "content": "목재나 석고보드를 고정하는 나사",
  "categories": ["철물"],
  "tags": ["목공", "고정"],
  "term_extras": {
    "standard_name": "나사",
    "aliases": ["스크류", "나사못"],
    "field": "목공",
    "english_name": "Screw",
    "related_terms": ["드릴", "앙카", "타카"]
  }
}
```

**검색 시나리오**:
- "피스" 검색 → 해당 항목 표시
- "스크류" 검색 → aliases에서 매칭
- "나사" 검색 → standard_name에서 매칭

---

### 2️⃣ 공정 가이드 (ProcessGuide)

시공 공정별 작업 순서와 주의사항을 가이드하는 새로운 콘텐츠 타입입니다.

#### 특징

- ✅ **이미지 지원**: 공정별 단계 사진
- ✅ **카테고리**: 7개 공정 카테고리
- ✅ **동영상**: 추후 추가 예정 (video_urls 필드)
- ✅ **기존 구조 활용**: 별도 확장 필드 불필요

#### 공정 가이드 카테고리 (7개)

```dart
static const List<String> processGuides = [
  '기초/골조',    // 철근, 거푸집, 콘크리트
  '미장/방수',    // 미장, 방수, 바탕 처리
  '타일',        // 타일 시공, 줄눈
  '목공',        // 목공, 가구 제작
  '도장',        // 페인트, 도배
  '전기/설비',   // 전기, 배관, 설비
  '마감/양생',   // 마감, 청소, 양생
];
```

#### 예시 데이터

**코킹 공정 가이드**:
```json
{
  "id": 201,
  "type": "process_guide",
  "title": "코킹 작업",
  "content": "실리콘 코킹은 틈새 방수와 마감을 위한 필수 공정입니다...",
  "categories": ["마감/양생"],
  "tags": ["코킹", "실리콘", "방수"],
  "image_urls": [
    "https://example.com/caulking-step1.jpg",
    "https://example.com/caulking-step2.jpg",
    "https://example.com/caulking-step3.jpg"
  ],
  "is_active": true
}
```

**줄눈 작업 가이드**:
```json
{
  "id": 202,
  "type": "process_guide",
  "title": "타일 줄눈",
  "content": "타일 시공 후 줄눈 처리는 방수와 미관을 위해 중요합니다...\n\n## 작업 순서\n1. 타일 본드 완전 경화 확인 (24시간 이상)\n2. 줄눈 시멘트 배합\n3. 고무 흙손으로 줄눈 메우기\n4. 잉여 시멘트 제거\n5. 물청소 및 양생",
  "categories": ["타일"],
  "tags": ["줄눈", "타일", "방수"],
  "image_urls": [
    "https://example.com/grout-step1.jpg",
    "https://example.com/grout-step2.jpg"
  ],
  "is_active": true
}
```

---

## 💻 클라이언트 구현

### 1. 모델 업데이트

#### KnowledgeEntryType에 추가

```dart
enum KnowledgeEntryType {
  material('material', '자재사전', '...'),
  term('term', '용어사전', '...'),
  constructionCase('construction_case', '시공사례', '...'),
  processGuide('process_guide', '공정 가이드', '시공 공정별 작업 순서와 주의사항 가이드'),
}
```

#### KnowledgeEntry에 필드 추가

```dart
class KnowledgeEntry {
  // ... 기존 필드
  
  /// 용어사전 전용: 확장 정보
  final TermExtras? termExtras;
  
  // ...
}
```

### 2. Hub 화면

공정 가이드 카드가 추가되었습니다:

```dart
_KnowledgeFeatureCard(
  icon: Icons.construction_outlined,
  title: '공정 가이드',
  description: '시공 공정별 순서와 주의사항 단계별 가이드',
  accent: Colors.orange,
  onTap: () => _navigateToList(context, KnowledgeEntryType.processGuide),
),
```

### 3. UI/UX

- **Hub 화면**: 4개 카드 (자재사전, 용어사전, 시공사례, 공정 가이드)
- **리스트 화면**: 공정 가이드 필터링 및 검색
- **상세 화면**: 이미지 갤러리 형태로 단계별 표시
- **편집 화면**: 공정 가이드 생성/수정

---

## 🔌 서버 구현 가이드

### 1. 데이터베이스 스키마 변경

#### A. 타입 추가

```sql
-- 1. 타입 제약 조건 업데이트
ALTER TABLE field_knowledge_entries
DROP CONSTRAINT IF EXISTS valid_type;

ALTER TABLE field_knowledge_entries
ADD CONSTRAINT valid_type 
CHECK (type IN ('material', 'term', 'construction_case', 'process_guide'));
```

#### B. term_extras 필드 추가

```sql
-- 용어사전 확장 정보 (JSONB)
ALTER TABLE field_knowledge_entries
ADD COLUMN term_extras JSONB;

-- 예시 데이터:
/*
{
  "standard_name": "나사",
  "aliases": ["스크류", "나사못"],
  "field": "목공",
  "english_name": "Screw",
  "related_terms": ["드릴", "앙카", "타카"]
}
*/
```

#### C. 검색 벡터 업데이트 (aliases 포함)

```sql
CREATE OR REPLACE FUNCTION update_search_vector()
RETURNS TRIGGER AS $$
DECLARE
  category_text TEXT;
  tag_text TEXT;
  alias_text TEXT;
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
  
  -- 별칭 조회 (term_extras)
  IF NEW.term_extras IS NOT NULL THEN
    SELECT string_agg(alias_val, ' ')
    INTO alias_text
    FROM jsonb_array_elements_text(NEW.term_extras->'aliases') AS alias_val;
  END IF;
  
  -- 검색 벡터 업데이트 (제목 + 내용 + 카테고리 + 태그 + 별칭)
  NEW.search_vector := to_tsvector('korean',
    COALESCE(NEW.title, '') || ' ' ||
    COALESCE(NEW.content, '') || ' ' ||
    COALESCE(category_text, '') || ' ' ||
    COALESCE(tag_text, '') || ' ' ||
    COALESCE(alias_text, '') || ' ' ||
    COALESCE(NEW.term_extras->>'standard_name', '')
  );
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;
```

### 2. API 요청/응답 예시

#### 생성 요청

**용어사전 (확장 정보 포함)**:
```json
POST /api/extras/field-knowledge/entries

{
  "type": "term",
  "title": "피스",
  "content": "목재나 석고보드를 고정하는 나사",
  "categories": ["철물"],
  "tags": ["목공", "고정"],
  "term_extras": {
    "standard_name": "나사",
    "aliases": ["스크류", "나사못"],
    "field": "목공",
    "english_name": "Screw",
    "related_terms": ["드릴", "앙카", "타카"]
  },
  "is_active": true
}
```

**공정 가이드**:
```json
POST /api/extras/field-knowledge/entries

{
  "type": "process_guide",
  "title": "코킹 작업",
  "content": "실리콘 코킹은 틈새 방수와 마감을 위한 필수 공정입니다...",
  "categories": ["마감/양생"],
  "tags": ["코킹", "실리콘", "방수"],
  "image_urls": [
    "https://example.com/caulking-step1.jpg",
    "https://example.com/caulking-step2.jpg"
  ],
  "is_active": true
}
```

#### 조회 응답

```json
GET /api/extras/field-knowledge/entries/103

{
  "id": 103,
  "type": "term",
  "title": "피스",
  "content": "목재나 석고보드를 고정하는 나사",
  "categories": ["철물"],
  "tags": ["목공", "고정"],
  "term_extras": {
    "standard_name": "나사",
    "aliases": ["스크류", "나사못"],
    "field": "목공",
    "english_name": "Screw",
    "related_terms": ["드릴", "앙카", "타카"]
  },
  "is_active": true,
  "view_count": 42,
  "created_at": "2026-07-21T10:00:00+09:00",
  "updated_at": "2026-07-21T10:00:00+09:00"
}
```

### 3. 검색 쿼리 최적화

#### 별칭 검색

```python
@router.get("/entries")
async def get_entries(
    query: Optional[str] = None,
    # ... 다른 파라미터
):
    if query:
        # 제목, 내용, 별칭에서 검색
        q = q.filter(
            or_(
                FieldKnowledgeEntry.search_vector.match(query),
                FieldKnowledgeEntry.term_extras['aliases'].astext.contains(query),
                FieldKnowledgeEntry.term_extras['standard_name'].astext.ilike(f"%{query}%")
            )
        )
    
    # ...
```

#### 분야별 필터링

```python
@router.get("/entries")
async def get_entries(
    field: Optional[str] = None,  # 추가 파라미터
    # ...
):
    if field:
        q = q.filter(
            FieldKnowledgeEntry.term_extras['field'].astext == field
        )
    
    # ...
```

### 4. Python 모델 예시

```python
class FieldKnowledgeEntry(Base):
    __tablename__ = 'field_knowledge_entries'
    
    # ... 기존 필드
    
    term_extras = Column(JSONB)  # 추가
    construction_examples = Column(JSONB)

# Pydantic 모델
class TermExtras(BaseModel):
    standard_name: Optional[str] = None
    aliases: List[str] = []
    field: Optional[str] = None
    english_name: Optional[str] = None
    related_terms: List[str] = []

class CreateEntryRequest(BaseModel):
    type: str
    title: str
    content: str
    categories: List[str] = []
    tags: List[str] = []
    image_urls: List[str] = []
    is_active: bool = True
    term_extras: Optional[TermExtras] = None
    construction_examples: Optional[dict] = None
```

---

## 📊 마이그레이션 스크립트

```sql
-- ============================================
-- 용어사전 확장 & 공정 가이드 추가
-- ============================================

BEGIN;

-- 1. 타입 제약 조건 업데이트
ALTER TABLE field_knowledge_entries
DROP CONSTRAINT IF EXISTS valid_type;

ALTER TABLE field_knowledge_entries
ADD CONSTRAINT valid_type 
CHECK (type IN ('material', 'term', 'construction_case', 'process_guide'));

-- 2. term_extras 필드 추가
ALTER TABLE field_knowledge_entries
ADD COLUMN IF NOT EXISTS term_extras JSONB;

-- 3. 공정 가이드 카테고리 추가
INSERT INTO field_knowledge_categories (entry_id, category)
SELECT id, '기초/골조'
FROM field_knowledge_entries
WHERE type = 'process_guide' AND id NOT IN (
  SELECT entry_id FROM field_knowledge_categories
)
ON CONFLICT (entry_id, category) DO NOTHING;

-- 4. 검색 벡터 트리거 업데이트 (별칭 포함)
DROP TRIGGER IF EXISTS entries_search_vector_update ON field_knowledge_entries;
DROP FUNCTION IF EXISTS update_search_vector();

CREATE FUNCTION update_search_vector()
RETURNS TRIGGER AS $$
DECLARE
  category_text TEXT;
  tag_text TEXT;
  alias_text TEXT;
BEGIN
  -- 카테고리
  SELECT string_agg(category, ' ')
  INTO category_text
  FROM field_knowledge_categories
  WHERE entry_id = NEW.id;
  
  -- 태그
  SELECT string_agg(tag, ' ')
  INTO tag_text
  FROM field_knowledge_tags
  WHERE entry_id = NEW.id;
  
  -- 별칭 (term_extras)
  IF NEW.term_extras IS NOT NULL THEN
    SELECT string_agg(alias_val, ' ')
    INTO alias_text
    FROM jsonb_array_elements_text(NEW.term_extras->'aliases') AS alias_val;
  END IF;
  
  -- 검색 벡터
  NEW.search_vector := to_tsvector('korean',
    COALESCE(NEW.title, '') || ' ' ||
    COALESCE(NEW.content, '') || ' ' ||
    COALESCE(category_text, '') || ' ' ||
    COALESCE(tag_text, '') || ' ' ||
    COALESCE(alias_text, '') || ' ' ||
    COALESCE(NEW.term_extras->>'standard_name', '')
  );
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER entries_search_vector_update
  BEFORE INSERT OR UPDATE ON field_knowledge_entries
  FOR EACH ROW
  EXECUTE FUNCTION update_search_vector();

-- 5. 기존 항목들의 검색 벡터 재생성
UPDATE field_knowledge_entries SET updated_at = updated_at;

COMMIT;
```

---

## 🎯 사용 시나리오

### 시나리오 1: 현장 용어 검색

**작업자**: "피스가 뭐지?"

1. 검색: "피스"
2. 결과: 용어사전 항목 표시
   - **제목**: 피스
   - **표준명**: 나사
   - **별칭**: 스크류, 나사못
   - **분야**: 목공
   - **관련 용어**: 드릴, 앙카, 타카

### 시나리오 2: 공정 가이드 참고

**작업자**: "코킹 어떻게 하지?"

1. 공정 가이드 → "마감/양생" 카테고리
2. "코킹 작업" 항목 선택
3. 단계별 이미지와 설명 확인:
   - 1단계: 양생 테이프 부착
   - 2단계: 실리콘 주입
   - 3단계: 흙손으로 정리
   - 4단계: 테이프 제거

### 시나리오 3: 별칭으로 검색

**작업자**: "스크류"로 검색

→ "피스" 항목이 검색됨 (aliases에서 매칭)

---

## ✅ 체크리스트

### 클라이언트 (완료)
- [x] KnowledgeEntryType에 processGuide 추가
- [x] TermExtras 모델 생성
- [x] KnowledgeEntry에 termExtras 필드 추가
- [x] KnowledgeCategories에 processGuides 카테고리 추가
- [x] Hub 화면에 공정 가이드 카드 추가
- [x] fromJson, toWriteJson에 termExtras 처리

### 서버 (구현 필요)
- [ ] 타입 제약 조건 업데이트 (process_guide 추가)
- [ ] term_extras 필드 추가 (JSONB)
- [ ] 검색 벡터 트리거 업데이트 (aliases 포함)
- [ ] API Request/Response에 term_extras 지원
- [ ] 별칭 검색 쿼리 구현
- [ ] 분야별 필터링 구현

---

## 🚀 향후 확장

### 동영상 지원 (추후)

```sql
-- video_urls 필드 추가
ALTER TABLE field_knowledge_entries
ADD COLUMN video_urls JSONB DEFAULT '[]'::jsonb;
```

```json
{
  "type": "process_guide",
  "title": "타일 시공 전체 과정",
  "video_urls": [
    "https://youtube.com/watch?v=..."
  ],
  "image_urls": [...]
}
```

### AI 용어 추천

현장 용어 입력 시 자동으로 표준 명칭과 별칭을 제안하는 기능.

---

## 🎉 결론

### 추가된 기능
✅ **용어사전 확장**: 표준명, 별칭, 분야, 영문명 지원  
✅ **공정 가이드**: 시공 공정별 단계 가이드  
✅ **검색 개선**: 별칭 검색 지원  
✅ **카테고리**: 공정별 7개 카테고리  

### 데이터 구축 방법
1. **용어사전**: 현장 용어 + 표준 명칭 매핑
2. **공정 가이드**: 시공 단계별 사진과 설명
3. **크라우드소싱**: 작업자들이 직접 용어와 별칭 추가

이제 현장 작업자들이 실제 사용하는 용어로 검색하고, 단계별 공정 가이드를 참고할 수 있습니다! 📚✨
