# 현장 지식 사전 이미지 업로드 구현 완료

**작성일**: 2026-07-21  
**구현 완료**: ✅

## 📋 개요

현장 지식 사전의 이미지 업로드 기능이 기존 앱의 이미지 업로드 시스템과 완전히 통합되었습니다.

## 🔧 구현 내용

### 1. API 레이어 통합

**파일**: `lib/data/datasources/remote/field_knowledge_api.dart`

```dart
/// 이미지 업로드 (기존 uploads/image API 사용)
/// 반환: 업로드된 이미지 URL
Future<String> uploadImage(String filePath) async {
  // 기존 image_attachment 시스템 사용
  final result = await uploadLocalImageFile(
    filePath,
    category: ImageUploadCategory.placeImage,
  );
  return result.displayUrl;
}
```

**주요 특징**:
- 기존 `uploadLocalImageFile` 함수 재사용
- `ImageUploadCategory.placeImage` 사용 (현장 사진과 동일한 카테고리)
- 업로드된 이미지의 `displayUrl` 반환 (CDN/썸네일 최적화 URL)

### 2. UI 레이어 - 편집 화면

**파일**: `lib/ui/screen/extras/field_knowledge_editor_screen.dart`

#### 2.1 이미지 선택 다이얼로그

사용자가 이미지 소스를 선택할 수 있는 다이얼로그:
- 📷 **갤러리**: 기기의 사진첩에서 선택
- 📸 **카메라**: 즉시 사진 촬영

```dart
final source = await showDialog<ImageSource>(
  context: context,
  builder: (ctx) => AlertDialog(
    title: const Text('이미지 선택'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ListTile(
          leading: const Icon(Icons.photo_library_outlined),
          title: const Text('갤러리'),
          onTap: () => Navigator.pop(ctx, ImageSource.gallery),
        ),
        ListTile(
          leading: const Icon(Icons.camera_alt_outlined),
          title: const Text('카메라'),
          onTap: () => Navigator.pop(ctx, ImageSource.camera),
        ),
      ],
    ),
  ),
);
```

#### 2.2 이미지 선택 및 업로드

```dart
// ImagePicker로 이미지 선택
final pickedFile = await _imagePicker.pickImage(
  source: source,
  maxWidth: 1920,      // 최대 너비 제한
  maxHeight: 1920,     // 최대 높이 제한
  imageQuality: 85,    // 품질 최적화
);

// 업로드
final result = await uploadLocalImageFile(
  pickedFile.path,
  category: ImageUploadCategory.placeImage,
);

// URL 저장
setState(() {
  _imageUrls.add(result.displayUrl);
});
```

#### 2.3 업로드 중 UI 피드백

```dart
if (_isUploadingImage)
  const Center(
    child: Padding(
      padding: EdgeInsets.all(24.0),
      child: Column(
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 8),
          Text('이미지 업로드 중...'),
        ],
      ),
    ),
  )
```

#### 2.4 에러 핸들링

```dart
try {
  // 업로드 로직
} catch (e) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('이미지 업로드 실패: $e')),
  );
}
```

## 🎯 사용자 흐름

1. **이미지 추가 버튼 클릭**
   - 자재사전, 시공사례 편집 시 이미지 섹션 표시
   - 용어사전은 이미지 미지원 (type.hasImages == false)

2. **소스 선택**
   - 갤러리 또는 카메라 선택 다이얼로그 표시

3. **이미지 선택**
   - ImagePicker가 이미지 선택
   - 자동으로 크기 조정 (최대 1920x1920, 품질 85%)

4. **업로드**
   - 로딩 인디케이터 표시
   - 서버로 multipart/form-data 업로드
   - `POST /uploads/image` 엔드포인트 사용

5. **완료**
   - 업로드된 이미지 URL 받아서 목록에 추가
   - 썸네일 형태로 미리보기 표시
   - 삭제 버튼(×) 제공

## 🔌 사용되는 API

### 기존 이미지 업로드 API

**엔드포인트**: `POST /uploads/image`

**요청**:
```
Content-Type: multipart/form-data

file: <이미지 파일>
category: place_image
```

**응답**:
```json
{
  "display_url": "https://cdn.example.com/optimized/abc123.jpg",
  "original_url": "https://storage.example.com/uploads/abc123.jpg",
  "originalname": "photo.jpg",
  "category": "place_image",
  "storage_key": "uploads/abc123.jpg"
}
```

### 현장 지식 사전 저장 시

**엔드포인트**: `POST /api/extras/field-knowledge/entries`

