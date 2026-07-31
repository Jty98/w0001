# 현장 지식 사전 카테고리 시스템 구현 완료

**작성일**: 2026-07-21  
**구현 완료**: ✅

## 📋 개요

현장 지식 사전에 구조화된 카테고리 시스템이 추가되었습니다. 태그와는 별개로 미리 정의된 카테고리를 통해 체계적인 분류와 검색이 가능합니다.

---

## 🎯 카테고리 vs 태그

### 카테고리 (Categories)
- ✅ **구조화된 분류**: 미리 정의된 계층적 분류 체계
- ✅ **필수 선택**: 자재사전과 용어사전에서 1개 이상 필수
- ✅ **검색 최적화**: 카테고리별 필터링 및 브라우징
- ✅ **일관성**: 표준화된 분류로 데이터 품질 유지
- 📍 **예시**: "바닥재", "목재/합판", "전기/조명"

### 태그 (Tags)
- ✅ **자유로운 키워드**: 사용자 정의 키워드
- ✅ **선택 사항**: 항목 특성을 보충하는 추가 정보
- ✅ **상세 검색**: 세부적인 검색 키워드
- ✅ **유연성**: 자유롭게 추가/수정 가능
- 📍 **예시**: "친환경", "VOC", "방수", "고급", "저가"

---

## 🗂️ 카테고리 구조

### 자재사전 카테고리 (10개)

```
1. 바닥재
   - 마루 (강화마루, 원목마루, 강마루, 온돌마루)
   - 타일 (포세린, 세라믹, 테라조)
   - 장판/시트 (롤 장판, 데코타일)
   - 특수바닥재 (에폭시, 우레탄)

2. 벽재
   - 벽지 (실크벽지, 합지, 실크벽지)
   - 페인트 (수성, 유성, 친환경)
   - 패널 (MDF, 우드패널, 아크릴)
   - 타일 (벽 타일, 모자이크)

3. 목재/합판
   - 원목 (소나무, 참나무, 티크)
   - 집성목 (핑거조인트, 엣지글루)
   - 합판 (일반합판, 시나합판, OSB)
   - MDF/PB (중밀도섬유판, 파티클보드)

4. 철물/부속
   - 경첩/손잡이
   - 레일/가이드
   - 나사/못
   - 브라켓/앵글

5. 전기/조명
   - 조명기구 (LED, 간접조명)
   - 스위치/콘센트
   - 배선기구
   - 스마트기기

6. 위생/배관
   - 수전 (세면대, 욕조, 주방)
   - 위생기구 (변기, 세면대)
   - 배수/배관
   - 욕실용품

7. 창호/문
   - 창문 (PVC, 알루미늄, 시스템창)
   - 문 (현관문, 중문, 방문)
   - 도어록/경첩
   - 창호부속

8. 단열/방수
   - 단열재 (스티로폼, 우레탄폼)
   - 방수재 (액체방수, 시트방수)
   - 차음재

9. 도료/접착
   - 페인트 (벽면용, 목재용)
   - 접착제 (순간접착, 본드)
   - 실리콘/코킹
   - 퍼티/충전제

10. 기타
    - 몰딩 (걸레받이, 천장몰딩)
    - 주방자재 (상판, 싱크대)
    - 가구부속품
```

### 용어사전 카테고리 (5개)

```
1. 시공 용어
   - 작업 공정 (골조, 미장, 도배)
   - 작업 방법 (줄눈, 평탄, 레벨)
   - 작업 도구

2. 자재 명칭
   - 규격/치수 (평, 자, 치)
   - 등급/품질
   - 제품명

3. 측정/규격
   - 단위 (평, 제곱미터, 자)
   - 두께/폭
   - 수량 표기

4. 하자/결함
   - 균열/틈새
   - 들뜸/박리
   - 변색/오염

5. 공정/절차
   - 준비 작업 (철거, 정리)
   - 본 공사
   - 마감/검수
```

### 시공사례
- 카테고리 없음 (베스트/워스트로 구분)

---

