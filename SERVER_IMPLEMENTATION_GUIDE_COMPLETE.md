# 🚀 기간별 일괄 인력투입 서버 구현 완전 가이드

## 📌 개요

클라이언트에서 다음 기능을 구현했습니다:
1. ✅ 공정 선택
2. ✅ 달력에서 날짜 범위 선택 (공정 이벤트 표시)
3. ✅ 최근 작업자 목록 자동 로드
4. ✅ 인력 선택 및 기간별 일괄 투입

서버에서 구현해야 할 API는 **2개**입니다:
1. **최근 작업자 조회 API** (이미 구현되어 있을 수 있음)
2. **기간별 일괄 인력투입 API** (새로 구현 필요)

---

## 🎯 1. 최근 작업자 조회 API

### 엔드포인트
```
GET /api/places/{pid}/recent-workers
```

### 설명
특정 현장에서 최근에 작업한 인력 목록을 반환합니다.

### 요청
```http
GET /api/places/116/recent-workers?limit=50&offset=0
Authorization: Bearer {access_token}
```

#### Query Parameters
- `limit` (optional, default=100): 반환할 최대 인원 수
- `offset` (optional, default=0): 페이지네이션 오프셋

### 응답
```json
[
  {
    "hid": 14,
    "uid": "worker001",
    "hname": "김철수",
    "hnumber": "010-1234-5678",
    "hdailyWage": 200000,
    "hdefaultRole": "타일공",
    "primarySpecialty": "타일",
    "specialties": ["타일", "미장"],
    "career": "10년",
    "workerRank": "기공",
    "last_work_date": "2026-06-30"
  },
  {
    "hid": 25,
    "uid": "worker002",
    "hname": "이영희",
    "hnumber": "010-5678-1234",
    "hdailyWage": 150000,
    "hdefaultRole": "조공",
    "primarySpecialty": "타일",
    "specialties": ["타일"],
    "career": "3년",
    "workerRank": "조공",
    "last_work_date": "2026-06-28"
  }
]
```

### 구현 예시 (FastAPI)

```python
from fastapi import APIRouter, Depends, Query
from sqlalchemy import select, func, and_
from sqlalchemy.orm import Session
from typing import List
from datetime import datetime

@router.get("/places/{pid}/recent-workers")
async def get_recent_workers_for_place(
    pid: int,
    limit: int = Query(default=100, ge=1, le=200),
    offset: int = Query(default=0, ge=0),
    db: Session = Depends(get_db),
    current_user: AppUser = Depends(get_current_user),
) -> List[dict]:
    """
    현장에서 최근 작업한 인력 목록 조회 (통합 최적화 쿼리)
    """
    
    # 권한 체크
    place = db.get(Place, pid)
    if not place:
        raise HTTPException(status_code=404, detail="Place not found")
    
    # 해당 현장에서 작업한 적 있는 인력 조회 (최근 순)
    # place_work_days 테이블에서 중복 제거하여 최근 작업일 기준 정렬
    subquery = (
        select(
            PlaceWorkDay.hid,
            func.max(PlaceWorkDay.workdate).label('last_work_date')
        )
        .where(PlaceWorkDay.pid == pid)
        .group_by(PlaceWorkDay.hid)
        .order_by(func.max(PlaceWorkDay.workdate).desc())
        .limit(limit)
        .offset(offset)
        .subquery()
    )
    
    # 인력 정보 조회
    stmt = (
        select(Human, subquery.c.last_work_date)
        .join(subquery, Human.hid == subquery.c.hid)
        .order_by(subquery.c.last_work_date.desc())
    )
    
    results = db.execute(stmt).all()
    
    return [
        {
            "hid": human.hid,
            "uid": human.uid,
            "hname": human.hname,
            "hnumber": human.hnumber,
            "hdailyWage": human.hdaily_wage,
            "hdefaultRole": human.hdefault_role or "",
            "primarySpecialty": human.primary_specialty,
            "specialties": human.specialties or [],
            "career": human.career or "",
            "workerRank": human.worker_rank,
            "last_work_date": last_work_date.isoformat() if last_work_date else None,
        }
        for human, last_work_date in results
    ]
```

### 성능 최적화

#### 1. 인덱스 추가
```sql
-- place_work_days 테이블에 복합 인덱스 추가
CREATE INDEX idx_place_work_days_pid_workdate 
ON place_work_days(pid, workdate DESC);

CREATE INDEX idx_place_work_days_pid_hid 
ON place_work_days(pid, hid);
```

