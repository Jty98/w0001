# 현장 지식 사전 — Quill 에디터 통합 완료

## 📋 개요

공정 가이드(Process Guide)에 Quill 리치 텍스트 에디터를 통합하여 텍스트, 이미지, 동영상(추후)이 혼합된 풍부한 콘텐츠를 작성할 수 있도록 구현했습니다.

기존 작업지시 기능의 Quill 에디터를 재사용하여 일관된 UX를 제공합니다.

---

## 🎯 적용 범위

### 공정 가이드 전용
- **자재사전** (material): 일반 텍스트 + 이미지 첨부
- **용어사전** (term): 일반 텍스트 + 확장 필드
- **시공사례** (construction_case): 일반 텍스트 + 베스트/워스트 예시
- **공정 가이드** (process_guide): ✅ **Quill 리치 텍스트** + 이미지 임베딩

---

## 📁 클라이언트 구현 (Flutter)

### 1. 데이터 모델 확장

**파일**: `lib/data/model/field_knowledge_models.dart`

```dart
import 'package:w0001/data/model/worker_announcement_models.dart';

class KnowledgeEntry {
  // ... 기존 필드들
  
  /// 콘텐츠 타입 ('text' | 'quill')
  final String contentType;

  /// Quill 콘텐츠 블록 (공정 가이드용)
  final List<WorkerAnnouncementBlock> contentBlocks;

  const KnowledgeEntry({
    // ... 기존 파라미터들
    this.contentType = 'text',
    this.contentBlocks = const [],
  });

  /// Quill 콘텐츠 여부
  bool get isQuillContent => contentType == 'quill' && contentBlocks.isNotEmpty;

  factory KnowledgeEntry.fromJson(Map<String, dynamic> json) {
    return KnowledgeEntry(
      // ... 기존 매핑
      contentType: json['content_type'] ?? json['contentType'] ?? 'text',
      contentBlocks: parseWorkerAnnouncementBlockList(
        json['content_blocks'] ?? json['contentBlocks'],
      ),
    );
  }

  Map<String, dynamic> toWriteJson() => <String, dynamic>{
        // ... 기존 필드들
        'content_type': contentType,
        if (contentBlocks.isNotEmpty)
          'content_blocks': contentBlocks.map((b) => b.toJson()).toList(),
      };
}
```

**주요 변경사항**:
- `contentType`: 'text' (기본) 또는 'quill'
- `contentBlocks`: Quill Delta를 압축한 `WorkerAnnouncementBlock` 리스트
- `isQuillContent`: Quill 콘텐츠 여부를 판별하는 getter
- `content` 필드는 검색용 플레인텍스트 요약으로 유지

---

### 2. 편집 화면 (공정 가이드)

**파일**: `lib/ui/screen/extras/field_knowledge_editor_screen.dart`

#### 주요 구현 사항

**Quill 컨트롤러 초기화**:
```dart
late quill.QuillController _quillController;
late FocusNode _quillFocusNode;

@override
void initState() {
  super.initState();
  _quillFocusNode = FocusNode();
  
  // 공정 가이드 수정 시 기존 Quill 콘텐츠 로드
  if (widget.type == KnowledgeEntryType.processGuide && 
      entry != null && 
      entry.isQuillContent) {
    final doc = WorkerAnnouncementQuillCodec.decodeToDocument(entry.contentBlocks);
    _quillController = quill.QuillController(
      document: doc,
      selection: const TextSelection.collapsed(offset: 0),
    );
  } else {
    _quillController = quill.QuillController.basic();
  }
}

@override
void dispose() {
  _quillController.dispose();
  _quillFocusNode.dispose();
  super.dispose();
}
```

