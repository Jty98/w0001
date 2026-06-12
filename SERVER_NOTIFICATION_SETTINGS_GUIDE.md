# 알림 설정 기능 서버 구현 가이드

## 개요

사용자별 알림 카테고리 ON/OFF 기능을 서버에서 지원하기 위한 가이드입니다.
업계 표준 Hybrid 방식(서버 저장 + 로컬 캐싱 + FCM Topics)을 따릅니다.

## 1. 데이터베이스 스키마

### 테이블: `user_notification_settings`

```sql
CREATE TABLE user_notification_settings (
    uid VARCHAR(50) PRIMARY KEY,
    work_assignment BOOLEAN NOT NULL DEFAULT TRUE,
    announcement_global BOOLEAN NOT NULL DEFAULT TRUE,
    announcement_place BOOLEAN NOT NULL DEFAULT TRUE,
    photo_upload BOOLEAN NOT NULL DEFAULT TRUE,
    work_instruction BOOLEAN NOT NULL DEFAULT TRUE,
    account_update BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (uid) REFERENCES users(uid) ON DELETE CASCADE
);

-- 업데이트 트리거 (MySQL)
CREATE TRIGGER update_user_notification_settings_timestamp
BEFORE UPDATE ON user_notification_settings
FOR EACH ROW
SET NEW.updated_at = CURRENT_TIMESTAMP;
```

### 알림 타입 정의

앱에서 사용하는 알림 타입과 서버 컬럼 매핑:

| 앱 타입 (key) | 서버 컬럼 | FCM 타입 prefix | 설명 |
|--------------|----------|----------------|------|
| `work_assignment` | work_assignment | `placeworkday_assignment` | 작업 배정 |
| `announcement_global` | announcement_global | `worker_announcement_global` | 전체 공지사항 |
| `announcement_place` | announcement_place | `worker_announcement_place` | 현장 공지사항 |
| `photo_upload` | photo_upload | `worker_place_photo` | 사진 업로드 요청 |
| `work_instruction` | work_instruction | `placeworkday_instruction` | 작업 지시사항 |
| `account_update` | account_update | `account_` | 계정 알림 |

## 2. REST API 엔드포인트

### 2.1 알림 설정 조회

**GET** `/users/me/notification-settings`

**인증:** Bearer Token 필요

**응답 (200 OK):**
```json
{
  "work_assignment": true,
  "announcement_global": true,
  "announcement_place": false,
  "photo_upload": true,
  "work_instruction": true,
  "account_update": true
}
```

**구현 로직:**
1. JWT에서 `uid` 추출
2. `user_notification_settings` 테이블에서 사용자 설정 조회
3. 레코드가 없으면 기본값(모두 true)으로 새 레코드 생성 후 반환

### 2.2 알림 설정 전체 업데이트

**PUT** `/users/me/notification-settings`

**인증:** Bearer Token 필요

**요청 Body:**
```json
{
  "work_assignment": true,
  "announcement_global": false,
  "announcement_place": true,
  "photo_upload": false,
  "work_instruction": true,
  "account_update": true
}
```

**응답 (200 OK):**
```json
{
  "work_assignment": true,
  "announcement_global": false,
  "announcement_place": true,
  "photo_upload": false,
  "work_instruction": true,
  "account_update": true
}
```

**구현 로직:**
1. JWT에서 `uid` 추출
2. 요청 body 검증 (모든 필드가 boolean인지 확인)
3. `user_notification_settings` 테이블 UPSERT (INSERT ON DUPLICATE KEY UPDATE)
4. 업데이트된 설정 반환

### 2.3 알림 설정 부분 업데이트

**PATCH** `/users/me/notification-settings`

**인증:** Bearer Token 필요

**요청 Body:**
```json
{
  "announcement_global": false
}
```

**응답 (204 No Content)**

**구현 로직:**
1. JWT에서 `uid` 추출
2. 요청 body에 있는 필드만 업데이트
3. 나머지 필드는 기존 값 유지

## 3. FCM 알림 발송 시 필터링