## 💻 구현 내용

### 1. 데이터 모델 (`field_knowledge_models.dart`)

#### KnowledgeEntry 모델 업데이트

```dart
class KnowledgeEntry {
  // ... 기존 필드
  
  /// 구조화된 분류 카테고리 (예: ["바닥재", "마루"])
  /// 자재와 용어에 사용, 여러 카테고리 할당 가능
  final List<String> categories;
  
  /// 검색·필터용 태그
  final List<String> tags;
  
  // ...
}
```

#### KnowledgeCategories 상수 클래스

```dart
class KnowledgeCategories {
  const KnowledgeCategories._();

  /// 자재사전 카테고리
  static const List<String> materials = [
    '바닥재', '벽재', '목재/합판', '철물/부속', '전기/조명',
    '위생/배관', '창호/문', '단열/방수', '도료/접착', '기타',
  ];

  /// 용어사전 카테고리
  static const List<String> terms = [
    '시공 용어', '자재 명칭', '측정/규격', '하자/결함', '공정/절차',
  ];

  /// 타입별 카테고리 반환
  static List<String> forType(KnowledgeEntryType type) {
    switch (type) {
      case KnowledgeEntryType.material:
        return materials;
      case KnowledgeEntryType.term:
        return terms;
      case KnowledgeEntryType.constructionCase:
        return []; // 시공사례는 카테고리 사용 안함
    }
  }
}
```

#### KnowledgeFilter 업데이트

```dart
class KnowledgeFilter {
  const KnowledgeFilter({
    this.type,
    this.categories = const [], // 추가
    this.tags = const [],
    this.isActive,
    this.query = '',
    this.sortBy = KnowledgeSortBy.recent,
  });

  final KnowledgeEntryType? type;
  final List<String> categories; // 추가
  final List<String> tags;
  // ...

  Map<String, dynamic> toQueryParams({int page = 1, int pageSize = 20}) {
    final params = <String, dynamic>{
      'page': page,
      'page_size': pageSize,
      'sort': sortBy.value,
    };
    if (type != null) params['type'] = type!.value;
    if (categories.isNotEmpty) params['categories'] = categories.join(','); // 추가
    if (tags.isNotEmpty) params['tags'] = tags.join(',');
    // ...
    return params;
  }
}
```

### 2. 편집 화면 UI (`field_knowledge_editor_screen.dart`)

#### 카테고리 선택기 위젯

```dart
class _CategorySelector extends StatelessWidget {
  const _CategorySelector({
    required this.type,
    required this.selectedCategories,
    required this.onCategoriesChanged,
  });

  final KnowledgeEntryType type;
  final List<String> selectedCategories;
  final ValueChanged<List<String>> onCategoriesChanged;

  @override
  Widget build(BuildContext context) {
    final availableCategories = KnowledgeCategories.forType(type);
    
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: availableCategories.map((category) {
        final isSelected = selectedCategories.contains(category);
        return FilterChip(
          label: Text(category),
          selected: isSelected,
          onSelected: (selected) {
            final newList = List<String>.from(selectedCategories);
            if (selected) {
              newList.add(category);
            } else {
              newList.remove(category);
            }
            onCategoriesChanged(newList);
          },
        );
      }).toList(),
    );
  }
}
```

#### 편집 화면 통합

```dart
// 카테고리 (자재사전, 용어사전만)
if (widget.type != KnowledgeEntryType.constructionCase) ...[
  Text('카테고리 *'),
  _CategorySelector(
    type: widget.type,
    selectedCategories: _categories,
    onCategoriesChanged: (categories) {
      setState(() {
        _categories.clear();
        _categories.addAll(categories);
      });
    },
  ),
],
```

#### 검증 로직

```dart
Future<void> _save() async {
  // ...
  
  // 카테고리 검증 (자재사전, 용어사전)
  if (widget.type != KnowledgeEntryType.constructionCase && 
      _categories.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('카테고리를 최소 1개 선택해주세요.')),
    );
    return;
  }
  
  // ...
}
```

