# 작업자 역할(worker_rank)과 경력(career) 수정 가이드

## 변경 사항 개요

작업자의 현장 역할과 경력 관리 방식이 다음과 같이 변경되었습니다:

### 1. 현장 역할 (worker_rank)
- **가입 시**: 작업자가 직접 선택 가능
- **이후 수정**: 관리자만 수정 가능 (작업자는 읽기 전용)

### 2. 경력 (career)
- **입력 방식**: 자유 텍스트 → **숫자(년수)로 변경**
- **저장 형식**: `"5년"` 형태로 저장 (예: 5년 경력 → `"5년"`)
- **UI**: ListWheelScrollView를 사용한 스크롤 선택 방식 (0~50년)

---

## 서버 측 수정 사항

### 1. 데이터베이스 스키마

현재 `worker_profile` 테이블 구조 확인:

```sql
-- 기존 구조 예시
CREATE TABLE worker_profile (
    uid VARCHAR(255) PRIMARY KEY,
    primary_specialty VARCHAR(255),
    specialties JSON,
    worker_rank VARCHAR(50),  -- '감리', '반장', '기공', '준기공', '조공' 또는 빈 문자열
    career TEXT,               -- 자유 텍스트 → "N년" 형태로 변경 필요
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);
```

#### 권장 변경 사항

**Option 1: 기존 컬럼 유지 (호환성 우선)**
```sql
-- career 컬럼을 TEXT로 유지하되, 애플리케이션 레벨에서 "N년" 형식으로 관리
-- 장점: 기존 데이터 마이그레이션 불필요
-- 단점: 정렬/필터링 시 문자열 파싱 필요
```

**Option 2: 새 컬럼 추가 (데이터 무결성 우선)**
```sql
-- 새로운 숫자형 컬럼 추가
ALTER TABLE worker_profile ADD COLUMN career_years INT DEFAULT 0;

-- 기존 career 컬럼의 데이터를 career_years로 마이그레이션
UPDATE worker_profile 
SET career_years = CAST(REGEXP_SUBSTR(career, '[0-9]+') AS UNSIGNED)
WHERE career REGEXP '[0-9]+';

-- 이후 career 컬럼은 deprecated 처리하거나 삭제
ALTER TABLE worker_profile DROP COLUMN career;
ALTER TABLE worker_profile RENAME COLUMN career_years TO career;

-- 최종 구조
ALTER TABLE worker_profile MODIFY COLUMN career INT DEFAULT 0;
```

### 2. API 엔드포인트 수정

#### 2.1 작업자 프로필 조회/수정 (작업자 본인)

**GET/PUT `/users/me/worker-profile`**

```json
// Response 예시
{
  "uid": "worker123",
  "primary_specialty": "목공",
  "specialties": ["목공", "타일"],
  "worker_rank": "기공",
  "career": "5년"  // 숫자 + "년" 형태로 반환
}
```

**PUT 요청 처리 시 주의사항:**

```python
# Python/FastAPI 예시
@router.put("/users/me/worker-profile")
async def update_worker_profile(
    profile: WorkerProfileUpdate,
    current_user: User = Depends(get_current_user)
):
    # 작업자는 worker_rank 수정 불가
    # 요청에 worker_rank가 포함되어 있어도 무시
    update_data = {
        "primary_specialty": profile.primary_specialty,
        "specialties": profile.specialties,
        "career": profile.career,  # "5년" 형태로 들어옴
        # worker_rank는 제외
    }
    
    # career 검증: "N년" 형식인지 확인
    if profile.career:
        match = re.match(r'^(\d+)년$', profile.career)
        if not match:
            raise HTTPException(400, "경력은 'N년' 형식이어야 합니다 (예: 5년)")
        years = int(match.group(1))
        if years < 0 or years > 50:
            raise HTTPException(400, "경력은 0~50년 사이여야 합니다")
    
    await db.update_worker_profile(current_user.uid, update_data)
    return {"message": "프로필이 업데이트되었습니다"}
```

#### 2.2 관리자의 작업자 정보 수정

**PUT `/api/humans/{hid}`** 또는 **PATCH `/api/workers/{uid}`**

```python
# 관리자는 worker_rank 수정 가능
@router.put("/api/humans/{hid}")
async def update_human(
    hid: int,
    update: HumanUpdate,
    current_user: User = Depends(require_admin)  # 관리자 권한 필요
):
    update_data = {
        "name": update.name,
        "worker_rank": update.worker_rank,  # 관리자는 수정 가능
        "daily_wage": update.daily_wage,
        # career는 작업자 본인만 수정 가능하므로 제외
    }
    
    # worker_rank 검증
    valid_ranks = ['감리', '반장', '기공', '준기공', '조공', '']
    if update.worker_rank not in valid_ranks:
        raise HTTPException(400, f"유효하지 않은 역할입니다: {update.worker_rank}")
    
    await db.update_human(hid, update_data)
    return {"message": "작업자 정보가 업데이트되었습니다"}
```

#### 2.3 작업자 가입 (signup)

**POST `/auth/signup`**