### 3.1 개인 알림 (Targeted Push)

특정 사용자에게 보내는 알림 (예: 작업 배정, 사진 업로드 요청)

**발송 전 체크:**
```python
def should_send_notification(uid: str, notification_type: str) -> bool:
    """
    알림을 발송해야 하는지 체크
    
    Args:
        uid: 사용자 ID
        notification_type: 알림 타입 (예: 'work_assignment')
    
    Returns:
        bool: 발송 여부
    """
    settings = get_user_notification_settings(uid)
    
    # account_update 타입은 항상 발송 (중요 알림)
    if notification_type == 'account_update':
        return True
    
    # 사용자 설정 확인
    return settings.get(notification_type, True)
```

**예시 - 작업 배정 알림 발송:**
```python
def notify_work_assignment(uid: str, pwd_id: int, workdate: str):
    # 1. 알림 설정 확인
    if not should_send_notification(uid, 'work_assignment'):
        logger.info(f"알림 차단됨 (사용자 설정): uid={uid}, type=work_assignment")
        return
    
    # 2. FCM 메시지 구성
    message = {
        "token": get_user_fcm_token(uid),
        "notification": {
            "title": "새로운 작업이 배정되었습니다",
            "body": f"{workdate} 작업을 확인해주세요"
        },
        "data": {
            "type": "placeworkday_assignment",
            "pwd_id": str(pwd_id),
            "workdate": workdate
        }
    }
    
    # 3. FCM 발송
    send_fcm_message(message)
```

### 3.2 전체 공지 알림 (Topic-based Push)

FCM Topics를 활용한 대량 발송

**Topics 구조:**
- `announcements_global`: 전체 공지사항
- `announcements_place`: 현장 공지사항

**발송 로직:**
```python
def notify_global_announcement(announcement_id: int, title: str, body: str):
    """전체 공지사항 알림 발송"""
    
    # Topic으로 발송 (announcement_global이 true인 사용자만 구독됨)
    message = {
        "topic": "announcements_global",
        "notification": {
            "title": title,
            "body": body
        },
        "data": {
            "type": "worker_announcement_global",
            "wa_id": str(announcement_id)
        }
    }
    
    send_fcm_message(message)
```

## 4. 사용자 가입 시 초기화

새 사용자 가입 시 알림 설정 레코드를 자동 생성합니다.

```python
def create_user(uid: str, uname: str, ...):
    # 1. users 테이블에 사용자 생성
    create_user_record(uid, uname, ...)
    
    # 2. 알림 설정 초기화 (모두 true)
    initialize_notification_settings(uid)
    
    # 3. FCM Topics 구독 (백그라운드)
    # 앱에서 자동으로 구독하므로 서버에서는 선택 사항
    # subscribe_to_default_topics(uid)
```

## 5. 로그아웃/탈퇴 시 처리

### 5.1 로그아웃
- 알림 설정은 유지 (서버 데이터 삭제 안 함)
- 앱에서 로컬 캐시만 삭제

### 5.2 회원 탈퇴
```python
def delete_user(uid: str):
    # 1. 알림 설정 삭제 (CASCADE로 자동 삭제됨)
    # 2. 기타 사용자 데이터 삭제
    delete_user_record(uid)
```

## 6. 주요 고려사항

### 6.1 기본값 처리
- 신규 사용자: 모든 알림 ON (기본값 true)
- 설정 조회 시 레코드 없음: 자동으로 기본값 레코드 생성

### 6.2 계정 알림은 항상 발송
`account_update` 타입(가입 승인, 계정 정지 등)은 사용자 설정과 무관하게 항상 발송해야 합니다.

### 6.3 성능 최적화
- 알림 설정은 Redis 등 캐시에 저장 (TTL: 1시간)
- 캐시 키: `user_notification_settings:{uid}`
- 설정 변경 시 캐시 무효화

