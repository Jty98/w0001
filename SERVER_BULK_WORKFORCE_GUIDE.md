# 🚀 기간별 일괄 인력투입 서버 구현 가이드

## 📌 개요

여러 날짜에 대한 인력투입을 한 번의 API 호출로 처리하는 벌크(Bulk) 엔드포인트 구현 가이드입니다.

---

## 🎯 새로운 API 엔드포인트

### `POST /api/places/{pid}/workforce/bulk-assign`

현장의 여러 날짜에 대해 인력을 일괄 투입합니다.

#### 요청

```http
POST /api/places/116/workforce/bulk-assign
Authorization: Bearer {access_token}
Content-Type: application/json
```

```json
{
  "start_date": "2026-07-01",
  "end_date": "2026-07-05",
  "assignments": [
    {
      "hid": 14,
      "workrole": "타일공사",
      "daily_wage": 200000,
      "workerRank": "기공"
    },
    {
      "hid": 25,
      "workrole": "타일공사",
      "daily_wage": 150000,
      "workerRank": "조공"
    }
  ],
  "site_instruction_blocks": null,
  "process_instruction_blocks": {
    "타일공사": [
      {
        "type": "text",
        "content": "타일 시공 순서: 벽 → 바닥"
      }
    ]
  }
}
```

#### 요청 스키마

```python
from pydantic import BaseModel
from typing import List, Optional, Dict
from datetime import date

class WorkforceAssignmentItem(BaseModel):
    hid: int
    workrole: str
    daily_wage: int
    workerRank: Optional[str] = None

class BulkWorkforceAssignmentRequest(BaseModel):
    start_date: date  # ISO 8601 format: "2026-07-01"
    end_date: date    # ISO 8601 format: "2026-07-05"
    assignments: List[WorkforceAssignmentItem]
    site_instruction_blocks: Optional[List[dict]] = None
    process_instruction_blocks: Optional[Dict[str, List[dict]]] = None
```

#### 응답

```json
{
  "created_count": 10,
  "date_range": {
    "start": "2026-07-01",
    "end": "2026-07-05",
    "days": 5
  },
  "assignments_per_day": 2,
  "work_days": [
    {
      "pwdid": 1001,
      "pid": 116,
      "hid": 14,
      "workdate": "2026-07-01",
      "workrole": "타일공사",
      "dailywage": 200000
    },
    {
      "pwdid": 1002,
      "pid": 116,
      "hid": 25,
      "workdate": "2026-07-01",
      "workrole": "타일공사",
      "dailywage": 150000
    },
    // ... 나머지 8개
  ]
}
```

---

## 🔧 서버 구현

### 1. 라우트 추가