```python
@router.post("/auth/signup")
async def signup(signup_data: WorkerSignupRequest):
    # 가입 시에는 worker_rank 선택 가능
    worker_profile = {
        "uid": signup_data.uid,
        "primary_specialty": signup_data.worker_profile.primary_specialty,
        "specialties": signup_data.worker_profile.specialties,
        "worker_rank": signup_data.worker_profile.worker_rank,  # 가입 시 선택
        "career": signup_data.worker_profile.career,  # "N년" 형태
    }
    
    # 검증
    valid_ranks = ['감리', '반장', '기공', '준기공', '조공', '']
    if worker_profile["worker_rank"] not in valid_ranks:
        raise HTTPException(400, "유효하지 않은 현장 역할입니다")
    
    if worker_profile["career"]:
        match = re.match(r'^(\d+)년$', worker_profile["career"])
        if not match or not (0 <= int(match.group(1)) <= 50):
            raise HTTPException(400, "경력은 0~50년 형식이어야 합니다")
    
    await create_user_and_profile(signup_data.uid, worker_profile)
    return {"message": "가입 요청이 접수되었습니다"}
```

### 3. 권한 검증 로직

```python
def can_update_worker_rank(current_user: User, target_uid: str) -> bool:
    """
    worker_rank 수정 권한 체크
    - 관리자: 모든 작업자의 worker_rank 수정 가능
    - 작업자: 자신의 worker_rank 수정 불가
    """
    if current_user.role in ['admin', 'super_admin']:
        return True
    return False

def can_update_career(current_user: User, target_uid: str) -> bool:
    """
    career 수정 권한 체크
    - 작업자: 자신의 career만 수정 가능
    - 관리자: career 수정 불가 (작업자 본인만 수정)
    """
    return current_user.uid == target_uid
```

### 4. 데이터 마이그레이션 스크립트

기존 자유 텍스트 형식의 경력 데이터를 "N년" 형식으로 변환:

```python
import re

async def migrate_career_data():
    """
    기존 career 데이터를 "N년" 형식으로 변환
    예: "인테리어 5년" → "5년"
        "현장 경력 10년차" → "10년"
        "3" → "3년"
    """
    profiles = await db.get_all_worker_profiles()
    
    for profile in profiles:
        old_career = profile.career.strip()
        if not old_career:
            continue
        
        # 숫자 추출
        match = re.search(r'(\d+)', old_career)
        if match:
            years = int(match.group(1))
            # 0~50년 범위로 제한
            years = max(0, min(years, 50))
            new_career = f"{years}년"
            
            await db.execute(
                "UPDATE worker_profile SET career = ? WHERE uid = ?",
                [new_career, profile.uid]
            )
            print(f"Migrated: {profile.uid} - '{old_career}' → '{new_career}'")
        else:
            # 숫자가 없는 경우 0년으로 설정
            await db.execute(
                "UPDATE worker_profile SET career = '0년' WHERE uid = ?",
                [profile.uid]
            )
            print(f"No number found: {profile.uid} - '{old_career}' → '0년'")
```

### 5. API 응답 예시

#### 성공 응답
```json
{
  "success": true,
  "data": {
    "uid": "worker123",
    "worker_rank": "기공",
    "career": "5년",
    "updated_at": "2026-07-10T14:30:00Z"
  }
}
```

#### 에러 응답
```json
// 작업자가 worker_rank 수정 시도 시
{
  "error": "FORBIDDEN",
  "message": "현장 역할은 관리자만 수정할 수 있습니다"
}

// 잘못된 career 형식
{
  "error": "VALIDATION_ERROR",
  "message": "경력은 '0년' ~ '50년' 형식이어야 합니다"
}
```

---

## 클라이언트 앱 변경 사항 요약

### 1. 가입 화면 (`signup_screen.dart`)
- 현장 역할: 드롭다운으로 선택 (변경 없음)
- 경력: ListWheelScrollView로 0~50년 중 선택

### 2. 프로필 설정 화면 (`worker_profile_settings_screen.dart`)
- 현장 역할: 읽기 전용 (잠금 아이콘 표시, "관리자만 수정 가능" 안내)
- 경력: ListWheelScrollView로 수정 가능

### 3. 관리자의 작업자 관리 화면 (`human_form_fields.dart`)
- 현장 역할: FilterChip으로 선택 가능 (관리자 권한)
- 경력: 표시하지 않음 (작업자 본인만 수정)

---

## 체크리스트

- [ ] 데이터베이스 스키마 변경 (선택사항)
- [ ] 기존 career 데이터 마이그레이션
- [ ] PUT `/users/me/worker-profile` 엔드포인트 수정 (worker_rank 수정 차단)
- [ ] PUT `/api/humans/{hid}` 엔드포인트 수정 (관리자만 worker_rank 수정)
- [ ] POST `/auth/signup` 검증 로직 업데이트
- [ ] career 데이터 검증: "N년" 형식, 0~50 범위
- [ ] 권한 검증 미들웨어 적용
- [ ] API 문서 업데이트
- [ ] 단위 테스트 작성
- [ ] 통합 테스트 작성

---

## 문의사항

서버 구현 중 문의사항이 있으시면 프론트엔드 팀에 연락주세요.
