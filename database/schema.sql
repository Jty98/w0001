-- PostgreSQL Schema for Interior App
-- Migration from SQLite to PostgreSQL

-- Human 테이블 생성
CREATE TABLE IF NOT EXISTS Human (
    hid BIGSERIAL PRIMARY KEY,
    hname VARCHAR(255) NOT NULL,
    hnumber VARCHAR(255),
    hmemo TEXT,
    hstar INTEGER DEFAULT 0,
    hdelete INTEGER DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Place 테이블 생성
CREATE TABLE IF NOT EXISTS Place (
    pid BIGSERIAL PRIMARY KEY,
    pname VARCHAR(255) NOT NULL,
    pstart VARCHAR(50),
    pend VARCHAR(50),
    pcomplete INTEGER DEFAULT 0,
    prevenue INTEGER DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- WorkCost 테이블 생성
CREATE TABLE IF NOT EXISTS WorkCost (
    wid BIGSERIAL PRIMARY KEY,
    whid BIGINT,
    wdate TIMESTAMP NOT NULL,
    wprice INTEGER NOT NULL,
    wpid BIGINT,
    wcomplete INTEGER DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (whid) REFERENCES Human(hid) ON DELETE SET NULL,
    FOREIGN KEY (wpid) REFERENCES Place(pid) ON DELETE CASCADE
);

-- MaterialCost 테이블 생성
CREATE TABLE IF NOT EXISTS MaterialCost (
    mid BIGSERIAL PRIMARY KEY,
    mpid BIGINT,
    mname VARCHAR(255) NOT NULL,
    mdate TIMESTAMP NOT NULL,
    mprice INTEGER NOT NULL,
    mcategory VARCHAR(50),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (mpid) REFERENCES Place(pid) ON DELETE CASCADE
);

-- PlaceRevenue 테이블 생성
CREATE TABLE IF NOT EXISTS PlaceRevenue (
    rid BIGSERIAL PRIMARY KEY,
    rpid BIGINT NOT NULL,
    rname VARCHAR(255) NOT NULL,
    rorder INTEGER DEFAULT 0,
    rprice INTEGER DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (rpid) REFERENCES Place(pid) ON DELETE CASCADE
);

-- 인덱스 생성 (성능 최적화)
CREATE INDEX IF NOT EXISTS idx_human_hdelete ON Human(hdelete);
CREATE INDEX IF NOT EXISTS idx_human_hstar ON Human(hstar);
CREATE INDEX IF NOT EXISTS idx_place_pcomplete ON Place(pcomplete);
CREATE INDEX IF NOT EXISTS idx_workcost_whid ON WorkCost(whid);
CREATE INDEX IF NOT EXISTS idx_workcost_wpid ON WorkCost(wpid);
CREATE INDEX IF NOT EXISTS idx_workcost_wdate ON WorkCost(wdate);
CREATE INDEX IF NOT EXISTS idx_workcost_wcomplete ON WorkCost(wcomplete);
CREATE INDEX IF NOT EXISTS idx_materialcost_mpid ON MaterialCost(mpid);
CREATE INDEX IF NOT EXISTS idx_materialcost_mdate ON MaterialCost(mdate);
CREATE INDEX IF NOT EXISTS idx_materialcost_mcategory ON MaterialCost(mcategory);
CREATE INDEX IF NOT EXISTS idx_placerevenue_rpid ON PlaceRevenue(rpid);
CREATE INDEX IF NOT EXISTS idx_placerevenue_rorder ON PlaceRevenue(rorder);

-- updated_at 자동 업데이트를 위한 트리거 함수
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ language 'plpgsql';

-- 각 테이블에 updated_at 트리거 생성
CREATE TRIGGER update_human_updated_at BEFORE UPDATE ON Human
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_place_updated_at BEFORE UPDATE ON Place
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_workcost_updated_at BEFORE UPDATE ON WorkCost
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_materialcost_updated_at BEFORE UPDATE ON MaterialCost
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_placerevenue_updated_at BEFORE UPDATE ON PlaceRevenue
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