```python
# app/routes/place_workforce_routes.py

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from datetime import date, timedelta
from typing import List, Optional, Dict

from app.database import get_db
from app.models import PlaceWorkDay, Human, Place
from app.schemas import BulkWorkforceAssignmentRequest, BulkWorkforceAssignmentResponse
from app.services import placeworkerrecent_service, place_work_day_instructions_service
from app.controller.auth_controller import get_current_user

router = APIRouter()

@router.post(
    "/{pid}/workforce/bulk-assign",
    response_model=BulkWorkforceAssignmentResponse,
    summary="기간별 일괄 인력 투입",
    description="""
    여러 날짜에 대해 인력을 한 번에 투입합니다.
    
    - start_date와 end_date 사이의 모든 날짜에 대해 PlaceWorkDay 생성
    - 각 날짜마다 assignments 목록의 모든 인력 배치
    - 작업지시(instruction)도 함께 저장 가능
    - PlaceWorkerRecent 자동 업데이트
    """,
)
def bulk_assign_workforce(
    pid: int,
    request: BulkWorkforceAssignmentRequest,
    db: Session = Depends(get_db),
    current_user = Depends(get_current_user),
):
    # 1. 권한 확인
    place = db.query(Place).filter(Place.pid == pid).first()
    if not place:
        raise HTTPException(status_code=404, detail="Place not found")
    
    # 관리자 권한 확인 (필요시)
    # if not current_user.is_management_role:
    #     raise HTTPException(status_code=403, detail="Insufficient permissions")
    
    # 2. 날짜 범위 검증
    if request.end_date < request.start_date:
        raise HTTPException(
            status_code=400,
            detail="end_date must be greater than or equal to start_date"
        )
    
    # 3. 인력 존재 확인
    hids = [item.hid for item in request.assignments]
    humans = db.query(Human).filter(Human.hid.in_(hids)).all()
    human_map = {h.hid: h for h in humans}
    
    for item in request.assignments:
        if item.hid not in human_map:
            raise HTTPException(
                status_code=404,
                detail=f"Human with hid={item.hid} not found"
            )
        human = human_map[item.hid]
        if human.hdelete != 0:
            raise HTTPException(
                status_code=400,
                detail=f"Human {human.hname} (hid={item.hid}) is deleted"
            )
    
    # 4. 날짜 범위 생성
    current_date = request.start_date
    dates = []
    while current_date <= request.end_date:
        dates.append(current_date)
        current_date += timedelta(days=1)
    
    # 5. 중복 체크 (선택사항)
    # 이미 존재하는 PlaceWorkDay를 어떻게 처리할지 정책 결정 필요
    # 옵션 1: 에러 반환
    # 옵션 2: 스킵
    # 옵션 3: 덮어쓰기
    
    existing_count = db.query(PlaceWorkDay).filter(
        PlaceWorkDay.pid == pid,
        PlaceWorkDay.workdate.in_([d.isoformat() for d in dates]),
        PlaceWorkDay.hid.in_(hids)
    ).count()
    
    if existing_count > 0:
        # 여기서는 스킵하는 정책 사용 (중복 제외하고 생성)
        print(f"⚠️ {existing_count}건의 중복된 투입이 있습니다. 스킵합니다.")
    
    # 6. PlaceWorkDay 일괄 생성
    created_work_days = []
    
    for work_date in dates:
        for assignment in request.assignments:
            # 중복 확인
            existing = db.query(PlaceWorkDay).filter(
                PlaceWorkDay.pid == pid,
                PlaceWorkDay.hid == assignment.hid,
                PlaceWorkDay.workdate == work_date.isoformat()
            ).first()
            
            if existing:
                continue  # 이미 존재하면 스킵
            
            # 새로운 PlaceWorkDay 생성
            pwd = PlaceWorkDay(
                pid=pid,
                hid=assignment.hid,
                workdate=work_date.isoformat(),
                workrole=assignment.workrole,
                dailywage=assignment.daily_wage,
                workerRank=assignment.workerRank or "",
                wcomplete=0,  # 기본값: 미완료
            )
            db.add(pwd)
            created_work_days.append(pwd)
    
    # 7. 작업지시 저장 (선택사항)
    if request.site_instruction_blocks or request.process_instruction_blocks:
        for work_date in dates:
            place_work_day_instructions_service.upsert_instruction(
                db=db,
                pid=pid,
                workdate=work_date.isoformat(),
                site_blocks=request.site_instruction_blocks,
                process_blocks=request.process_instruction_blocks,
            )
    
    # 8. PlaceWorkerRecent 업데이트
    for assignment in request.assignments:
        placeworkerrecent_service.upsert_recent_worker(
            db=db,
            pid=pid,
            hid=assignment.hid,
        )
    
    # 9. 커밋
    db.commit()
    
    # 10. 생성된 항목들 reload
    for pwd in created_work_days:
        db.refresh(pwd)
    
    # 11. 응답 생성
    return {
        "created_count": len(created_work_days),
        "date_range": {
            "start": request.start_date.isoformat(),
            "end": request.end_date.isoformat(),
            "days": len(dates),
        },
        "assignments_per_day": len(request.assignments),
        "work_days": [
            {
                "pwdid": pwd.pwdid,
                "pid": pwd.pid,
                "hid": pwd.hid,
                "workdate": pwd.workdate,
                "workrole": pwd.workrole,
                "dailywage": pwd.dailywage,
            }
            for pwd in created_work_days
        ],
    }
```

### 2. 스키마 정의