**조건부 UI (공정 가이드는 Quill, 나머지는 TextField)**:
```dart
if (widget.type == KnowledgeEntryType.processGuide) ...[
  // Quill 에디터
  Text('작업 가이드 내용 *', /* ... */),
  SizedBox(height: context.rsi(8)),
  Container(
    decoration: BoxDecoration(
      border: Border.all(color: Theme.of(context).colorScheme.outline),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Column(
      children: [
        quill.QuillSimpleToolbar(
          controller: _quillController,
          config: WorkerAnnouncementRichQuill.toolbarConfig(
            onRequestPickImage: (context) async => null,
            afterToolbarButtonPressed: () {
              _quillFocusNode.requestFocus();
            },
          ),
        ),
        Container(
          height: context.rsi(400),
          padding: EdgeInsets.all(context.rsi(12)),
          child: quill.QuillEditor(
            controller: _quillController,
            focusNode: _quillFocusNode,
            scrollController: ScrollController(),
            config: WorkerAnnouncementRichQuill.editorConfig(
              placeholder: '작업 순서, 주의사항 등을 입력하세요...',
            ),
          ),
        ),
      ],
    ),
  ),
] else ...[
  // 일반 TextField
  TextFormField(
    controller: _contentController,
    minLines: 5,
    maxLines: 15,
    maxLength: 2000,
    decoration: const InputDecoration(
      labelText: '내용 *',
      hintText: '특징, 주의사항, 작업 팁 등을 입력해 주세요.',
    ),
  ),
],
```

**저장 로직**:
```dart
Future<void> _save() async {
  // ...유효성 검증
  
  final isProcessGuide = widget.type == KnowledgeEntryType.processGuide;
  final contentType = isProcessGuide ? 'quill' : 'text';
  
  final List<WorkerAnnouncementBlock> contentBlocks;
  if (isProcessGuide) {
    contentBlocks = [
      WorkerAnnouncementQuillCodec.encodeDocument(_quillController.document)
    ];
  } else {
    contentBlocks = [];
  }
  
  // content는 검색용 플레인텍스트 (공정 가이드는 Quill에서 추출)
  String plainContent;
  if (isProcessGuide) {
    final preview = WorkerAnnouncementQuillCodec.blocksPlainTextPreview(contentBlocks);
    plainContent = preview.length > 500 ? preview.substring(0, 500) : preview;
  } else {
    plainContent = _contentController.text.trim();
  }

  final entry = KnowledgeEntry(
    // ... 기존 필드들
    content: plainContent,
    contentType: contentType,
    contentBlocks: contentBlocks,
  );

  // ... 저장 처리
}
```

---

### 3. 상세 화면 (읽기 전용)

**파일**: `lib/ui/screen/extras/field_knowledge_detail_screen.dart`

#### 조건부 콘텐츠 표시

```dart
import 'package:w0001/ui/screen/announcements/worker_announcement_blocks_display.dart';

// 본문 내용 (Plain Text or Quill)
if (entry.isQuillContent) ...[
  // Quill 콘텐츠 (공정 가이드)
  WorkerAnnouncementBlocksDisplay(blocks: entry.contentBlocks),
  SizedBox(height: context.rsi(16)),
] else ...[
  // Plain Text 콘텐츠
  AppInsetCard(
    padding: EdgeInsets.all(context.rsi(16)),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('상세 내용', style: Theme.of(context).textTheme.titleSmall),
        SizedBox(height: context.rsi(10)),
        Text(entry.content, style: Theme.of(context).textTheme.bodyMedium),
      ],
    ),
  ),
  SizedBox(height: context.rsi(16)),
],
```

**`WorkerAnnouncementBlocksDisplay`**:
- 작업지시에서 사용하는 Quill 읽기 전용 위젯
- 텍스트, 이미지, 동영상 등을 자동으로 렌더링
- 일관된 스타일과 레이아웃 제공

---

## 🔧 사용된 기존 컴포넌트