#### 2. 쿼리 설명
- `place_work_days` 테이블에서 해당 현장(`pid`)의 작업 이력 조회
- `GROUP BY hid`로 중복 제거
- `MAX(workdate)`로 최근 작업일 기준 정렬
- `JOIN`으로 인력 정보와 결합

---

## 🎯 2. 기간별 일괄 인력투입 API

### 엔드포인트
```
POST /api/places/{pid}/workforce/bulk-assign
```

### 설명
여러 날짜에 대해 인력을 일괄 투입합니다.

### 요청
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

### 요청 스키마

```python
from pydantic import BaseModel, Field
from typing import List, Optional, Dict
from datetime import date

class WorkforceAssignmentItem(BaseModel):
    """개별 인력 투입 정보"""
    hid: int = Field(..., description="인력 ID")
    workrole: str = Field(..., description="작업 역할")
    daily_wage: int = Field(..., description="일당")
    workerRank: Optional[str] = Field(None, description="직급 (조공/준기공/기공/반장/감리)")

class BulkWorkforceAssignmentRequest(BaseModel):
    """기간별 일괄 인력투입 요청"""
    start_date: date = Field(..., description="시작일 (ISO 8601)")
    end_date: date = Field(..., description="종료일 (ISO 8601)")
    assignments: List[WorkforceAssignmentItem] = Field(..., description="투입할 인력 목록")
    site_instruction_blocks: Optional[List[dict]] = Field(None, description="현장 전체 작업지시")
    process_instruction_blocks: Optional[Dict[str, List[dict]]] = Field(
        None, 
        description="공정별 작업지시 (key: workrole, value: instruction blocks)"
    )
    
    class Config:
        json_schema_extra = {
            "example": {
                "start_date": "2026-07-01",
                "end_date": "2026-07-05",
                "assignments": [
                    {
                        "hid": 14,
                        "workrole": "타일공사",
                        "daily_wage": 200000,
                        "workerRank": "기공"
                    }
                ],
                "site_instruction_blocks": None,
                "process_instruction_blocks": {
                    "타일공사": [
                        {"type": "text", "content": "작업 지시 내용"}
                    ]
                }
            }
        }
```

### 응답

```json
{
  "created_count": 10,
  "date_range": {
    "start": "2026-07-01",
    "end": "2026-07-05",
    "days": 5
  },
  "assignments_per_day": 2,
  "total_assignments": 10,
  "work_days": [
    {
      "pwdid": 1001,
      "pid": 116,
      "hid": 14,
      "workdate": "2026-07-01",
      "workrole": "타일공사",
      "dailywage": 200000,
      "workerRank": "기공"
    }
    // ... 나머지 생성된 작업일
  ]
}
```

### 구현 예시 (FastAPI + SQLAlchemy)

