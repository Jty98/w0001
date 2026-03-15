# SQLite에서 PostgreSQL로 마이그레이션 가이드

## 아키텍처 개요

```
┌─────────────────┐
│  Flutter 앱     │  (프론트엔드)
│  (HTTP Client)  │
└────────┬────────┘
         │ HTTP/REST API
         ↓
┌─────────────────┐
│  백엔드 서버     │  (API 서버)
│  (Node.js/Go/   │
│   Python 등)    │
└────────┬────────┘
         │ SQL 쿼리
         ↓
┌─────────────────┐
│  PostgreSQL     │  (데이터베이스)
│  데이터베이스    │
└─────────────────┘
```

## 역할 분담

### Flutter 앱 (프론트엔드)
- **역할**: UI/UX 제공, 사용자 입력 처리
- **사용 패키지**: `dio` (HTTP 클라이언트)
- **책임**: REST API 호출만 담당

### 백엔드 서버
- **역할**: 비즈니스 로직 처리, 데이터 검증
- **사용 패키지**: PostgreSQL 드라이버 (예: `pg`, `sqlx`, `GORM` 등)
- **책임**: 
  - API 엔드포인트 제공
  - PostgreSQL과 직접 통신
  - 인증/인가 처리
  - 데이터 검증 및 변환

### PostgreSQL 데이터베이스
- **역할**: 데이터 저장 및 관리
- **사용 위치**: 백엔드 서버에서만 접근

## 주요 변경사항

### 1. Flutter 앱 측 변경

#### 패키지 변경
```yaml
# 제거
postgres: ^3.0.0  # ❌ 불필요

# 추가
dio: ^5.4.0  # ✅ HTTP 클라이언트
```

#### 코드 변경
```dart
// 기존 (SQLite 직접 접근)
final dbHelper = DbHelper();
await dbHelper.initializeDB();
final places = await dbHelper.getAllPlaces();

// 변경 후 (REST API 호출)
final dataSource = RemoteDataSource(baseUrl: 'https://api.example.com');
final places = await dataSource.getAllPlaces();
```

### 2. 백엔드 서버 측

#### PostgreSQL 스키마 사용
- `database/schema.sql` 파일을 백엔드 서버에서 실행
- 백엔드 서버가 PostgreSQL과 직접 통신

#### API 엔드포인트 예시
```
GET    /api/places              # 모든 현장 조회
POST   /api/places              # 현장 추가
PUT    /api/places/:id           # 현장 수정
DELETE /api/places/:id           # 현장 삭제

GET    /api/workers              # 모든 작업자 조회
POST   /api/workers              # 작업자 추가
...

GET    /api/work-costs           # 인건비 조회
POST   /api/work-costs/batch     # 인건비 일괄 추가
...
```

## 설치 및 설정

### 1. Flutter 앱 설정

```bash
# HTTP 클라이언트 패키지 추가
flutter pub add dio
```

```dart
// lib/data/datasources/remote_data_source.dart 사용
final dataSource = RemoteDataSource(
  baseUrl: 'https://your-api-server.com',
  apiKey: 'your-api-key', // 필요시
);
```

### 2. 백엔드 서버 설정

#### PostgreSQL 설치 및 데이터베이스 생성
```bash
# PostgreSQL 설치 (macOS)
brew install postgresql@15
brew services start postgresql@15

# 데이터베이스 생성
createdb interior_app

# 사용자 생성 및 권한 부여
psql -d interior_app
CREATE USER app_user WITH PASSWORD 'your_password';
GRANT ALL PRIVILEGES ON DATABASE interior_app TO app_user;
```

#### 스키마 생성
```bash
psql -d interior_app -U app_user -f database/schema.sql
```

#### 백엔드 서버 예시 (Node.js + Express)
```javascript
const express = require('express');
const { Pool } = require('pg');

const pool = new Pool({
  host: 'localhost',
  port: 5432,
  database: 'interior_app',
  user: 'app_user',
  password: 'your_password',
});

const app = express();
app.use(express.json());

// 모든 현장 조회
app.get('/api/places', async (req, res) => {
  try {
    const result = await pool.query(`
      SELECT p.*, ...
      FROM Place p
      ...
    `);
    res.json(result.rows);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

app.listen(3000);
```

## 데이터 마이그레이션

기존 SQLite 데이터를 PostgreSQL로 마이그레이션:

1. **SQLite 데이터 내보내기**
   ```bash
   sqlite3 w00001.db .dump > data_export.sql
   ```

2. **데이터 변환 스크립트 작성** (날짜 형식 등 변환 필요)

3. **PostgreSQL로 데이터 가져오기**
   ```bash
   psql -d interior_app -f data_import.sql
   ```

## 보안 고려사항

### 1. 인증/인가
- JWT 토큰 사용
- API 키 관리
- 사용자 권한 체크

### 2. 데이터 검증
- 백엔드에서 모든 입력 데이터 검증
- SQL Injection 방지 (Prepared Statements 사용)

### 3. HTTPS 사용
- 프로덕션 환경에서는 반드시 HTTPS 사용

## 환경 변수 설정

### Flutter 앱
```dart
final baseUrl = Platform.environment['API_BASE_URL'] ?? 'http://localhost:3000';
final apiKey = Platform.environment['API_KEY'] ?? '';
```

### 백엔드 서버
```bash
DB_HOST=localhost
DB_PORT=5432
DB_NAME=interior_app
DB_USER=app_user
DB_PASSWORD=your_password
```

## 문제 해결

### 연결 오류
- 백엔드 서버가 실행 중인지 확인
- 네트워크 연결 확인
- CORS 설정 확인 (웹 앱인 경우)

### 인증 오류
- API 키 또는 토큰 확인
- 토큰 만료 시간 확인

### 성능 문제
- API 응답 시간 확인
- 백엔드 서버 로그 확인
- PostgreSQL 쿼리 최적화

## 참고 파일

- `database/schema.sql`: PostgreSQL 스키마 (백엔드 서버에서 사용)
- `lib/data/datasources/remote_data_source.dart`: Flutter 앱의 API 클라이언트