```python
def get_user_notification_settings(uid: str) -> dict:
    # 1. 캐시 확인
    cache_key = f"user_notification_settings:{uid}"
    cached = redis.get(cache_key)
    if cached:
        return json.loads(cached)
    
    # 2. DB 조회
    settings = db.query(
        "SELECT * FROM user_notification_settings WHERE uid = %s",
        (uid,)
    )
    
    # 3. 레코드 없으면 기본값 생성
    if not settings:
        settings = create_default_settings(uid)
    
    # 4. 캐시 저장 (1시간)
    redis.setex(cache_key, 3600, json.dumps(settings))
    
    return settings
```

### 6.4 Topics 구독 관리

앱에서 자동으로 처리하지만, 서버에서도 Topics 구독 상태를 추적할 수 있습니다.

```python
def update_fcm_topic_subscription(uid: str, topic: str, subscribe: bool):
    """
    FCM Topic 구독 업데이트 (선택 사항)
    
    Firebase Admin SDK 사용 시 서버에서도 Topics 구독 관리 가능
    """
    user_tokens = get_user_fcm_tokens(uid)
    
    if subscribe:
        firebase_admin.messaging.subscribe_to_topic(user_tokens, topic)
    else:
        firebase_admin.messaging.unsubscribe_from_topic(user_tokens, topic)
```

## 7. 테스트 시나리오

### 7.1 기본 동작 테스트
1. 신규 사용자 가입 → 알림 설정 레코드 자동 생성 확인
2. GET `/users/me/notification-settings` → 기본값(모두 true) 반환 확인
3. PUT으로 설정 변경 → DB 업데이트 및 응답 확인
4. PATCH로 부분 업데이트 → 해당 필드만 변경 확인

### 7.2 알림 필터링 테스트
1. 사용자가 `work_assignment`를 OFF로 설정
2. 작업 배정 알림 발송 시도
3. `should_send_notification()` 체크로 차단 확인
4. 로그에서 차단 이유 확인

### 7.3 계정 알림 테스트
1. 사용자가 `account_update`를 OFF로 설정
2. 계정 승인 알림 발송
3. 사용자 설정과 무관하게 발송되는지 확인

### 7.4 캐시 테스트
1. 설정 조회 → 캐시 저장 확인
2. 설정 변경 → 캐시 무효화 확인
3. 다시 조회 → 새로운 값으로 캐시 재저장 확인

## 8. API 구현 예시 (Python/FastAPI)

```python
from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel
from typing import Optional

router = APIRouter()

class NotificationSettings(BaseModel):
    work_assignment: bool = True
    announcement_global: bool = True
    announcement_place: bool = True
    photo_upload: bool = True
    work_instruction: bool = True
    account_update: bool = True

class NotificationSettingsPartial(BaseModel):
    work_assignment: Optional[bool] = None
    announcement_global: Optional[bool] = None
    announcement_place: Optional[bool] = None
    photo_upload: Optional[bool] = None
    work_instruction: Optional[bool] = None
    account_update: Optional[bool] = None

@router.get("/users/me/notification-settings", response_model=NotificationSettings)
async def get_notification_settings(
    current_user: User = Depends(get_current_user)
):
    """알림 설정 조회"""
    settings = await db.fetch_one(
        "SELECT * FROM user_notification_settings WHERE uid = :uid",
        {"uid": current_user.uid}
    )
    
    if not settings:
        # 레코드 없으면 기본값으로 생성
        settings = NotificationSettings()
        await db.execute(
            """
            INSERT INTO user_notification_settings 
            (uid, work_assignment, announcement_global, announcement_place, 
             photo_upload, work_instruction, account_update)
            VALUES (:uid, :work_assignment, :announcement_global, :announcement_place,
                    :photo_upload, :work_instruction, :account_update)
            """,
            {"uid": current_user.uid, **settings.dict()}
        )
    
    return settings

@router.put("/users/me/notification-settings", response_model=NotificationSettings)
async def update_notification_settings(
    settings: NotificationSettings,
    current_user: User = Depends(get_current_user)
):
    """알림 설정 전체 업데이트"""
    await db.execute(
        """
        INSERT INTO user_notification_settings 
        (uid, work_assignment, announcement_global, announcement_place, 
         photo_upload, work_instruction, account_update)
        VALUES (:uid, :work_assignment, :announcement_global, :announcement_place,
                :photo_upload, :work_instruction, :account_update)
        ON DUPLICATE KEY UPDATE
            work_assignment = VALUES(work_assignment),
            announcement_global = VALUES(announcement_global),
            announcement_place = VALUES(announcement_place),
            photo_upload = VALUES(photo_upload),
            work_instruction = VALUES(work_instruction),
            account_update = VALUES(account_update)
        """,
        {"uid": current_user.uid, **settings.dict()}
    )
    
    # 캐시 무효화
    await invalidate_settings_cache(current_user.uid)
    
    return settings

@router.patch("/users/me/notification-settings", status_code=204)
async def partial_update_notification_settings(
    settings: NotificationSettingsPartial,
    current_user: User = Depends(get_current_user)
):
    """알림 설정 부분 업데이트"""
    update_fields = {k: v for k, v in settings.dict().items() if v is not None}
    
    if not update_fields:
        return
    
    set_clause = ", ".join([f"{k} = :{k}" for k in update_fields.keys()])
    
    await db.execute(
        f"UPDATE user_notification_settings SET {set_clause} WHERE uid = :uid",
        {"uid": current_user.uid, **update_fields}
    )
    
    # 캐시 무효화
    await invalidate_settings_cache(current_user.uid)
```