---

## 🔌 서버 API 연동

### Request Body (생성/수정)

```json
{
  "type": "material",
  "title": "강화마루",
  "content": "강화마루는 고밀도 섬유판(HDF) 위에...",
  "categories": ["바닥재", "목재/합판"],
  "tags": ["친환경", "저소음", "내구성"],
  "image_urls": ["https://..."],
  "is_active": true
}
```

### Response (조회)

```json
{
  "id": 1,
  "type": "material",
  "title": "강화마루",
  "content": "...",
  "categories": ["바닥재", "목재/합판"],
  "tags": ["친환경", "저소음", "내구성"],
  "image_urls": ["https://..."],
  "thumbnail_url": "https://...",
  "is_active": true,
  "view_count": 42,
  "created_at": "2026-07-21T10:00:00+09:00",
  "updated_at": "2026-07-21T10:00:00+09:00"
}
```

### Query Parameters (검색)

```
GET /api/extras/field-knowledge/entries
  ?type=material
  &categories=바닥재,목재/합판
  &tags=친환경
  &query=마루
  &page=1
  &page_size=20
```

---

## 📊 데이터베이스 스키마 (서버 측 구현 필요)

### 테이블 구조

```sql
-- 기존 field_knowledge_entries 테이블 수정
ALTER TABLE field_knowledge_entries
ADD COLUMN categories TEXT[];  -- PostgreSQL 배열

-- 또는 정규화된 구조 (추천)
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

### 검색 쿼리 최적화

```sql
-- 카테고리 검색
SELECT e.* 
FROM field_knowledge_entries e
JOIN field_knowledge_categories c ON e.id = c.entry_id
WHERE c.category IN ('바닥재', '목재/합판')
GROUP BY e.id
HAVING COUNT(DISTINCT c.category) = 2;  -- AND 조건

-- 또는 OR 조건
WHERE c.category IN ('바닥재', '목재/합판');
```

---

## 🎯 사용자 경험

### 편집 화면
1. **카테고리 섹션 표시**
   - 자재사전 → 10개 카테고리 FilterChip 표시
   - 용어사전 → 5개 카테고리 FilterChip 표시
   - 시공사례 → 카테고리 섹션 숨김

2. **다중 선택**
   - 여러 카테고리 동시 선택 가능
   - 선택된 항목은 하이라이트 표시
   - 클릭으로 선택/해제 토글

3. **검증**
   - 자재/용어는 최소 1개 필수
   - 선택 안 했을 때 에러 메시지 표시
   - 저장 시 검증

### 검색/필터 화면 (향후 구현)
1. **카테고리별 브라우징**
   - 카테고리 목록 표시
   - 카테고리 클릭 → 해당 항목 필터링

2. **다중 카테고리 필터**
   - 여러 카테고리 동시 선택 가능
   - AND/OR 조건 지원

3. **카테고리 + 태그 조합 검색**
   - 카테고리로 큰 범위 선택
   - 태그로 세부 검색

---

## 📈 검색 성능 최적화

### 인덱스 전략

```sql
-- 카테고리 인덱스 (GIN 인덱스 - 배열 검색)
CREATE INDEX idx_fk_entries_categories 
ON field_knowledge_entries USING GIN (categories);

-- 복합 인덱스 (타입 + 카테고리)
CREATE INDEX idx_fk_entries_type_categories 
ON field_knowledge_entries (type, categories);

-- 전문 검색 인덱스 (카테고리 포함)
CREATE INDEX idx_fk_entries_search 
ON field_knowledge_entries USING GIN (
  to_tsvector('korean', 
    title || ' ' || content || ' ' || 
    array_to_string(categories, ' ') || ' ' || 
    array_to_string(tags, ' ')
  )
);
```

---

## 🔄 마이그레이션 가이드

### 기존 데이터 마이그레이션

```sql
-- 1. categories 컬럼 추가 (NULL 허용)
ALTER TABLE field_knowledge_entries
ADD COLUMN categories TEXT[] DEFAULT '{}';