```python
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from sqlalchemy.exc import IntegrityError
from datetime import datetime, timedelta
from typing import List, Dict, Any
import json

router = APIRouter()

@router.post("/places/{pid}/workforce/bulk-assign")
async def bulk_assign_workforce(
    pid: int,
    request: BulkWorkforceAssignmentRequest,
    db: Session = Depends(get_db),
    current_user: AppUser = Depends(get_current_user),
) -> Dict[str, Any]:
    """
    기간별 일괄 인력투입
    """
    
    # 1. 권한 체크
    place = db.get(Place, pid)
    if not place:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Place {pid} not found"
        )
    
    if not current_user.is_management_role:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="관리자 권한이 필요합니다"
        )
    
    # 2. 입력 검증
    if request.end_date < request.start_date:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="종료일은 시작일보다 이후여야 합니다"
        )
    
    if len(request.assignments) == 0:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="최소 1명 이상의 인력을 선택해야 합니다"
        )
    
    # 날짜 범위 계산
    days_count = (request.end_date - request.start_date).days + 1
    
    if days_count > 365:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="최대 365일까지 투입 가능합니다"
        )
    
    # 3. 인력 존재 여부 확인
    hids = [assignment.hid for assignment in request.assignments]
    humans = db.query(Human).filter(Human.hid.in_(hids)).all()
    
    if len(humans) != len(hids):
        missing_hids = set(hids) - {h.hid for h in humans}
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"인력을 찾을 수 없습니다: {missing_hids}"
        )
    
    # 4. 작업일 생성
    created_work_days = []
    
    try:
        for assignment in request.assignments:
            # 각 날짜별로 작업일 생성
            current_date = request.start_date
            
            while current_date <= request.end_date:
                # 작업지시 처리
                instruction_blocks = None
                
                # 공정별 작업지시가 있으면 사용
                if request.process_instruction_blocks:
                    process_blocks = request.process_instruction_blocks.get(
                        assignment.workrole
                    )
                    if process_blocks:
                        instruction_blocks = json.dumps(process_blocks, ensure_ascii=False)
                
                # 현장 전체 작업지시가 있으면 사용
                if not instruction_blocks and request.site_instruction_blocks:
                    instruction_blocks = json.dumps(
                        request.site_instruction_blocks, 
                        ensure_ascii=False
                    )
                
                # 작업일 레코드 생성
                work_day = PlaceWorkDay(
                    pid=pid,
                    hid=assignment.hid,
                    workdate=current_date,
                    workrole=assignment.workrole,
                    dailywage=assignment.daily_wage,
                    workerRank=assignment.workerRank,
                    instruction_blocks=instruction_blocks,
                    created_by=current_user.uid,
                    created_at=datetime.utcnow(),
                )
                
                db.add(work_day)
                created_work_days.append(work_day)
                
                # 다음 날짜로
                current_date += timedelta(days=1)
        
        # 5. 데이터베이스에 커밋
        db.commit()
        
        # 6. 생성된 레코드 새로고침 (ID 등 서버 생성 값 가져오기)
        for work_day in created_work_days:
            db.refresh(work_day)
        
        # 7. 응답 생성
        return {
            "created_count": len(created_work_days),
            "date_range": {
                "start": request.start_date.isoformat(),
                "end": request.end_date.isoformat(),
                "days": days_count,
            },
            "assignments_per_day": len(request.assignments),
            "total_assignments": len(created_work_days),
            "work_days": [
                {
                    "pwdid": wd.pwdid,
                    "pid": wd.pid,
                    "hid": wd.hid,
                    "workdate": wd.workdate.isoformat(),
                    "workrole": wd.workrole,
                    "dailywage": wd.dailywage,
                    "workerRank": wd.workerRank,
                }
                for wd in created_work_days
            ],
        }
    
    except IntegrityError as e:
        db.rollback()
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=f"이미 투입된 날짜가 있습니다: {str(e)}"
        )
    
    except Exception as e:
        db.rollback()
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"작업일 생성 중 오류 발생: {str(e)}"
        )
```

### 데이터베이스 모델

```python
from sqlalchemy import Column, Integer, String, Date, Text, DateTime, ForeignKey
from sqlalchemy.orm import relationship
from datetime import datetime

class PlaceWorkDay(Base):
    __tablename__ = "place_work_days"
    
    pwdid = Column(Integer, primary_key=True, autoincrement=True)
    pid = Column(Integer, ForeignKey("places.pid"), nullable=False, index=True)
    hid = Column(Integer, ForeignKey("humans.hid"), nullable=False, index=True)
    workdate = Column(Date, nullable=False, index=True)
    workrole = Column(String(100), nullable=False)
    dailywage = Column(Integer, nullable=False)
    workerRank = Column(String(50), nullable=True)
    instruction_blocks = Column(Text, nullable=True)  # JSON string
    created_by = Column(String(100), nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    
    # Relationships
    place = relationship("Place", back_populates="work_days")
    human = relationship("Human", back_populates="work_days")
    
    # Unique constraint: 한 사람이 같은 날짜에 중복 투입 방지
    __table_args__ = (
        UniqueConstraint('pid', 'hid', 'workdate', name='uix_place_human_date'),
        Index('idx_place_work_days_pid_workdate', 'pid', 'workdate'),
        Index('idx_place_work_days_hid_workdate', 'hid', 'workdate'),
    )
```

---

## 🔐 보안 및 검증

### 1. 권한 체크
```python
# 관리자 권한 확인
if not current_user.is_management_role:
    raise HTTPException(status_code=403, detail="관리자 권한 필요")

# 현장 접근 권한 확인 (필요시)
if not user_has_access_to_place(current_user, pid):
    raise HTTPException(status_code=403, detail="현장 접근 권한 없음")
```

### 2. 입력 검증
```python
# 날짜 범위 검증
if request.end_date < request.start_date:
    raise HTTPException(status_code=400, detail="잘못된 날짜 범위")

# 기간 제한
days_count = (request.end_date - request.start_date).days + 1
if days_count > 365:
    raise HTTPException(status_code=400, detail="최대 365일")

# 인력 수 제한
if len(request.assignments) > 100:
    raise HTTPException(status_code=400, detail="최대 100명")

# 일당 범위 검증
for assignment in request.assignments:
    if assignment.daily_wage < 0 or assignment.daily_wage > 10_000_000:
        raise HTTPException(status_code=400, detail="일당 범위 초과")
```