**요청 본문** (이미지 URL 포함):
```json
{
  "type": "material",
  "title": "친환경 페인트",
  "content": "설명...",
  "image_urls": [
    "https://cdn.example.com/optimized/abc123.jpg",
    "https://cdn.example.com/optimized/def456.jpg"
  ],
  "tags": ["페인트", "친환경"]
}
```

## 📦 의존성

### Dart 패키지

- ✅ `image_picker: ^1.1.2` (이미 설치됨)
- ✅ `dio` (AppHttpClient 내부에서 사용)
- ✅ `http_parser` (multipart 업로드용)

### 기존 유틸리티

- `uploadLocalImageFile()` - multipart 업로드 헬퍼
- `ImageUploadResult` - 업로드 응답 파싱
- `ImageUploadCategory` - 카테고리 열거형
- `prepareImageFileForUpload()` - 이미지 전처리

## 🎨 UX 개선 사항

### 이미지 품질 최적화
- 자동 리사이징 (최대 1920x1920)
- 품질 압축 (85%)
- 서버에서 추가 최적화 및 썸네일 생성

### 사용자 피드백
- ⏳ 업로드 중: 로딩 인디케이터 + "이미지 업로드 중..." 메시지
- ✅ 업로드 완료: "이미지를 추가했습니다." 스낵바
- ❌ 업로드 실패: "이미지 업로드 실패: [오류 메시지]" 스낵바

### 이미지 관리
- 수평 스크롤 갤러리
- 각 이미지마다 삭제 버튼 (우측 상단)
- 마지막에 "+" 버튼으로 추가 이미지 업로드
- 에러 시 대체 아이콘 표시

## 🔐 보안 및 검증

### 클라이언트 검증
- 이미지 파일 타입 자동 검증 (ImagePicker가 처리)
- 최대 크기 제한 (1920x1920)
- 품질 조정으로 파일 크기 제한

### 서버 검증 (예상)
- Content-Type 검증
- 파일 크기 제한
- 이미지 포맷 검증
- 바이러스 스캔 (옵션)
- 사용자 권한 검증 (Bearer 토큰)

## 📊 테스트 시나리오

### 성공 케이스
1. ✅ 갤러리에서 이미지 선택 → 업로드 → 미리보기 표시
2. ✅ 카메라로 사진 촬영 → 업로드 → 미리보기 표시
3. ✅ 여러 이미지 업로드 (순차 업로드)
4. ✅ 이미지 삭제 → 목록에서 제거
5. ✅ 이미지 포함하여 항목 저장 → 서버에 image_urls 배열 전송

### 에러 케이스
1. ❌ 네트워크 오류 → 에러 메시지 표시, 재시도 가능
2. ❌ 권한 없음 → 에러 메시지 표시
3. ❌ 파일 크기 초과 → 에러 메시지 표시
4. ❌ 잘못된 파일 형식 → ImagePicker가 필터링

### Edge 케이스
1. 이미지 선택 취소 → 아무 동작 없음
2. 업로드 중 화면 이탈 → 업로드 취소
3. 빠른 연속 업로드 → 첫 업로드 완료 후 다음 업로드

## 🚀 향후 개선 가능 사항

### 다중 선택
```dart
// 현재: 한 번에 하나씩
final pickedFile = await _imagePicker.pickImage(...);

// 개선: 여러 이미지 동시 선택
final pickedFiles = await _imagePicker.pickMultiImage(...);
```

### 이미지 편집
- 자르기 (crop)
- 회전
- 필터 적용

### 업로드 진행률
- 업로드 진행률 표시 (Dio의 onSendProgress)
- 취소 버튼 제공

### 오프라인 지원
- 이미지를 로컬에 임시 저장
- 네트워크 연결 시 자동 업로드

### 이미지 순서 변경
- 드래그 앤 드롭으로 순서 조정
- `ReorderableListView` 사용

## 🎉 결론

현장 지식 사전의 이미지 업로드 기능이 완전히 구현되었습니다!

### 구현 완료 ✅
- 기존 업로드 시스템과의 통합
- 갤러리/카메라 선택
- 이미지 최적화
- 업로드 진행 상태 표시
- 에러 핸들링
- 이미지 미리보기 및 삭제

### 사용자 경험
- 직관적인 UI/UX
- 빠른 업로드
- 명확한 피드백
- 에러 복구 가능

이제 사용자들이 자재사전과 시공사례에 풍부한 이미지를 추가할 수 있습니다! 📸✨