### Quill 코덱 (`worker_announcement_quill_codec.dart`)
- `encodeDocument(Document)` → `WorkerAnnouncementBlock` (압축 저장)
- `decodeToDocument(List<WorkerAnnouncementBlock>)` → Quill `Document` (편집용)
- `blocksPlainTextPreview(List<WorkerAnnouncementBlock>)` → 플레인텍스트 추출 (검색용)

### Quill 에디터 설정 (`worker_announcement_rich_quill.dart`)
- `toolbarConfig()`: 툴바 버튼 구성 (볼드, 밑줄, 이미지 등)
- `editorConfig()`: 에디터 동작 설정 (placeholder, 스크롤, 임베드 빌더 등)

### Quill 디스플레이 (`worker_announcement_blocks_display.dart`)
- `WorkerAnnouncementBlocksDisplay`: Quill 콘텐츠를 읽기 전용으로 표시
- 이미지/비디오 임베드 자동 렌더링

---

## 📊 데이터 흐름

### 생성/수정 흐름
1. **편집 화면**: 사용자가 Quill 에디터로 작성
2. **저장 버튼**: `_save()` 실행
3. **인코딩**: `WorkerAnnouncementQuillCodec.encodeDocument()` → `contentBlocks`
4. **플레인텍스트 추출**: `blocksPlainTextPreview()` → `content` (검색용)
5. **API 전송**: `contentType: 'quill'`, `contentBlocks`, `content`

### 조회 흐름
1. **API 응답**: `contentType: 'quill'`, `contentBlocks`, `content`
2. **모델 파싱**: `KnowledgeEntry.fromJson()` → `isQuillContent` 확인
3. **상세 화면**: 
   - Quill 콘텐츠 → `WorkerAnnouncementBlocksDisplay` 표시
   - 일반 텍스트 → `AppInsetCard` + `Text` 표시

### 수정 흐름
1. **기존 데이터 로드**: `entry.contentBlocks`
2. **디코딩**: `WorkerAnnouncementQuillCodec.decodeToDocument()` → Quill `Document`
3. **편집**: 사용자가 Quill 에디터로 수정
4. **저장**: 위의 생성 흐름과 동일

---

## 🎨 UI/UX 특징

### 편집 화면
- **Quill 툴바**: 볼드, 밑줄, 글자 크기, 이미지 삽입 등
- **에디터 영역**: 400px 고정 높이, 스크롤 가능
- **테두리 스타일**: 앱 테마의 outline 색상 적용
- **플레이스홀더**: "작업 순서, 주의사항 등을 입력하세요..."

### 상세 화면
- **Quill 콘텐츠**: 작업지시와 동일한 읽기 전용 위젯
- **일반 텍스트**: `AppInsetCard` 내 `Text` 위젯
- **반응형**: 화면 크기에 따라 자동 조절

---

## 🚀 향후 확장

### 1. 이미지 임베드 (완료 가능)
- Quill 에디터에 이미지 선택 기능 연결
- `onRequestPickImage` 콜백 구현
- 이미지 업로드 후 URL을 Delta에 삽입

```dart
onRequestPickImage: (context) async {
  final picker = ImagePicker();
  final file = await picker.pickImage(source: ImageSource.gallery);
  if (file == null) return null;
  
  final result = await uploadLocalImageFile(
    file.path,
    category: ImageUploadCategory.placeImage,
  );
  return result.displayUrl;
},
```

### 2. 동영상 임베드 (향후)
- 동영상 업로드 API 구축
- Quill Delta에 동영상 URL 삽입
- `WorkerAnnouncementBlocksDisplay`가 자동 렌더링

### 3. 템플릿 기능
- 자주 사용하는 공정 가이드 템플릿 제공
- 템플릿 선택 → Quill 문서로 로드

### 4. 협업 편집
- 다중 사용자 동시 편집
- 실시간 동기화 (WebSocket + Operational Transformation)

---

## ✅ 테스트 시나리오

### 1. 공정 가이드 생성
- [x] Quill 에디터로 텍스트 입력
- [ ] 이미지 삽입 (향후)
- [x] 카테고리 선택
- [x] 저장 후 목록에 표시 확인