### 3. 중복 방지
```python
# 데이터베이스 Unique Constraint
__table_args__ = (
    UniqueConstraint('pid', 'hid', 'workdate', name='uix_place_human_date'),
)

# 또는 코드에서 체크
existing = db.query(PlaceWorkDay).filter(
    PlaceWorkDay.pid == pid,
    PlaceWorkDay.hid == assignment.hid,
    PlaceWorkDay.workdate == current_date,
).first()

if existing:
    # 건너뛰거나 업데이트
    pass
```

---

## ⚡ 성능 최적화

### 1. 대량 삽입 (Bulk Insert)

```python
# ❌ 비효율적 (한 번에 하나씩)
for work_day in work_days:
    db.add(work_day)
    db.commit()  # N번 커밋

# ✅ 효율적 (한 번에 모두)
db.bulk_insert_mappings(PlaceWorkDay, work_day_dicts)
db.commit()  # 1번 커밋
```

**개선된 구현**:
```python
# 작업일 데이터 준비
work_day_dicts = []

for assignment in request.assignments:
    current_date = request.start_date
    while current_date <= request.end_date:
        work_day_dicts.append({
            'pid': pid,
            'hid': assignment.hid,
            'workdate': current_date,
            'workrole': assignment.workrole,
            'dailywage': assignment.daily_wage,
            'workerRank': assignment.workerRank,
            'created_by': current_user.uid,
            'created_at': datetime.utcnow(),
        })
        current_date += timedelta(days=1)

# 한 번에 삽입
db.bulk_insert_mappings(PlaceWorkDay, work_day_dicts)
db.commit()
```

### 2. 인덱스 추가

```sql
-- 조회 성능 향상
CREATE INDEX idx_place_work_days_pid_workdate 
ON place_work_days(pid, workdate DESC);

CREATE INDEX idx_place_work_days_hid_workdate 
ON place_work_days(hid, workdate DESC);

-- 중복 체크 성능 향상
CREATE UNIQUE INDEX uix_place_human_date 
ON place_work_days(pid, hid, workdate);
```

### 3. 트랜잭션 관리

```python
try:
    # 모든 작업을 하나의 트랜잭션으로
    db.bulk_insert_mappings(PlaceWorkDay, work_day_dicts)
    db.commit()
except Exception as e:
    db.rollback()
    raise
```

---

## 🧪 테스트

### 1. 단위 테스트

```python
import pytest
from datetime import date

def test_bulk_assign_basic(client, auth_token):
    """기본 일괄 투입 테스트"""
    response = client.post(
        "/api/places/116/workforce/bulk-assign",
        headers={"Authorization": f"Bearer {auth_token}"},
        json={
            "start_date": "2026-07-01",
            "end_date": "2026-07-03",
            "assignments": [
                {"hid": 14, "workrole": "타일", "daily_wage": 200000}
            ]
        }
    )
    
    assert response.status_code == 200
    data = response.json()
    assert data["created_count"] == 3  # 3일 * 1명
    assert data["date_range"]["days"] == 3

def test_bulk_assign_multiple_workers(client, auth_token):
    """다수 인력 일괄 투입 테스트"""
    response = client.post(
        "/api/places/116/workforce/bulk-assign",
        headers={"Authorization": f"Bearer {auth_token}"},
        json={
            "start_date": "2026-07-01",
            "end_date": "2026-07-05",
            "assignments": [
                {"hid": 14, "workrole": "타일", "daily_wage": 200000},
                {"hid": 25, "workrole": "타일", "daily_wage": 150000}
            ]
        }
    )
    
    assert response.status_code == 200
    data = response.json()
    assert data["created_count"] == 10  # 5일 * 2명

def test_bulk_assign_invalid_date_range(client, auth_token):
    """잘못된 날짜 범위 테스트"""
    response = client.post(
        "/api/places/116/workforce/bulk-assign",
        headers={"Authorization": f"Bearer {auth_token}"},
        json={
            "start_date": "2026-07-05",
            "end_date": "2026-07-01",  # 종료일이 시작일보다 이전
            "assignments": [
                {"hid": 14, "workrole": "타일", "daily_wage": 200000}
            ]
        }
    )
    
    assert response.status_code == 400

def test_bulk_assign_duplicate(client, auth_token):
    """중복 투입 방지 테스트"""
    # 첫 번째 투입
    response1 = client.post(
        "/api/places/116/workforce/bulk-assign",
        headers={"Authorization": f"Bearer {auth_token}"},
        json={
            "start_date": "2026-07-01",
            "end_date": "2026-07-01",
            "assignments": [
                {"hid": 14, "workrole": "타일", "daily_wage": 200000}
            ]
        }
    )
    assert response1.status_code == 200
    
    # 중복 투입 시도
    response2 = client.post(
        "/api/places/116/workforce/bulk-assign",
        headers={"Authorization": f"Bearer {auth_token}"},
        json={
            "start_date": "2026-07-01",
            "end_date": "2026-07-01",
            "assignments": [
                {"hid": 14, "workrole": "미장", "daily_wage": 180000}
            ]
        }
    )
    assert response2.status_code == 409  # Conflict
```