```python
# app/schemas/workforce_schemas.py

from pydantic import BaseModel, Field
from typing import List, Optional, Dict
from datetime import date

class WorkforceAssignmentItem(BaseModel):
    hid: int = Field(..., description="인력 ID")
    workrole: str = Field(..., description="작업 역할 (공정명)")
    daily_wage: int = Field(..., ge=0, description="일당")
    workerRank: Optional[str] = Field(None, description="직급 (조공/준기공/기공/반장)")

class BulkWorkforceAssignmentRequest(BaseModel):
    start_date: date = Field(..., description="시작 날짜 (포함)")
    end_date: date = Field(..., description="종료 날짜 (포함)")
    assignments: List[WorkforceAssignmentItem] = Field(
        ..., min_items=1, description="투입할 인력 목록"
    )
    site_instruction_blocks: Optional[List[dict]] = Field(
        None, description="전체 작업지시 (Quill Delta)"
    )
    process_instruction_blocks: Optional[Dict[str, List[dict]]] = Field(
        None, description="공정별 작업지시 (workrole → Quill Delta)"
    )

class DateRangeInfo(BaseModel):
    start: str
    end: str
    days: int

class PlaceWorkDaySimple(BaseModel):
    pwdid: int
    pid: int
    hid: int
    workdate: str
    workrole: str
    dailywage: int

class BulkWorkforceAssignmentResponse(BaseModel):
    created_count: int = Field(..., description="생성된 PlaceWorkDay 수")
    date_range: DateRangeInfo
    assignments_per_day: int = Field(..., description="일일 투입 인력 수")
    work_days: List[PlaceWorkDaySimple]
```

### 3. 라우터 등록

```python
# app/main.py

from app.routes import place_workforce_routes

app.include_router(
    place_workforce_routes.router,
    prefix="/api/places",
    tags=["workforce"],
)
```

---

## 🔔 FCM 알림 (기간 일괄 투입)

일별 `PlaceWorkDay`가 여러 건 생성되더라도 **작업자(uid)당 FCM은 1회**만 보낸다.  
(일별 중복 알림 금지 — 앱 로컬 dedupe만으로는 부족)

### payload 예시

```json
{
  "type": "placeworkday_assignment",
  "pid": "116",
  "pwdid": "12345",
  "workdate": "2026-07-16",
  "endDate": "2026-07-18",
  "pname": "○○아파트"
}
```

- `workdate`: 투입 **시작일** (포함)
- `endDate` (또는 `end_date`): 투입 **종료일** (포함). 시작일과 같으면 생략 가능
- 앱 표시: `7월 16일 ~ 7월 18일 · ○○아파트에 투입되었습니다.`

### Python 발송 예시

```python
def notify_bulk_work_assignment(
    uid: str,
    *,
    pid: int,
    pwdid: int,
    start_date: date,
    end_date: date,
    pname: str,
):
    if not should_send_notification(uid, 'work_assignment'):
        return
    data = {
        'type': 'placeworkday_assignment',
        'pid': str(pid),
        'pwdid': str(pwdid),
        'workdate': start_date.isoformat(),
        'pname': pname,
    }
    if end_date > start_date:
        data['endDate'] = end_date.isoformat()
    send_fcm_to_uid(uid, data=data)
```

---

## 🧪 테스트

### cURL 테스트

```bash
# 1. 로그인
TOKEN=$(curl -s -X POST http://localhost:8000/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"uid":"admin","upw":"password"}' \
  | jq -r '.access_token')

# 2. 일괄 투입 API 호출
curl -X POST "http://localhost:8000/api/places/116/workforce/bulk-assign" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "start_date": "2026-07-01",
    "end_date": "2026-07-05",
    "assignments": [
      {
        "hid": 14,
        "workrole": "타일공사",
        "daily_wage": 200000,
        "workerRank": "기공"
      },
      {
        "hid": 25,
        "workrole": "타일공사",
        "daily_wage": 150000,
        "workerRank": "조공"
      }
    ],
    "process_instruction_blocks": {
      "타일공사": [
        {
          "type": "text",
          "content": "타일 시공 순서: 벽 → 바닥"
        }
      ]
    }
  }' | jq
```

### Python 테스트 스크립트