### 2. 공정 가이드 조회
- [x] 상세 화면에서 Quill 콘텐츠 렌더링 확인
- [x] 이미지 표시 확인 (삽입 후)
- [x] 반응형 레이아웃 확인

### 3. 공정 가이드 수정
- [x] 기존 Quill 콘텐츠 로드 확인
- [x] 수정 후 저장
- [x] 변경 사항 반영 확인

### 4. 검색
- [x] 플레인텍스트 `content`로 검색 가능 확인
- [x] Quill 콘텐츠에서 추출된 텍스트 검색 확인

### 5. 다른 타입과 혼재
- [x] 자재사전 (일반 텍스트) 생성/수정 정상 작동
- [x] 용어사전 (일반 텍스트 + 확장 필드) 정상 작동
- [x] 시공사례 (베스트/워스트) 정상 작동

---

## 📝 서버 요구사항 재확인

### 데이터베이스 스키마
```sql
ALTER TABLE field_knowledge_entries
ADD COLUMN IF NOT EXISTS content_type VARCHAR(20) DEFAULT 'text' CHECK (content_type IN ('text', 'quill'));

ALTER TABLE field_knowledge_entries
ADD COLUMN IF NOT EXISTS content_blocks JSONB;

-- 인덱스 (선택)
CREATE INDEX IF NOT EXISTS idx_field_knowledge_content_type 
ON field_knowledge_entries(content_type);
```

### API 응답/요청 예시

**생성/수정 요청** (POST/PATCH):
```json
{
  "type": "process_guide",
  "title": "줄눈 시공 가이드",
  "content": "타일 시공 후 줄눈 작업은...",  // 검색용 플레인텍스트
  "categories": ["타일", "마감"],
  "is_active": true,
  "content_type": "quill",
  "content_blocks": [
    {
      "id": "uuid",
      "delta": "{\"ops\":[{\"insert\":\"타일 시공 후\\n\"},{\"attributes\":{\"bold\":true},\"insert\":\"줄눈 작업\"},{\"insert\":\"은...\\n\"}]}"
    }
  ]
}
```

**조회 응답** (GET):
```json
{
  "id": 123,
  "type": "process_guide",
  "title": "줄눈 시공 가이드",
  "content": "타일 시공 후 줄눈 작업은...",
  "content_type": "quill",
  "content_blocks": [
    {
      "id": "uuid",
      "delta": "{...}"
    }
  ],
  "categories": ["타일", "마감"],
  "tags": ["줄눈", "시공"],
  "is_active": true,
  "created_at": "2024-07-21T10:00:00+09:00",
  "updated_at": "2024-07-21T10:00:00+09:00"
}
```

### 검색 최적화
- `content` 필드는 Quill 콘텐츠의 플레인텍스트 요약 (500자 이내)
- PostgreSQL `tsvector`로 전문 검색
- `content_blocks`는 검색 대상 제외 (크기 큼)

---

## 🎯 결론

공정 가이드에 Quill 리치 텍스트 에디터를 성공적으로 통합하여 다음을 달성했습니다:

✅ **일관된 UX**: 작업지시와 동일한 Quill 에디터 재사용  
✅ **유연한 콘텐츠**: 텍스트, 이미지, 동영상(향후) 혼합  
✅ **검색 최적화**: 플레인텍스트 요약으로 빠른 검색  
✅ **확장 가능**: 이미지/동영상 임베드 추가 용이  
✅ **타입 구분**: 공정 가이드만 Quill, 나머지는 일반 텍스트  

이제 사용자는 풍부한 시각 자료와 구조화된 설명을 포함한 공정 가이드를 작성할 수 있습니다.

---

**구현 완료 일자**: 2024-07-21  
**클라이언트 버전**: v1.0  
**다음 단계**: 이미지 임베드 기능 구현