## 9. 마이그레이션 가이드

기존 사용자들을 위한 마이그레이션 스크립트:

```sql
-- 1. 테이블 생성 (위 스키마 참고)

-- 2. 기존 사용자 대상 기본 설정 생성
INSERT INTO user_notification_settings (uid)
SELECT uid FROM users
WHERE uid NOT IN (SELECT uid FROM user_notification_settings);

-- 3. 기본값 업데이트 (이미 생성된 레코드가 있다면)
UPDATE user_notification_settings
SET 
    work_assignment = COALESCE(work_assignment, TRUE),
    announcement_global = COALESCE(announcement_global, TRUE),
    announcement_place = COALESCE(announcement_place, TRUE),
    photo_upload = COALESCE(photo_upload, TRUE),
    work_instruction = COALESCE(work_instruction, TRUE),
    account_update = COALESCE(account_update, TRUE);
```

## 10. 모니터링 및 로깅

### 10.1 로그 포인트
- 알림 설정 조회/변경 시
- 알림 필터링으로 차단된 경우
- FCM 발송 실패 시

### 10.2 메트릭
- 알림 설정 변경 횟수 (타입별)
- 차단된 알림 수 (타입별)
- FCM 발송 성공/실패율

```python
# 예시: 로그 및 메트릭
import logging

logger = logging.getLogger(__name__)

def send_notification(uid: str, notification_type: str, message: dict):
    if not should_send_notification(uid, notification_type):
        logger.info(
            f"Notification blocked by user settings",
            extra={
                "uid": uid,
                "notification_type": notification_type,
                "blocked": True
            }
        )
        metrics.increment(f"notification.blocked.{notification_type}")
        return
    
    try:
        send_fcm_message(message)
        metrics.increment(f"notification.sent.{notification_type}")
    except Exception as e:
        logger.error(
            f"Failed to send notification",
            extra={
                "uid": uid,
                "notification_type": notification_type,
                "error": str(e)
            }
        )
        metrics.increment(f"notification.failed.{notification_type}")
```

---

## 요약

1. **DB 테이블**: `user_notification_settings` 생성 (6개 카테고리 boolean)
2. **API 엔드포인트**: GET, PUT, PATCH 구현
3. **알림 발송 시**: 사용자 설정 체크 후 필터링
4. **계정 알림**: 항상 발송 (사용자 설정 무시)
5. **성능**: Redis 캐싱 권장
6. **Topics**: 앱에서 자동 구독/해제, 서버는 체크만
7. **마이그레이션**: 기존 사용자 기본 설정 생성

이 가이드를 따르면 앱의 알림 설정 기능이 정상적으로 동작합니다!