-- 2. 기존 데이터에 기본 카테고리 할당
-- 자재사전 → "기타"
UPDATE field_knowledge_entries
SET categories = ARRAY['기타']
WHERE type = 'material' AND (categories IS NULL OR categories = '{}');

-- 용어사전 → "시공 용어"
UPDATE field_knowledge_entries
SET categories = ARRAY['시공 용어']
WHERE type = 'term' AND (categories IS NULL OR categories = '{}');

-- 3. NOT NULL 제약 추가
ALTER TABLE field_knowledge_entries
ALTER COLUMN categories SET NOT NULL;

-- 4. 체크 제약 추가 (빈 배열 방지)
ALTER TABLE field_knowledge_entries
ADD CONSTRAINT chk_categories_not_empty
CHECK (array_length(categories, 1) > 0 OR type = 'construction_case');
```

---

## 🎁 추가 기능 제안

### 1. 카테고리 통계 API

```
GET /api/extras/field-knowledge/categories/stats
?type=material

Response:
{
  "categories": [
    {
      "name": "바닥재",
      "count": 45,
      "last_updated": "2026-07-21T10:00:00+09:00"
    },
    {
      "name": "벽재",
      "count": 38,
      "last_updated": "2026-07-20T15:30:00+09:00"
    },
    ...
  ]
}
```

### 2. 카테고리별 인기 항목

```
GET /api/extras/field-knowledge/categories/바닥재/popular
?limit=10

Response:
{
  "category": "바닥재",
  "items": [
    { "id": 1, "title": "강화마루", "view_count": 520 },
    { "id": 2, "title": "원목마루", "view_count": 480 },
    ...
  ]
}
```

### 3. 카테고리 자동 제안 (AI)

```python
def suggest_categories(title: str, content: str) -> List[str]:
    """
    GPT-4를 사용하여 제목과 내용으로부터 
    적합한 카테고리를 자동으로 제안
    """
    prompt = f"""
    다음 자재/용어에 적합한 카테고리를 선택해주세요:
    
    제목: {title}
    내용: {content[:200]}...
    
    가능한 카테고리:
    {', '.join(KnowledgeCategories.materials)}
    
    JSON 형식으로 응답: ["카테고리1", "카테고리2"]
    """
    
    response = openai.chat.completions.create(
        model="gpt-4",
        messages=[{"role": "user", "content": prompt}]
    )
    
    return json.loads(response.choices[0].message.content)
```

---

## ✅ 체크리스트

### 클라이언트 (완료)
- [x] KnowledgeEntry 모델에 categories 필드 추가
- [x] KnowledgeCategories 상수 클래스 생성
- [x] KnowledgeFilter에 categories 필터 추가
- [x] 편집 화면에 카테고리 선택기 UI 추가
- [x] 카테고리 검증 로직 추가
- [x] toWriteJson, fromJson에 categories 처리

### 서버 (구현 필요)
- [ ] 데이터베이스 스키마 수정 (categories 필드 추가)
- [ ] 마이그레이션 스크립트 작성
- [ ] API 엔드포인트 업데이트 (categories 파라미터)
- [ ] 카테고리 검색 쿼리 최적화
- [ ] 카테고리 통계 API 추가 (선택)
- [ ] 인덱스 생성

---

## 🎉 결론

카테고리 시스템이 성공적으로 추가되었습니다!

### 주요 이점
✅ **체계적 분류**: 미리 정의된 카테고리로 데이터 품질 향상  
✅ **검색 개선**: 카테고리별 브라우징 및 필터링 가능  
✅ **확장 가능**: 새 카테고리 추가 용이  
✅ **사용자 친화**: FilterChip으로 직관적인 선택 UI  
✅ **데이터 일관성**: 표준화된 분류 체계 유지  

### 다음 단계
1. 서버 API 업데이트
2. 검색/필터 화면에 카테고리 필터 UI 추가
3. 카테고리 통계 및 분석 기능 추가
4. AI 기반 카테고리 자동 제안 기능 (선택)