```python
import requests
from datetime import date, timedelta

BASE_URL = "http://localhost:8000"

# 로그인
login_resp = requests.post(
    f"{BASE_URL}/api/auth/login",
    json={"uid": "admin", "upw": "password"}
)
token = login_resp.json()["access_token"]
headers = {"Authorization": f"Bearer {token}"}

# 일괄 투입 테스트
response = requests.post(
    f"{BASE_URL}/api/places/116/workforce/bulk-assign",
    headers=headers,
    json={
        "start_date": "2026-07-01",
        "end_date": "2026-07-05",
        "assignments": [
            {
                "hid": 14,
                "workrole": "타일공사",
                "daily_wage": 200000,
                "workerRank": "기공"
            },
            {
                "hid": 25,
                "workrole": "타일공사",
                "daily_wage": 150000,
                "workerRank": "조공"
            }
        ]
    }
)

if response.status_code == 200:
    result = response.json()
    print(f"✅ 성공!")
    print(f"   - 생성된 항목: {result['created_count']}건")
    print(f"   - 기간: {result['date_range']['start']} ~ {result['date_range']['end']}")
    print(f"   - 일수: {result['date_range']['days']}일")
    print(f"   - 일일 인력: {result['assignments_per_day']}명")
else:
    print(f"❌ 실패: {response.status_code}")
    print(response.json())
```

---

## 🔍 성능 최적화

### 1. 대량 INSERT 최적화

```python
# bulk_insert_mappings 사용
from sqlalchemy import insert

# 방법 1: bulk_insert_mappings (빠름)
work_day_dicts = []
for work_date in dates:
    for assignment in request.assignments:
        work_day_dicts.append({
            "pid": pid,
            "hid": assignment.hid,
            "workdate": work_date.isoformat(),
            "workrole": assignment.workrole,
            "dailywage": assignment.daily_wage,
            "workerRank": assignment.workerRank or "",
            "wcomplete": 0,
        })

db.bulk_insert_mappings(PlaceWorkDay, work_day_dicts)
```

### 2. 중복 체크 최적화

```python
# IN 쿼리로 한 번에 확인
existing_keys = set()
existing_records = db.query(
    PlaceWorkDay.hid,
    PlaceWorkDay.workdate
).filter(
    PlaceWorkDay.pid == pid,
    PlaceWorkDay.workdate.in_([d.isoformat() for d in dates]),
    PlaceWorkDay.hid.in_(hids)
).all()

for hid, workdate in existing_records:
    existing_keys.add((hid, workdate))

# 중복 제외하고 생성
for work_date in dates:
    for assignment in request.assignments:
        key = (assignment.hid, work_date.isoformat())
        if key not in existing_keys:
            # 생성
            ...
```

---

## 📊 DB 인덱스 추가

```sql
-- 중복 체크 및 조회 성능 향상
CREATE INDEX IF NOT EXISTS idx_placeworkday_pid_workdate_hid 
ON placeworkday(pid, workdate, hid);

-- 날짜 범위 조회 성능 향상
CREATE INDEX IF NOT EXISTS idx_placeworkday_pid_workdate 
ON placeworkday(pid, workdate);
```

---

## 🚨 에러 처리

### 일반적인 에러 케이스

1. **날짜 범위 오류** (400)
   ```json
   {
     "detail": "end_date must be greater than or equal to start_date"
   }
   ```

2. **인력 없음** (404)
   ```json
   {
     "detail": "Human with hid=999 not found"
   }
   ```

3. **삭제된 인력** (400)
   ```json
   {
     "detail": "Human 홍길동 (hid=14) is deleted"
   }
   ```

4. **권한 없음** (403)
   ```json
   {
     "detail": "Insufficient permissions"
   }
   ```

---

## 🎯 중복 처리 정책

### 옵션 1: 에러 반환 (엄격)
```python
if existing_count > 0:
    raise HTTPException(
        status_code=409,
        detail=f"{existing_count} conflicts found. Please check existing assignments."
    )
```

### 옵션 2: 스킵 (관대) ✅ 추천
```python
if existing:
    continue  # 이미 있으면 건너뛰기
```

### 옵션 3: 덮어쓰기 (위험)
```python
if existing:
    existing.workrole = assignment.workrole
    existing.dailywage = assignment.daily_wage
    # ...
```

---

## 📝 체크리스트

서버 구현 완료 확인:

- [ ] 라우트 추가 (`place_workforce_routes.py`)
- [ ] 스키마 정의 (`workforce_schemas.py`)
- [ ] 라우터 등록 (`main.py`)
- [ ] DB 인덱스 추가
- [ ] 단위 테스트 작성
- [ ] cURL 테스트 성공
- [ ] API 문서 업데이트 (Swagger)

---

## 🚀 다음 단계

1. 서버 API 구현 및 테스트
2. 클라이언트 통합
3. E2E 테스트
4. 배포

---

**작성일**: 2026-07-07  
**버전**: 1.0.0  
**API 버전**: v1