### 2. 통합 테스트

```bash
# cURL로 API 테스트
curl -X POST http://localhost:8000/api/places/116/workforce/bulk-assign \
  -H "Authorization: Bearer YOUR_TOKEN" \
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
      }
    ]
  }'
```

---

## 📊 모니터링 및 로깅

### 1. 요청 로깅

```python
import logging

logger = logging.getLogger(__name__)

@router.post("/places/{pid}/workforce/bulk-assign")
async def bulk_assign_workforce(
    pid: int,
    request: BulkWorkforceAssignmentRequest,
    db: Session = Depends(get_db),
    current_user: AppUser = Depends(get_current_user),
):
    logger.info(
        f"Bulk assignment started: user={current_user.uid}, pid={pid}, "
        f"date_range={request.start_date}~{request.end_date}, "
        f"workers={len(request.assignments)}"
    )
    
    try:
        # ... 구현 ...
        
        logger.info(
            f"Bulk assignment completed: created={len(created_work_days)} records"
        )
        
        return response
        
    except Exception as e:
        logger.error(
            f"Bulk assignment failed: user={current_user.uid}, pid={pid}, "
            f"error={str(e)}"
        )
        raise
```

### 2. 성능 모니터링

```python
import time

start_time = time.time()

# ... API 로직 ...

duration = time.time() - start_time
logger.info(f"Bulk assignment took {duration:.2f}s")

if duration > 5.0:
    logger.warning(f"Slow bulk assignment: {duration:.2f}s for {days_count} days")
```

---

## 🚀 배포 체크리스트

### 서버 구현
- [ ] `GET /api/places/{pid}/recent-workers` 구현
- [ ] `POST /api/places/{pid}/workforce/bulk-assign` 구현
- [ ] Pydantic 스키마 정의
- [ ] 권한 체크 구현
- [ ] 입력 검증 구현

### 데이터베이스
- [ ] `place_work_days` 테이블 확인/생성
- [ ] 인덱스 추가
- [ ] Unique Constraint 추가

### 테스트
- [ ] 단위 테스트 작성
- [ ] 통합 테스트 작성
- [ ] 성능 테스트 (100명 × 30일)
- [ ] 중복 방지 테스트

### 문서화
- [ ] API 문서 (Swagger/OpenAPI)
- [ ] 에러 코드 정의
- [ ] 예제 요청/응답

### 모니터링
- [ ] 로깅 추가
- [ ] 성능 모니터링
- [ ] 에러 알림 설정

---

## 📝 에러 코드

| 상태 코드 | 설명 | 대응 방법 |
|----------|------|----------|
| 200 | 성공 | - |
| 400 | 잘못된 요청 (날짜 범위, 인력 수 등) | 요청 데이터 확인 |
| 403 | 권한 없음 | 관리자 권한 필요 |
| 404 | 현장 또는 인력을 찾을 수 없음 | ID 확인 |
| 409 | 중복된 투입 | 기존 데이터 확인 |
| 500 | 서버 오류 | 로그 확인 |

---

## 💡 추가 고려사항

### 1. 비동기 처리 (선택사항)
대량 데이터 (예: 100명 × 365일 = 36,500건)의 경우:

```python
from celery import shared_task

@shared_task
def bulk_assign_workforce_async(pid, request_data, user_id):
    # 백그라운드에서 처리
    # 완료 후 알림
    pass
```

### 2. 진행 상황 알림 (선택사항)
```python
# WebSocket으로 진행 상황 전송
await websocket.send_json({
    "type": "bulk_assign_progress",
    "progress": 50,
    "created": 50,
    "total": 100
})
```

### 3. 롤백 기능 (선택사항)
```python
@router.delete("/places/{pid}/workforce/bulk-assignments/{batch_id}")
async def rollback_bulk_assignment(pid: int, batch_id: str):
    # 특정 배치의 일괄 투입 취소
    pass
```

---

## 🎉 완료!

이 가이드를 따라 구현하면 클라이언트의 기간별 일괄 인력투입 기능이 완벽하게 작동합니다! 🚀
