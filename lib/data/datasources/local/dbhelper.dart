import 'package:flutter/material.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:w0001/data/model/human_model.dart';
import 'package:w0001/data/model/materialcost_model.dart';
import 'package:w0001/data/model/place_dropdown_model.dart';
import 'package:w0001/data/model/place_info_model.dart';
import 'package:w0001/data/model/place_model.dart';
import 'package:w0001/data/model/place_photo_group_model.dart';
import 'package:w0001/data/model/revenue_model.dart';
import 'package:w0001/data/model/total_cost_model.dart';
import 'package:w0001/data/model/total_workcost_model.dart';
import 'package:w0001/data/model/workcost_model.dart';
import 'package:w0001/data/model/monthly_summary_model.dart';
import 'package:w0001/data/model/dashboard_models.dart';
import 'package:w0001/data/model/schedule_memo_model.dart';

class DbHelper {
  final int curruntVersion = 14;
  Database? db;

  Future<Database> initializeDB() async {
    return await openDatabase(
      join(await getDatabasesPath(), 'w00001.db'),
      version: curruntVersion,
      onCreate: (database, version) async {
        // Human 테이블 생성
        await database.execute('''CREATE TABLE IF NOT EXISTS Human (
          hid INTEGER PRIMARY KEY AUTOINCREMENT,
          hname TEXT,
          hnumber TEXT,
          hmemo TEXT,
          hdailyWage INTEGER DEFAULT 0,
          hdefaultRole TEXT DEFAULT '',
          hstar INTEGER,
          hdelete INTEGER DEFAULT 0
        )''');

        // Place 테이블 생성
        await database.execute('''CREATE TABLE IF NOT EXISTS Place (
          pid INTEGER PRIMARY KEY AUTOINCREMENT,
          pname TEXT,
          pstart TEXT,
          pend TEXT,
          paddress TEXT DEFAULT '',
          pcomplete INTEGER DEFAULT 0,
          prevenue INTEGER DEFAULT 0,
          pcontractTotal INTEGER DEFAULT 0,
          pcontractDate TEXT DEFAULT ''
        )''');

        // WorkCost 테이블 생성
        await database.execute('''CREATE TABLE IF NOT EXISTS WorkCost (
          wid INTEGER PRIMARY KEY AUTOINCREMENT,
          whid INTEGER,
          wdate TEXT,
          wprice INTEGER,
          wpid INTEGER,
          wcomplete INTEGER DEFAULT 0,
          wrole TEXT DEFAULT '',
          FOREIGN KEY (whid) REFERENCES Human(hid),
          FOREIGN KEY (wpid) REFERENCES Place(pid)
        )''');

        // PlaceWorkDay 테이블 생성 (현장-날짜-사람 투입/출근 원천 데이터)
        // - 하루 1레코드(일당 기준)
        // - paid: 0(미지급) / 1(지급)
        await database.execute('''CREATE TABLE IF NOT EXISTS PlaceWorkDay (
          pwdid INTEGER PRIMARY KEY AUTOINCREMENT,
          pid INTEGER,
          hid INTEGER,
          workDate TEXT,
          dailyWage INTEGER DEFAULT 0,
          paid INTEGER DEFAULT 0,
          workRole TEXT DEFAULT '',
          FOREIGN KEY (hid) REFERENCES Human(hid),
          FOREIGN KEY (pid) REFERENCES Place(pid)
        )''');

        // MaterialCost 테이블 생성
        await database.execute('''CREATE TABLE IF NOT EXISTS MaterialCost (
          mid INTEGER PRIMARY KEY AUTOINCREMENT,
          mpid INTEGER,
          mname TEXT,
          mdate TEXT,
          mprice INTEGER,
          mcategory TEXT,
          FOREIGN KEY (mpid) REFERENCES Place(pid)
        )''');
        await database.execute('''CREATE TABLE IF NOT EXISTS PlaceRevenue (
          rid INTEGER PRIMARY KEY AUTOINCREMENT,
          rpid INTEGER,
          rname TEXT,
          rorder INTEGER,
          rprice INTEGER,
          rdate TEXT DEFAULT '',
          FOREIGN KEY (rpid) REFERENCES Place(pid)
        )''');

        await database.execute('''CREATE TABLE IF NOT EXISTS PlaceCollection (
          cid INTEGER PRIMARY KEY AUTOINCREMENT,
          pid INTEGER NOT NULL,
          cdate TEXT NOT NULL,
          ckind TEXT NOT NULL,
          camount INTEGER NOT NULL DEFAULT 0,
          cnote TEXT DEFAULT '',
          revenueId INTEGER,
          FOREIGN KEY (pid) REFERENCES Place(pid),
          FOREIGN KEY (revenueId) REFERENCES PlaceRevenue(rid)
        )''');
        await database.execute(
          'CREATE UNIQUE INDEX IF NOT EXISTS idx_placecollection_revenueId ON PlaceCollection(revenueId) WHERE revenueId IS NOT NULL',
        );

        await database.execute('''CREATE TABLE IF NOT EXISTS PlaceWorkerRecent (
          pid INTEGER NOT NULL,
          hid INTEGER NOT NULL,
          lastUsedMs INTEGER NOT NULL,
          PRIMARY KEY (pid, hid),
          FOREIGN KEY (hid) REFERENCES Human(hid),
          FOREIGN KEY (pid) REFERENCES Place(pid)
        )''');

        await database.execute('''CREATE TABLE IF NOT EXISTS ScheduleMemo (
          sid INTEGER PRIMARY KEY AUTOINCREMENT,
          taskDate TEXT NOT NULL,
          taskTime TEXT NOT NULL DEFAULT '',
          title TEXT NOT NULL,
          memo TEXT NOT NULL DEFAULT '',
          done INTEGER NOT NULL DEFAULT 0,
          alarmEnabled INTEGER NOT NULL DEFAULT 0,
          alarmOffsetMinutes INTEGER NOT NULL DEFAULT 0,
          sortOrder INTEGER NOT NULL DEFAULT 0,
          createdAtMs INTEGER NOT NULL DEFAULT 0
        )''');
        await database.execute(
          'CREATE INDEX IF NOT EXISTS idx_schedulememo_taskDate ON ScheduleMemo(taskDate)',
        );

        await database.execute('''CREATE TABLE IF NOT EXISTS PlacePhotoGroup (
          pgid INTEGER PRIMARY KEY AUTOINCREMENT,
          pid INTEGER NOT NULL,
          photoDate TEXT NOT NULL,
          title TEXT NOT NULL DEFAULT '',
          sortOrder INTEGER NOT NULL DEFAULT 0,
          createdAtMs INTEGER NOT NULL DEFAULT 0,
          FOREIGN KEY (pid) REFERENCES Place(pid)
        )''');
        await database.execute(
          'CREATE INDEX IF NOT EXISTS idx_placephotogroup_pid_date ON PlacePhotoGroup(pid, photoDate)',
        );

        await database.execute('''CREATE TABLE IF NOT EXISTS PlacePhoto (
          phid INTEGER PRIMARY KEY AUTOINCREMENT,
          pgid INTEGER NOT NULL,
          photoUrl TEXT NOT NULL,
          originalName TEXT DEFAULT '',
          sortOrder INTEGER NOT NULL DEFAULT 0,
          createdAtMs INTEGER NOT NULL DEFAULT 0,
          FOREIGN KEY (pgid) REFERENCES PlacePhotoGroup(pgid)
        )''');
        await database.execute(
          'CREATE INDEX IF NOT EXISTS idx_placephoto_pgid_order ON PlacePhoto(pgid, sortOrder)',
        );
      },
      onUpgrade: (database, oldVersion, newVersion) async {
        if (oldVersion < 3) {
          await database.execute(
              'ALTER TABLE Place ADD COLUMN prevenue INTEGER DEFAULT 0');

          await database.execute('''CREATE TABLE IF NOT EXISTS PlaceRevenue (
            rid INTEGER PRIMARY KEY AUTOINCREMENT,
            rpid INTEGER,
            rname TEXT,
            rorder INTEGER,
            rprice INTEGER,
            rdate TEXT DEFAULT '',
            FOREIGN KEY (rpid) REFERENCES Place(pid)
          )''');
        }

        if (oldVersion < 4) {
          await database.execute(
              'ALTER TABLE Human ADD COLUMN hdailyWage INTEGER DEFAULT 0');

          await database.execute('''CREATE TABLE IF NOT EXISTS PlaceWorkDay (
            pwdid INTEGER PRIMARY KEY AUTOINCREMENT,
            pid INTEGER,
            hid INTEGER,
            workDate TEXT,
            dailyWage INTEGER DEFAULT 0,
            paid INTEGER DEFAULT 0,
            FOREIGN KEY (hid) REFERENCES Human(hid),
            FOREIGN KEY (pid) REFERENCES Place(pid)
          )''');

          // 기존 WorkCost 데이터를 PlaceWorkDay로 이관 (일당 스냅샷 + 지급여부)
          // - WorkCost.wcomplete: 0(미지급) / 1(지급완료) → PlaceWorkDay.paid로 매핑
          // - WorkCost.wprice → PlaceWorkDay.dailyWage로 스냅샷 저장
          await database.execute('''
            INSERT INTO PlaceWorkDay (pid, hid, workDate, dailyWage, paid)
            SELECT
              wpid AS pid,
              whid AS hid,
              SUBSTR(wdate, 1, 10) AS workDate,
              wprice AS dailyWage,
              wcomplete AS paid
            FROM WorkCost
            WHERE whid IS NOT NULL AND wpid IS NOT NULL
          ''');
        }

        if (oldVersion < 5) {
          await database.execute(
              "ALTER TABLE WorkCost ADD COLUMN wrole TEXT DEFAULT ''");
          await database.execute(
              "ALTER TABLE PlaceWorkDay ADD COLUMN workRole TEXT DEFAULT ''");
        }

        if (oldVersion < 6) {
          await database.execute(
              "ALTER TABLE Human ADD COLUMN hdefaultRole TEXT DEFAULT ''");
        }

        if (oldVersion < 7) {
          await database.execute('''CREATE TABLE IF NOT EXISTS PlaceWorkerRecent (
            pid INTEGER NOT NULL,
            hid INTEGER NOT NULL,
            lastUsedMs INTEGER NOT NULL,
            PRIMARY KEY (pid, hid),
            FOREIGN KEY (hid) REFERENCES Human(hid),
            FOREIGN KEY (pid) REFERENCES Place(pid)
          )''');
          await database.execute('''
            INSERT OR IGNORE INTO PlaceWorkerRecent (pid, hid, lastUsedMs)
            SELECT DISTINCT wpid, whid, CAST(strftime('%s', 'now') AS INTEGER) * 1000
            FROM WorkCost
            WHERE whid IS NOT NULL AND wpid IS NOT NULL
          ''');
        }

        if (oldVersion < 8) {
          await database.execute(
            'ALTER TABLE Place ADD COLUMN pcontractTotal INTEGER DEFAULT 0',
          );
        }

        if (oldVersion < 9) {
          await database.execute(
            "ALTER TABLE PlaceRevenue ADD COLUMN rdate TEXT DEFAULT ''",
          );
          // 추가수익에 날짜가 없던 기존 데이터는 현장 시작일(없으면 오늘)로 귀속시킨다.
          await database.execute('''
            UPDATE PlaceRevenue
            SET rdate = COALESCE(
              (SELECT SUBSTR(pstart, 1, 10) FROM Place WHERE Place.pid = PlaceRevenue.rpid),
              SUBSTR(strftime('%Y-%m-%d', 'now'), 1, 10)
            )
            WHERE (rdate IS NULL OR rdate = '')
          ''');
        }

        if (oldVersion < 10) {
          await database.execute(
            "ALTER TABLE Place ADD COLUMN pcontractDate TEXT DEFAULT ''",
          );
          await database.execute('''
            UPDATE Place
            SET pcontractDate = SUBSTR(pstart, 1, 10)
            WHERE (pcontractDate IS NULL OR TRIM(pcontractDate) = '')
              AND LENGTH(pstart) >= 10
          ''');

          await database.execute('''CREATE TABLE IF NOT EXISTS PlaceCollection (
            cid INTEGER PRIMARY KEY AUTOINCREMENT,
            pid INTEGER NOT NULL,
            cdate TEXT NOT NULL,
            ckind TEXT NOT NULL,
            camount INTEGER NOT NULL DEFAULT 0,
            cnote TEXT DEFAULT '',
            revenueId INTEGER,
            FOREIGN KEY (pid) REFERENCES Place(pid),
            FOREIGN KEY (revenueId) REFERENCES PlaceRevenue(rid)
          )''');
          await database.execute(
            'CREATE UNIQUE INDEX IF NOT EXISTS idx_placecollection_revenueId ON PlaceCollection(revenueId) WHERE revenueId IS NOT NULL',
          );

          await database.execute('''
            INSERT INTO PlaceCollection (pid, cdate, ckind, camount, cnote, revenueId)
            SELECT
              r.rpid,
              CASE
                WHEN LENGTH(TRIM(COALESCE(r.rdate, ''))) >= 10 THEN SUBSTR(r.rdate, 1, 10)
                ELSE COALESCE(
                  (SELECT SUBSTR(pstart, 1, 10) FROM Place p WHERE p.pid = r.rpid),
                  SUBSTR(strftime('%Y-%m-%d', 'now'), 1, 10)
                )
              END,
              CASE WHEN LENGTH(TRIM(COALESCE(r.rname, ''))) > 0 THEN TRIM(r.rname) ELSE '추가수익' END,
              r.rprice,
              '',
              r.rid
            FROM PlaceRevenue r
          ''');

          await database.execute('''
            INSERT INTO PlaceCollection (pid, cdate, ckind, camount, cnote, revenueId)
            SELECT
              p.pid,
              CASE
                WHEN LENGTH(p.pstart) >= 10 THEN SUBSTR(p.pstart, 1, 10)
                ELSE SUBSTR(strftime('%Y-%m-%d', 'now'), 1, 10)
              END,
              '선수금',
              p.prevenue,
              '이관',
              NULL
            FROM Place p
            WHERE p.prevenue > 0 AND p.pcomplete != 2
          ''');
        }

        if (oldVersion < 11) {
          await database.execute('''CREATE TABLE IF NOT EXISTS ScheduleMemo (
            sid INTEGER PRIMARY KEY AUTOINCREMENT,
            taskDate TEXT NOT NULL,
            taskTime TEXT NOT NULL DEFAULT '',
            title TEXT NOT NULL,
            memo TEXT NOT NULL DEFAULT '',
            done INTEGER NOT NULL DEFAULT 0,
            alarmEnabled INTEGER NOT NULL DEFAULT 0,
            alarmOffsetMinutes INTEGER NOT NULL DEFAULT 0,
            sortOrder INTEGER NOT NULL DEFAULT 0,
            createdAtMs INTEGER NOT NULL DEFAULT 0
          )''');
          await database.execute(
            'CREATE INDEX IF NOT EXISTS idx_schedulememo_taskDate ON ScheduleMemo(taskDate)',
          );
        }

        if (oldVersion < 12) {
          if (!await _tableHasColumn(database, 'ScheduleMemo', 'taskTime')) {
            await database.execute(
              "ALTER TABLE ScheduleMemo ADD COLUMN taskTime TEXT NOT NULL DEFAULT ''",
            );
          }
          if (!await _tableHasColumn(database, 'ScheduleMemo', 'alarmEnabled')) {
            await database.execute(
              'ALTER TABLE ScheduleMemo ADD COLUMN alarmEnabled INTEGER NOT NULL DEFAULT 0',
            );
          }
          if (!await _tableHasColumn(
              database, 'ScheduleMemo', 'alarmOffsetMinutes')) {
            await database.execute(
              'ALTER TABLE ScheduleMemo ADD COLUMN alarmOffsetMinutes INTEGER NOT NULL DEFAULT 0',
            );
          }
        }

        if (oldVersion < 13) {
          await database.execute('''CREATE TABLE IF NOT EXISTS PlacePhotoGroup (
            pgid INTEGER PRIMARY KEY AUTOINCREMENT,
            pid INTEGER NOT NULL,
            photoDate TEXT NOT NULL,
            title TEXT NOT NULL DEFAULT '',
            sortOrder INTEGER NOT NULL DEFAULT 0,
            createdAtMs INTEGER NOT NULL DEFAULT 0,
            FOREIGN KEY (pid) REFERENCES Place(pid)
          )''');
          await database.execute(
            'CREATE INDEX IF NOT EXISTS idx_placephotogroup_pid_date ON PlacePhotoGroup(pid, photoDate)',
          );

          await database.execute('''CREATE TABLE IF NOT EXISTS PlacePhoto (
            phid INTEGER PRIMARY KEY AUTOINCREMENT,
            pgid INTEGER NOT NULL,
            photoUrl TEXT NOT NULL,
            originalName TEXT DEFAULT '',
            sortOrder INTEGER NOT NULL DEFAULT 0,
            createdAtMs INTEGER NOT NULL DEFAULT 0,
            FOREIGN KEY (pgid) REFERENCES PlacePhotoGroup(pgid)
          )''');
          await database.execute(
            'CREATE INDEX IF NOT EXISTS idx_placephoto_pgid_order ON PlacePhoto(pgid, sortOrder)',
          );
        }

        if (oldVersion < 14) {
          if (!await _tableHasColumn(database, 'Place', 'paddress')) {
            await database.execute(
              "ALTER TABLE Place ADD COLUMN paddress TEXT DEFAULT ''",
            );
          }
        }
      },
    );
  }

  Future<List<PlaceInfoModel>> getAllPlaces() async {
    final Database db = await initializeDB();
    String query = '''
        SELECT
    p.*,
	COALESCE(pr.total_revenue, 0) AS totalAdditionalRevenue ,
    COALESCE(mc.total_material_cost, 0) AS mTotal,
    COALESCE(mc.total_wood_cost, 0) AS woodTotal,
    COALESCE(mc.total_metal_cost, 0) AS metalTotal,
    COALESCE(mc.total_electric_cost, 0) AS electricTotal,
    COALESCE(mc.total_lighting_cost, 0) AS lightingTotal,
    COALESCE(mc.total_cleaning_cost, 0) AS cleaningTotal,
    COALESCE(mc.total_film_cost, 0) AS filmTotal,
    COALESCE(mc.total_landscape_cost, 0) AS landscapeTotal,
    COALESCE(mc.total_hardware_cost, 0) AS hardwareTotal,
    COALESCE(mc.total_paint_cost, 0) AS paintTotal,
    COALESCE(mc.total_facility_cost, 0) AS facilityTotal,
    COALESCE(mc.total_tile_cost, 0) AS tileTotal,
    COALESCE(mc.total_glass_cost, 0) AS glassTotal,
    COALESCE(mc.total_fuel_cost, 0) AS fuelTotal,
    COALESCE(mc.total_accommodation_cost, 0) AS accommodationTotal,
    COALESCE(mc.total_food_cost, 0) AS foodTotal,
    COALESCE(mc.total_personal_expenses_cost, 0) AS personalExpensesTotal,
    COALESCE(mc.total_firefighting_cost, 0) AS firefightingTotal,
    COALESCE(mc.total_signage_cost, 0) AS signageTotal,
    COALESCE(mc.total_air_conditioning_cost, 0) AS airConditioningTotal,
    COALESCE(mc.total_demolition_cost, 0) AS demolitionTotal,
    COALESCE(mc.total_custom_made_cost, 0) AS customMadeTotal,
    COALESCE(mc.total_other_expenses_cost, 0) AS otherExpensesTotal,
    COALESCE(wc.total_work_cost, 0) AS wTotal,
    COALESCE(wc.total_incomplete_cost, 0) AS wIncomplete,
    COALESCE(wc.workerCount, 0) AS workerCount
FROM
    Place p
LEFT JOIN (
    SELECT
        mpid,
        SUM(mprice) AS total_material_cost,
        SUM(CASE WHEN mcategory = '목재' THEN mprice ELSE 0 END) AS total_wood_cost,
        SUM(CASE WHEN mcategory = '금속' THEN mprice ELSE 0 END) AS total_metal_cost,
        SUM(CASE WHEN mcategory = '전기' THEN mprice ELSE 0 END) AS total_electric_cost,
        SUM(CASE WHEN mcategory = '조명' THEN mprice ELSE 0 END) AS total_lighting_cost,
        SUM(CASE WHEN mcategory = '청소' THEN mprice ELSE 0 END) AS total_cleaning_cost,
        SUM(CASE WHEN mcategory = '필름' THEN mprice ELSE 0 END) AS total_film_cost,
        SUM(CASE WHEN mcategory = '조경' THEN mprice ELSE 0 END) AS total_landscape_cost,
        SUM(CASE WHEN mcategory = '철물' THEN mprice ELSE 0 END) AS total_hardware_cost,
        SUM(CASE WHEN mcategory = '페인트' THEN mprice ELSE 0 END) AS total_paint_cost,
        SUM(CASE WHEN mcategory = '설비' THEN mprice ELSE 0 END) AS total_facility_cost,
        SUM(CASE WHEN mcategory = '타일' THEN mprice ELSE 0 END) AS total_tile_cost,
        SUM(CASE WHEN mcategory = '유리' THEN mprice ELSE 0 END) AS total_glass_cost,
        SUM(CASE WHEN mcategory = '유류비' THEN mprice ELSE 0 END) AS total_fuel_cost,
        SUM(CASE WHEN mcategory = '숙반' THEN mprice ELSE 0 END) AS total_accommodation_cost,
        SUM(CASE WHEN mcategory = '식대' THEN mprice ELSE 0 END) AS total_food_cost,
        SUM(CASE WHEN mcategory = '개인경비' THEN mprice ELSE 0 END) AS total_personal_expenses_cost,
        SUM(CASE WHEN mcategory = '소방' THEN mprice ELSE 0 END) AS total_firefighting_cost,
        SUM(CASE WHEN mcategory = '사인물' THEN mprice ELSE 0 END) AS total_signage_cost,
        SUM(CASE WHEN mcategory = '공조' THEN mprice ELSE 0 END) AS total_air_conditioning_cost,
        SUM(CASE WHEN mcategory = '철거' THEN mprice ELSE 0 END) AS total_demolition_cost,
        SUM(CASE WHEN mcategory = '기타주문제작' THEN mprice ELSE 0 END) AS total_custom_made_cost,
        SUM(CASE WHEN mcategory = '기타경비' THEN mprice ELSE 0 END) AS total_other_expenses_cost
    FROM
        MaterialCost
    GROUP BY
        mpid
) mc ON p.pid = mc.mpid
LEFT JOIN (
    SELECT
        pid,
        SUM(dailyWage) AS total_work_cost,
        SUM(CASE WHEN paid = 0 THEN dailyWage ELSE 0 END) AS total_incomplete_cost,
        COUNT(pwd.hid) AS workerCount
    FROM
        PlaceWorkDay pwd
    JOIN
        Human h ON pwd.hid = h.hid AND h.hdelete = 0
    GROUP BY
        pid
) wc ON p.pid = wc.pid
LEFT JOIN (
    SELECT
        rpid,
        SUM(rprice) AS total_revenue  -- 새로운 JOIN 추가
    FROM
        PlaceRevenue
    GROUP BY
        rpid
) pr ON p.pid = pr.rpid;
                ''';
    final List<Map<String, Object?>> queryResults = await db.rawQuery(query);

    return queryResults.map((e) => PlaceInfoModel.fromMap(e)).toList();
  }

  Future<List<Map<String, Object?>>> getPlaceSummaryForCsv(int pid) async {
    final Database db = await initializeDB();
    String query = '''
SELECT
    COALESCE(wc.total_work_cost, 0)  + COALESCE(mc.total_material_cost, 0)  AS '총 합계금액',
    COALESCE(wc.total_work_cost, 0) AS '인건비 총계',
    COALESCE(mc.total_material_cost, 0) AS '자재비 총계',
    COALESCE(wc.workerCount, 0) AS '총 품수',
    ' ' AS ' ',
    COALESCE(mc.total_food_cost, 0) AS '식대',
    COALESCE(mc.total_accommodation_cost, 0) AS '숙박',
    COALESCE(mc.total_fuel_cost, 0) AS '유류비',
    COALESCE(mc.total_hardware_cost, 0) AS '철물',
    COALESCE(mc.total_wood_cost, 0) AS '목재',
    COALESCE(mc.total_metal_cost, 0) AS '금속',
    COALESCE(mc.total_electric_cost, 0) AS '전기',
    COALESCE(mc.total_lighting_cost, 0) AS '조명',
    COALESCE(mc.total_paint_cost, 0) AS '페인트',
    COALESCE(mc.total_facility_cost, 0) AS '설비',
    COALESCE(mc.total_tile_cost, 0) AS '타일',
    COALESCE(mc.total_air_conditioning_cost, 0) AS '공조',
    COALESCE(mc.total_firefighting_cost, 0) AS '소방',
    COALESCE(mc.total_glass_cost, 0) AS '유리',
    COALESCE(mc.total_landscape_cost, 0) AS '조경',
    COALESCE(mc.total_film_cost, 0) AS '필름',
    COALESCE(mc.total_signage_cost, 0) AS '사인물',
    COALESCE(mc.total_demolition_cost, 0) AS '철거',
    COALESCE(mc.total_cleaning_cost, 0) AS '청소',
    COALESCE(mc.total_custom_made_cost, 0) AS '기타주문제작',
    COALESCE(mc.total_other_expenses_cost, 0) AS '기타경비',
    COALESCE(mc.total_personal_expenses_cost, 0) AS '개인경비'
FROM
    Place p
    LEFT JOIN (
        SELECT 
            mpid, 
            SUM(mprice) AS total_material_cost,
            SUM(CASE WHEN mcategory = '목재' THEN mprice ELSE 0 END) AS total_wood_cost,
            SUM(CASE WHEN mcategory = '금속' THEN mprice ELSE 0 END) AS total_metal_cost,
            SUM(CASE WHEN mcategory = '전기' THEN mprice ELSE 0 END) AS total_electric_cost,
            SUM(CASE WHEN mcategory = '조명' THEN mprice ELSE 0 END) AS total_lighting_cost,
            SUM(CASE WHEN mcategory = '청소' THEN mprice ELSE 0 END) AS total_cleaning_cost,
            SUM(CASE WHEN mcategory = '필름' THEN mprice ELSE 0 END) AS total_film_cost,
            SUM(CASE WHEN mcategory = '조경' THEN mprice ELSE 0 END) AS total_landscape_cost,
            SUM(CASE WHEN mcategory = '철물' THEN mprice ELSE 0 END) AS total_hardware_cost,
            SUM(CASE WHEN mcategory = '페인트' THEN mprice ELSE 0 END) AS total_paint_cost,
            SUM(CASE WHEN mcategory = '설비' THEN mprice ELSE 0 END) AS total_facility_cost,
            SUM(CASE WHEN mcategory = '타일' THEN mprice ELSE 0 END) AS total_tile_cost,
            SUM(CASE WHEN mcategory = '유리' THEN mprice ELSE 0 END) AS total_glass_cost,
            SUM(CASE WHEN mcategory = '유류비' THEN mprice ELSE 0 END) AS total_fuel_cost,
            SUM(CASE WHEN mcategory = '숙박' THEN mprice ELSE 0 END) AS total_accommodation_cost,
            SUM(CASE WHEN mcategory = '식대' THEN mprice ELSE 0 END) AS total_food_cost,
            SUM(CASE WHEN mcategory = '개인경비' THEN mprice ELSE 0 END) AS total_personal_expenses_cost,
            SUM(CASE WHEN mcategory = '소방' THEN mprice ELSE 0 END) AS total_firefighting_cost,
            SUM(CASE WHEN mcategory = '사인물' THEN mprice ELSE 0 END) AS total_signage_cost,
            SUM(CASE WHEN mcategory = '공조' THEN mprice ELSE 0 END) AS total_air_conditioning_cost,
            SUM(CASE WHEN mcategory = '철거' THEN mprice ELSE 0 END) AS total_demolition_cost,
            SUM(CASE WHEN mcategory = '기타주문제작' THEN mprice ELSE 0 END) AS total_custom_made_cost,
            SUM(CASE WHEN mcategory = '기타경비' THEN mprice ELSE 0 END) AS total_other_expenses_cost
        FROM MaterialCost
        GROUP BY mpid
    ) mc ON p.pid = mc.mpid
    LEFT JOIN (
        SELECT
            wpid,
            SUM(wprice) AS total_work_cost,
            SUM(CASE WHEN wcomplete = 0 THEN wprice ELSE 0 END) AS total_incomplete_cost,
            COUNT(whid) AS workerCount
        FROM WorkCost wc
        JOIN Human h ON wc.whid = h.hid AND h.hdelete = 0
        GROUP BY wpid
    ) wc ON p.pid = wc.wpid
    WHERE
    p.pid = $pid;
                ''';
    final List<Map<String, Object?>> queryResults = await db.rawQuery(query);

    return queryResults;
  }

  // add Screen에서 드롭다운 검색
  Future<List<PlaceModel>> getIncompletePlaces() async {
    final Database db = await initializeDB();
    final List<Map<String, Object?>> queryResults =
        await db.rawQuery('SELECT * FROM Place WHERE pcomplete = 0;');

    return queryResults.map((e) => PlaceModel.fromMap(e)).toList();
  }

  // 캘린더 이벤트 위한 쿼리
  Future<Map<DateTime, List<String>>> getAllEvents() async {
    final Database db = await initializeDB();
    String query = '''
    SELECT p.pname AS pname,
          SUBSTR(w.wdate, 1, 10) AS dateString
    FROM WorkCost w
    LEFT JOIN Human h ON w.whid = h.hid
    JOIN Place p ON w.wpid = p.pid
    WHERE p.pcomplete != 2
    AND (w.whid IS NULL OR h.hdelete = 0)
    UNION ALL
    SELECT p.pname AS pname,
          SUBSTRING(m.mdate, 1, 10) AS dateString
    FROM materialcost m
    JOIN Place p ON m.mpid = p.pid
    WHERE p.pcomplete != 2
    ORDER BY dateString;
  ''';

    final results = await db.rawQuery(query);
    final events = <DateTime, List<String>>{};

    for (final row in results) {
      final dateString = row['dateString'] as String;
      final dateTime = DateTime.parse(dateString);
      final placeName = row['pname'] as String;

      final list = events.putIfAbsent(dateTime, () => []);
      // 캘린더의 점(마커)은 "해당 날짜에 등장하는 현장 수"로 보는 게 UX상 자연스러움.
      // 같은 현장에서 그날 지출이 여러 건이어도 점이 여러 개 찍히면 혼란스러우므로,
      // events(마커용)는 날짜별 현장명을 unique로 유지한다.
      if (!list.contains(placeName)) {
        list.add(placeName);
      }
    }

    return events;
  }

  // 인건비 세부정보 탭에서 현장별 인건비 토탈 조회
  Future<List<WorkCost2Model>> getWorkCostsByPlaceAndDate(
      int hid, DateTimeRange dateTimeRange, int pid) async {
    String query;
    final start = dateTimeRange.start;
    final endNext = dateTimeRange.end.add(const Duration(days: 1));
    final startKey =
        '${start.year}-${start.month.toString().padLeft(2, '0')}-${start.day.toString().padLeft(2, '0')}';
    final endNextKey =
        '${endNext.year}-${endNext.month.toString().padLeft(2, '0')}-${endNext.day.toString().padLeft(2, '0')}';
    final Database db = await initializeDB();
    if (pid != 0) {
      query = '''
          SELECT pwd.workDate AS wdate, pwd.dailyWage AS wprice, p.pname , pwd.paid AS wcomplete
          FROM PlaceWorkDay pwd
          JOIN Place p ON p.pid = pwd.pid
          WHERE hid = $hid AND
          pid = $pid AND
          p.pcomplete != 2 AND
          pwd.workDate >= '$startKey' AND pwd.workDate < '$endNextKey'
          ORDER BY pwd.workDate DESC
                ''';
    } else {
      query = '''
          SELECT pwd.workDate AS wdate, pwd.dailyWage AS wprice, p.pname, pwd.paid AS wcomplete
          FROM PlaceWorkDay pwd
          JOIN Place p ON p.pid = pwd.pid
          WHERE hid = $hid AND
          p.pcomplete != 2 AND
          pwd.workDate >= '$startKey' AND pwd.workDate < '$endNextKey'
          ORDER BY pwd.workDate DESC
                ''';
    }
    final List<Map<String, Object?>> queryResults = await db.rawQuery(query);

    return queryResults.map((e) => WorkCost2Model.fromMap(e)).toList();
  }

  // Future<String> findPlaceNameByPid(int pid) async {
  //   final Database db = await initializeDB();
  //   String query = '''
  //     SELECT pname FROM Place WHERE pid = $pid;
  //               ''';
  //   final List<Map<String, Object?>> queryResults = await db.rawQuery(query);

  //   if (queryResults.isNotEmpty) {
  //     return queryResults.first['pname'] as String; // 첫 번째 행의 pname 열 값을 리턴
  //   } else {
  //     return ''; // 결과가 없을 경우 빈 문자열 리턴
  //   }
  // }

  // dropdown에서 현장 검색
  Future<List<PlaceDropDownModel>> getPlacesForWorkCost(int hid) async {
    PlaceDropDownModel wholeModel = PlaceDropDownModel(pname: '전체 현장', pid: 0);
    List<PlaceDropDownModel> placeList = [wholeModel];

    final Database db = await initializeDB();
    String query = '''
      SELECT p.pname, p.pid FROM PlaceWorkDay  pwd
      JOIN Place p on  pwd.pid = p.pid
      WHERE hid = $hid
      AND p.pcomplete != 2
      group by pid
                ''';
    final List<Map<String, Object?>> queryResults = await db.rawQuery(query);

    return placeList +
        queryResults.map((e) => PlaceDropDownModel.fromMap(e)).toList();
  }

  /// 하루의 인건비, 자재비 모두 가져오는 쿼리문 (캘린더뷰)
  Future<List<TotalCostModel>> getTotalCostsByDate(DateTime dateTime) async {
    final dateKey =
        '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')}';

    // String startDate = DateTime(2020).toString();
    // String endDate = DateTime(2040).toString();

    final Database db = await initializeDB();
    String query = '''
        SELECT 
            p.pname AS pname,
            p.pcomplete AS pcomplete,
            h.hname AS name,
            w.wdate AS date,
            w.wprice AS price,
            'w' AS category,
            w.wid AS id,
            w.wcomplete AS wcomplete
        FROM WorkCost w
        JOIN Human h ON w.whid = h.hid
        JOIN Place p ON w.wpid = p.pid
        WHERE SUBSTR(w.wdate, 1, 10) = '$dateKey' 
        AND p.pcomplete != 2
        AND h.hdelete = 0
        UNION ALL
        SELECT 
              p.pname AS pname,
              p.pcomplete,
              m.mname AS name,
              m.mdate AS date,
              m.mprice AS price,
              m.mcategory AS category,
              m.mid AS id,
              -1 AS wcomplete
        FROM materialcost m
        JOIN Place p ON m.mpid = p.pid
        WHERE SUBSTRING(m.mdate, 1, 10) = '$dateKey'
        AND p.pcomplete != 2
        ORDER BY category, name;
                ''';
    final List<Map<String, Object?>> queryResults = await db.rawQuery(query);
    return queryResults.map((e) => TotalCostModel.fromMap(e)).toList();
  }

  /// 기간조회 한 현장의 인건비, 자재비 모두 가져오는 쿼리문 (현장 뷰)
  Future<List<TotalCostModel>> getTotalCostsForPlace(int pid) async {
    final Database db = await initializeDB();
    String query = '''
        SELECT p.pname AS pname,
              p.pcomplete AS pcomplete,
              h.hname AS name,
              w.wdate AS date,
              w.wprice AS price,
              'w' AS category,
              w.wid AS id,
              w.wcomplete AS wcomplete
        FROM WorkCost w
        JOIN Human h ON w.whid = h.hid
        JOIN Place p ON w.wpid = p.pid
        WHERE w.wpid = $pid
        AND h.hdelete = 0
        UNION ALL
        SELECT p.pname AS pname,
              p.pcomplete AS pcomplete,
              m.mname AS name,
              m.mdate AS date,
              m.mprice AS price,
              m.mcategory AS category,
              m.mid AS id,
              -1 AS wcomplete
        FROM materialcost m
        JOIN Place p ON m.mpid = p.pid
        WHERE m.mpid = $pid
        ORDER BY date DESC, category DESC, name;
                ''';
    final List<Map<String, Object?>> queryResults = await db.rawQuery(query);
    return queryResults.map((e) => TotalCostModel.fromMap(e)).toList();
  }

  // 사람 관리 탭 사람 정보 조회
  Future<List<HumanModel>> getAllWorkers() async {
    final Database db = await initializeDB();
    final List<Map<String, Object?>> queryResults = await db.rawQuery(
        'SELECT * FROM Human WHERE hdelete = 0 ORDER BY hstar DESC, hname');

    return queryResults.map((e) => HumanModel.fromMap(e)).toList();
  }

  /// 현장별로 투입했던 작업자(hid)를 기록한다.
  /// UX상 "칩 순서가 추가할 때마다 바뀌는 것"을 막기 위해,
  /// 이미 존재하는 (pid, hid)는 갱신하지 않는다.
  Future<void> upsertPlaceWorkerRecent(int pid, int hid) async {
    final Database db = await initializeDB();
    final ms = DateTime.now().millisecondsSinceEpoch;
    await db.rawInsert(
      '''INSERT OR IGNORE INTO PlaceWorkerRecent(pid, hid, lastUsedMs) VALUES (?, ?, ?)''',
      [pid, hid, ms],
    );
  }

  /// 해당 현장에서 일했던 인원을 "고정 순서(이름순)"로 반환한다.
  Future<List<int>> getPlaceWorkerRecentHids(int pid) async {
    final Database db = await initializeDB();
    final rows = await db.rawQuery(
      '''
      SELECT r.hid
      FROM PlaceWorkerRecent r
      JOIN Human h ON r.hid = h.hid
      WHERE r.pid = ? AND h.hdelete = 0
      ORDER BY h.hname
      ''',
      [pid],
    );
    return rows.map((e) => e['hid'] as int).toList();
  }

  Future<void> deletePlaceWorkerRecent(int pid, int hid) async {
    final Database db = await initializeDB();
    await db.rawDelete(
      'DELETE FROM PlaceWorkerRecent WHERE pid = ? AND hid = ?',
      [pid, hid],
    );
  }

  Future<List<int>> getSavedWorkDayHidsForPlaceDate({
    required int pid,
    required String dateKey, // yyyy-MM-dd
  }) async {
    final Database db = await initializeDB();
    final rows = await db.rawQuery(
      'SELECT hid FROM PlaceWorkDay WHERE pid = ? AND workDate = ?',
      [pid, dateKey],
    );
    return rows.map((e) => e['hid'] as int).toList();
  }

  Future<void> updateWorker(HumanModel humanModel) async {
    final Database db = await initializeDB();
    await db.rawUpdate(
        "update Human set hname = ?, hnumber = ?, hmemo = ?, hdailyWage = ?, hdefaultRole = ? where hid = ?",
        [
      humanModel.hname,
      humanModel.hnumber,
      humanModel.hmemo,
      humanModel.hdailyWage,
      humanModel.hdefaultRole,
      humanModel.hid,
    ]);
  }

  Future<void> toggleWorkerStarStatus(int hid, bool isStared) async {
    final Database db = await initializeDB();
    int hstar = isStared ? 1 : 0;
    await db
        .rawUpdate("UPDATE Human SET hstar = ? WHERE hid = ?", [hstar, hid]);
  }

  // 현장 추가
  Future<void> insertPlace(PlaceModel place) async {
    final Database db = await initializeDB();

    // 기존 Place 이름 조회
    final List<Map<String, dynamic>> existingPlaces =
        await db.rawQuery('SELECT pname FROM Place WHERE pcomplete != 2;');

    String newName = place.pname;
    int count = 1;

    // 기존 Place 이름과 중복되는지 확인
    while (existingPlaces.any((row) => row['pname'] == newName)) {
      newName = '${place.pname}(${count++})';
    }

    final contractDate = _contractDateKey(place.pcontractDate, place.pstart);
    final pid = await db.insert(
      'Place',
      {
        'pname': newName,
        'pstart': place.pstart,
        'pend': place.pend,
        'paddress': place.paddress,
        'pcomplete': place.pcomplete,
        'prevenue': place.prevenue,
        'pcontractTotal': place.pcontractTotal,
        'pcontractDate': contractDate,
      },
    );
    await syncAdvancePaymentCollection(
      pid: pid,
      prevenue: place.prevenue,
      pstart: place.pstart,
      pcontractDate: contractDate,
    );
  }

  //진행중 완료 수정하는 쿼리
  Future<void> updatePlaceCompletionStatus(
      int pid, int pcomplete, String endDate) async {
    final Database db = await initializeDB();
    await db.rawUpdate(
      "UPDATE Place SET pcomplete = ?, pend = ? WHERE pid = ?",
      [pcomplete, endDate, pid],
    );
  }

  // 사람 추가 (삽입된 hid 반환)
  Future<int> addWorker(HumanModel worker) async {
    final Database db = await initializeDB();
    return db.rawInsert(
      'INSERT INTO Human(hname, hnumber, hmemo, hdailyWage, hdefaultRole, hstar) VALUES (?,?,?,?,?,?)',
      [
        worker.hname,
        worker.hnumber, // null 허용
        worker.hmemo,
        worker.hdailyWage,
        worker.hdefaultRole,
        worker.hstar,
      ],
    );
  }

  Future<bool> addMaterialCosts(List<MaterialCostModel> mCostList) async {
    final Database db = await initializeDB();
    bool isSuccess = true;
    try {
      for (var mCost in mCostList) {
        await db.rawInsert(
          'INSERT INTO MaterialCost(mpid, mprice, mname, mdate, mcategory) VALUES (?,?,?,?,?)',
          [
            mCost.mpid,
            mCost.mprice,
            mCost.mname,
            mCost.mdate,
            mCost.mcategory,
          ],
        );
      }
    } catch (e) {
      isSuccess = false;
    }
    return isSuccess;
  }

  Future<bool> addWorkCosts(List<WorkCostModel> wCostList) async {
    final Database db = await initializeDB();
    bool isSuccess = true;
    try {
      for (var wCost in wCostList) {
        await db.rawInsert(
          'INSERT INTO WorkCost(wpid, whid, wdate, wprice, wcomplete, wrole) VALUES (?,?,?,?,?,?)',
          [
            wCost.wpid,
            wCost.whid, // null 허용
            wCost.wdate,
            wCost.wprice,
            wCost.wcomplete,
            wCost.wrole,
          ],
        );

        // 신규 원천 테이블(PlaceWorkDay)에도 함께 저장 (호환 유지)
        await db.rawInsert(
          'INSERT INTO PlaceWorkDay(pid, hid, workDate, dailyWage, paid, workRole) VALUES (?,?,?,?,?,?)',
          [
            wCost.wpid,
            wCost.whid,
            // wdate는 DateTime.toString() 기반이므로 앞 10자리(yyyy-MM-dd)만 저장
            wCost.wdate.length >= 10 ? wCost.wdate.substring(0, 10) : wCost.wdate,
            wCost.wprice,
            wCost.wcomplete,
            wCost.wrole,
          ],
        );
      }
    } catch (e) {
      isSuccess = false;
    }
    return isSuccess;
  }

  // 사람 삭제
  Future<void> deleteWorker(int hid) async {
    final Database db = await initializeDB();
    await db.rawUpdate(
      "UPDATE Human SET hdelete = 1 WHERE hid = ?",
      [hid],
    );
  }

  // 현장 이름 변경
  Future<void> updatePlace(PlaceModel placeModel) async {
    final Database db = await initializeDB();
    final contractDate =
        _contractDateKey(placeModel.pcontractDate, placeModel.pstart);
    await db.rawUpdate(
      "UPDATE Place SET pname = ?, prevenue = ?, pcontractTotal = ?, pstart = ?, pend = ?, paddress = ?, pcontractDate = ? WHERE pid = ?",
      [
        placeModel.pname,
        placeModel.prevenue,
        placeModel.pcontractTotal,
        placeModel.pstart,
        placeModel.pend,
        placeModel.paddress,
        contractDate,
        placeModel.pid,
      ],
    );
    if (placeModel.pid != null) {
      await syncAdvancePaymentCollection(
        pid: placeModel.pid!,
        prevenue: placeModel.prevenue,
        pstart: placeModel.pstart,
        pcontractDate: contractDate,
      );
    }
  }

  // 인건비 탭에서 wid를 List로 받아와 wcomplete를 모두 1로 업데이트
  Future<void> updateWorkCostsToComplete(List<int> widList) async {
    final Database db = await initializeDB();
    if (widList.isNotEmpty) {
      String widPlaceholders = widList.join(',');
      await db.rawUpdate(
        'UPDATE WorkCost SET wcomplete = 1 WHERE wid IN ($widPlaceholders)',
      );
    }
  }

  // 자재비 수정
  Future<void> updateMaterialCostItem(MaterialCostModel materialCost) async {
    final Database db = await initializeDB();
    await db.rawUpdate(
      "UPDATE MaterialCost SET mname = ?, mprice = ?, mdate = ?, mcategory = ? WHERE mid = ?",
      [
        materialCost.mname,
        materialCost.mprice,
        materialCost.mdate,
        materialCost.mcategory,
        materialCost.mid,
      ],
    );
  }

  // 인건비 수정
  Future<void> updateWorkCostItem(WorkCostModel workCost) async {
    final Database db = await initializeDB();
    await db.rawUpdate(
      "UPDATE WorkCost SET wprice = ?, wdate = ? WHERE wid = ?",
      [
        workCost.wprice,
        workCost.wdate,
        workCost.wid,
      ],
    );
  }

  // 인건비 완료 / 미완료 변경
  Future<void> toggleWorkCostCompletionStatus(int wcomplete, int wid) async {
    final Database db = await initializeDB();
    wcomplete = wcomplete == 1 ? 0 : 1;

    await db.rawUpdate(
      "UPDATE WorkCost SET wcomplete = ? WHERE wid = ?",
      [
        wcomplete,
        wid,
      ],
    );
  }

  // 인건비 삭제
  Future<void> deleteWorkCost(int wid) async {
    final Database db = await initializeDB();
    await db.rawUpdate(
      "DELETE FROM WorkCost WHERE wid = ?",
      [wid],
    );
  }

  // 자재비 삭제
  Future<void> deleteMaterialCost(int mid) async {
    final Database db = await initializeDB();
    await db.rawUpdate(
      "DELETE FROM MaterialCost WHERE mid = ?",
      [mid],
    );
  }

  // 인건비 탭 csv 조회
  Future<List<Map<String, dynamic>>> getWorkCostDetailsForCsv(
      DateTimeRange dateTimeRange) async {
    final Database db = await initializeDB();
    final start = dateTimeRange.start;
    final endNext = dateTimeRange.end.add(const Duration(days: 1));
    final startKey =
        '${start.year}-${start.month.toString().padLeft(2, '0')}-${start.day.toString().padLeft(2, '0')}';
    final endNextKey =
        '${endNext.year}-${endNext.month.toString().padLeft(2, '0')}-${endNext.day.toString().padLeft(2, '0')}';
    String query = '''
        SELECT
          h.hname as 이름,
          p.pname as 현장,
          h.hnumber as 주민등록번호,
          pwd.workDate as 날짜,
          pwd.dailyWage as 금액,
          CAST((pwd.dailyWage * 0.967) AS INT) AS 공제금액
        FROM 
          PlaceWorkDay pwd
        JOIN 
          Human h ON pwd.hid = h.hid
        JOIN 
          Place p ON pwd.pid = p.pid
        WHERE 
          pwd.workDate >= '$startKey' AND pwd.workDate < '$endNextKey'
        AND p.pcomplete != 2
        AND h.hdelete != 1
        ORDER BY 
          h.hname, pwd.workDate;
                ''';
    final List<Map<String, Object?>> queryResults = await db.rawQuery(query);
    return queryResults;
  }

  // 인건비 탭 csv 조회
  Future<List<Map<String, dynamic>>> getWorkCostTotalsForCsv(
      DateTimeRange dateTimeRange) async {
    final Database db = await initializeDB();
    final start = dateTimeRange.start;
    final endNext = dateTimeRange.end.add(const Duration(days: 1));
    final startKey =
        '${start.year}-${start.month.toString().padLeft(2, '0')}-${start.day.toString().padLeft(2, '0')}';
    final endNextKey =
        '${endNext.year}-${endNext.month.toString().padLeft(2, '0')}-${endNext.day.toString().padLeft(2, '0')}';
    String query = '''
        SELECT
      h.hname AS 이름,
      h.hnumber AS 주민등록번호,
      SUM(pwd.dailyWage) AS 총금액,
      SUM(CAST((pwd.dailyWage * 0.967) AS INT)) AS 총공제금액
    FROM PlaceWorkDay pwd
    JOIN Human h ON pwd.hid = h.hid
    JOIN 
          Place p ON pwd.pid = p.pid
    WHERE 
          pwd.workDate >= '$startKey' AND pwd.workDate < '$endNextKey'
    AND h.hdelete != 1
    AND p.pcomplete != 2
    GROUP BY h.hname, h.hnumber
    ORDER BY h.hname, h.hnumber;
                ''';
    final List<Map<String, Object?>> queryResults = await db.rawQuery(query);
    return queryResults;
  }

  // 현장의 인건비 자재비 csv 추출
  Future<List<Map<String, dynamic>>> getPlaceTotalCostsForCsv(
      DateTimeRange dateTimeRange, int pid) async {
    final Database db = await initializeDB();
    String startDate = dateTimeRange.start.toString();
    String endDate = dateTimeRange.end.add(const Duration(days: 1)).toString();
    String query = '''
    SELECT 
        substr(w.wdate,1,10) AS 날짜,
        '인건비' AS 항목,
        h.hname AS 지출내역, 
        w.wprice AS 지출금액
		FROM 
				workcost w
		JOIN 
				Human h ON w.whid = h.hid
		JOIN
				Place p ON w.wpid = p.pid
		WHERE
				w.wdate BETWEEN '$startDate' AND '$endDate'
		AND 
				w.wpid = $pid
    AND
        h.hdelete = 0
UNION
		SELECT 
				substr(m.mdate,1,10)  AS 날짜,
				m.mcategory AS 항목,
				m.mname AS 지출내역,
				m.mprice AS 지출금액
		FROM 
				materialcost m
		JOIN 
				Place p ON m.mpid = p.pid
		WHERE 
				m.mdate BETWEEN '$startDate' AND '$endDate' 
		AND 
				m.mpid = $pid
		ORDER BY 
				날짜, 항목 DESC;
                ''';
    final List<Map<String, Object?>> queryResults = await db.rawQuery(query);
    return queryResults;
  }

  // 인건비 탭에서 조회
  Future<List<TotalWorkCostModel>> getWorkCostsByDateRange(
      DateTimeRange dateTimeRange) async {
    final start = dateTimeRange.start;
    final endNext = dateTimeRange.end.add(const Duration(days: 1));
    final startKey =
        '${start.year}-${start.month.toString().padLeft(2, '0')}-${start.day.toString().padLeft(2, '0')}';
    final endNextKey =
        '${endNext.year}-${endNext.month.toString().padLeft(2, '0')}-${endNext.day.toString().padLeft(2, '0')}';
    final Database db = await initializeDB();
    String query = '''
        SELECT
        h.hname as 이름,
        h.hid as hid,
        h.hstar as hstar,
        p.pname as 현장,
        h.hnumber as 주민등록번호,
        w.wdate as 날짜,
        p.pcomplete as pcomplete,
        w.wid as wid,
        w.wprice as 금액,
        w.wcomplete as wcomplete
        FROM WorkCost w
        JOIN Human h ON w.whid = h.hid
        JOIN Place p ON w.wpid = p.pid
        WHERE SUBSTR(w.wdate, 1, 10) >= '$startKey'
          AND SUBSTR(w.wdate, 1, 10) < '$endNextKey'
        AND h.hdelete = 0
        AND p.pcomplete != 2
        ORDER BY hstar DESC, 이름, SUBSTR(w.wdate, 1, 10);
                ''';
    final List<Map<String, Object?>> queryResults = await db.rawQuery(query);
    return queryResults.map((e) => TotalWorkCostModel.fromMap(e)).toList();
  }

  Future<List<RevenueModel>> getAllRevenues(int placeId) async {
    final Database db = await initializeDB();
    final List<Map<String, Object?>> queryResults = await db.rawQuery(
      'SELECT * FROM PlaceRevenue WHERE rpid = ? ORDER BY rdate, rorder',
      [placeId],
    );
    return queryResults.map((e) => RevenueModel.fromMap(e)).toList();
  }

  Future<void> deleteRevenue(int revenueId, int placeId) async {
    final db = await initializeDB();
    await db.delete(
      'PlaceCollection',
      where: 'revenueId = ?',
      whereArgs: [revenueId],
    );
    await db.delete(
      'PlaceRevenue',
      where: 'rid = ?',
      whereArgs: [revenueId],
    );
    await _updateRevenueOrder(placeId);
  }

  Future<void> _updateRevenueOrder(int placeId) async {
    final db = await initializeDB();
    final revenues = await db.query(
      'PlaceRevenue',
      where: 'rpid = ?',
      whereArgs: [placeId],
      orderBy: 'rid',
    );

    for (int i = 0; i < revenues.length; i++) {
      await db.update(
        'PlaceRevenue',
        {'rorder': i + 1}, // 순서를 1부터 시작하게 업데이트
        where: 'rid = ?',
        whereArgs: [revenues[i]['rid']],
      );
    }
  }

  Future<int> insertRevenue({
    required int pid,
    required int rprice,
    required String rname,
    required String rdate,
  }) async {
    final db = await initializeDB();
    final rid = await db.insert(
      'PlaceRevenue',
      {'rpid': pid, 'rprice': rprice, 'rname': rname, 'rdate': rdate},
    );
    final dateKey = rdate.length >= 10 ? rdate.substring(0, 10) : rdate;
    final kind = rname.trim().isEmpty ? '추가수익' : rname.trim();
    await db.insert('PlaceCollection', {
      'pid': pid,
      'cdate': dateKey,
      'ckind': kind,
      'camount': rprice,
      'cnote': '',
      'revenueId': rid,
    });
    await _updateRevenueOrder(pid);
    return rid;
  }

  Future<void> updateRevenue({
    required RevenueModel revenue,
    required int placeId,
  }) async {
    final db = await initializeDB();
    await db.update(
      'PlaceRevenue',
      {'rprice': revenue.rprice, 'rname': revenue.rname, 'rdate': revenue.rdate},
      where: 'rid = ?',
      whereArgs: [revenue.rid],
    );
    final dateKey = revenue.rdate.length >= 10
        ? revenue.rdate.substring(0, 10)
        : revenue.rdate;
    final kind =
        revenue.rname.trim().isEmpty ? '추가수익' : revenue.rname.trim();
    await db.update(
      'PlaceCollection',
      {
        'camount': revenue.rprice,
        'cdate': dateKey,
        'ckind': kind,
      },
      where: 'revenueId = ?',
      whereArgs: [revenue.rid],
    );
    await _updateRevenueOrder(placeId);
  }

  String _contractDateKey(String pcontractDate, String pstart) {
    final t = pcontractDate.trim();
    if (t.length >= 10) return t.substring(0, 10);
    if (pstart.length >= 10) return pstart.substring(0, 10);
    return DateTime.now().toIso8601String().substring(0, 10);
  }

  /// 선수금(Place.prevenue) ↔ `PlaceCollection` 동기화. 추가수익(rid) 행은 건드리지 않습니다.
  Future<void> syncAdvancePaymentCollection({
    required int pid,
    required int prevenue,
    required String pstart,
    required String pcontractDate,
  }) async {
    final db = await initializeDB();
    await db.delete(
      'PlaceCollection',
      where: 'pid = ? AND revenueId IS NULL AND ckind = ?',
      whereArgs: [pid, '선수금'],
    );
    if (prevenue <= 0) return;
    final dk = _contractDateKey(pcontractDate, pstart);
    await db.insert('PlaceCollection', {
      'pid': pid,
      'cdate': dk,
      'ckind': '선수금',
      'camount': prevenue,
      'cnote': '',
      'revenueId': null,
    });
  }

  /// KPI: 특정 연·월 (기본적으로 **이번 달**에 사용).
  Future<DashboardKpiSnapshot> getDashboardKpiForMonth(int year, int month) async {
    final Database db = await initializeDB();
    final ym =
        '${year.toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}';

    final contractRow = await db.rawQuery(
      '''
      SELECT COALESCE(SUM(p.pcontractTotal), 0) AS s
      FROM Place p
      WHERE p.pcomplete != 2
        AND LENGTH(COALESCE(NULLIF(TRIM(p.pcontractDate), ''), p.pstart)) >= 7
        AND SUBSTR(COALESCE(NULLIF(TRIM(p.pcontractDate), ''), p.pstart), 1, 7) = ?
      ''',
      [ym],
    );
    final colRow = await db.rawQuery(
      '''
      SELECT COALESCE(SUM(c.camount), 0) AS s
      FROM PlaceCollection c
      JOIN Place p ON p.pid = c.pid AND p.pcomplete != 2
      WHERE LENGTH(c.cdate) >= 7 AND SUBSTR(c.cdate, 1, 7) = ?
      ''',
      [ym],
    );
    final costRow = await db.rawQuery(
      '''
      SELECT COALESCE(SUM(price), 0) AS s FROM (
        SELECT pwd.dailyWage AS price
        FROM PlaceWorkDay pwd
        JOIN Human h ON pwd.hid = h.hid AND h.hdelete = 0
        JOIN Place pl ON pl.pid = pwd.pid AND pl.pcomplete != 2
        WHERE SUBSTR(pwd.workDate, 1, 7) = ?
        UNION ALL
        SELECT m.mprice AS price
        FROM MaterialCost m
        JOIN Place pl ON pl.pid = m.mpid AND pl.pcomplete != 2
        WHERE SUBSTR(m.mdate, 1, 7) = ?
      )
      ''',
      [ym, ym],
    );

    final inProg = await db.rawQuery(
      'SELECT COUNT(*) AS c FROM Place WHERE pcomplete = 0',
    );
    final done = await db.rawQuery(
      'SELECT COUNT(*) AS c FROM Place WHERE pcomplete = 1',
    );
    final outRow = await db.rawQuery('''
      SELECT COALESCE(SUM(
        CASE
          WHEN (
            p.pcontractTotal -
            COALESCE(t.coll, 0)
          ) > 0
          THEN (
            p.pcontractTotal -
            COALESCE(t.coll, 0)
          )
          ELSE 0
        END
      ), 0) AS s
      FROM Place p
      LEFT JOIN (
        SELECT
          pid,
          SUM(camount) AS coll,
          SUM(CASE WHEN ckind = '선수금' THEN camount ELSE 0 END) AS adv
        FROM PlaceCollection
        GROUP BY pid
      ) t ON t.pid = p.pid
      WHERE p.pcomplete != 2
    ''');

    final doneMarginRow = await db.rawQuery('''
      SELECT
        COUNT(*) AS cnt,
        COALESCE(SUM(p.pcontractTotal), 0) AS sum_c,
        COALESCE(SUM(
          COALESCE(col.coll, 0) -
          (COALESCE(wc.wcst, 0) + COALESCE(mc.mct, 0))
        ), 0) AS sum_p
      FROM Place p
      LEFT JOIN (
        SELECT pwd.pid AS pid, SUM(pwd.dailyWage) AS wcst
        FROM PlaceWorkDay pwd
        JOIN Human h ON pwd.hid = h.hid AND h.hdelete = 0
        GROUP BY pwd.pid
      ) wc ON wc.pid = p.pid
      LEFT JOIN (
        SELECT mpid AS pid, SUM(mprice) AS mct
        FROM MaterialCost
        GROUP BY mpid
      ) mc ON mc.pid = p.pid
      LEFT JOIN (
        SELECT
          pid,
          SUM(camount) AS coll,
          SUM(CASE WHEN ckind = '선수금' THEN camount ELSE 0 END) AS adv
        FROM PlaceCollection
        GROUP BY pid
      ) col ON col.pid = p.pid
      WHERE p.pcomplete = 1
        AND p.pcontractTotal > 0
    ''');
    final doneCnt = (doneMarginRow.first['cnt'] as int?) ?? 0;
    final sumC = (doneMarginRow.first['sum_c'] as int?) ?? 0;
    final sumP = (doneMarginRow.first['sum_p'] as int?) ?? 0;
    final doneMarginPct =
        doneCnt > 0 && sumC > 0 ? (sumP / sumC) * 100.0 : 0.0;

    return DashboardKpiSnapshot(
      year: year,
      month: month,
      monthlyContract: (contractRow.first['s'] as int?) ?? 0,
      monthlyCollection: (colRow.first['s'] as int?) ?? 0,
      monthlyCost: (costRow.first['s'] as int?) ?? 0,
      inProgressPlaces: (inProg.first['c'] as int?) ?? 0,
      completedPlaces: (done.first['c'] as int?) ?? 0,
      outstandingReceivable: (outRow.first['s'] as int?) ?? 0,
      completedSitesInKpiMonth: doneCnt,
      completedContractMarginPct: doneMarginPct,
      completedContractProfitTotal: sumP,
    );
  }

  /// 연도별 공사금액·수금·원가·현장 건수 (`fromYear`~`toYear` 포함).
  Future<List<YearlyDashboardPoint>> getYearlyDashboardPoints({
    required int fromYear,
    required int toYear,
  }) async {
    final Database db = await initializeDB();
    final fromKey = fromYear.toString().padLeft(4, '0');
    final toKey = toYear.toString().padLeft(4, '0');

    Future<Map<String, int>> qMap(String sql) async {
      final rows = await db.rawQuery(sql, [fromKey, toKey]);
      final m = <String, int>{};
      for (final r in rows) {
        final y = r['y'] as String?;
        if (y == null) continue;
        m[y] = (r['t'] as int?) ?? 0;
      }
      return m;
    }

    final contractBy = await qMap('''
      SELECT SUBSTR(COALESCE(NULLIF(TRIM(p.pcontractDate), ''), p.pstart), 1, 4) AS y,
             SUM(p.pcontractTotal) AS t
      FROM Place p
      WHERE p.pcomplete != 2
        AND LENGTH(COALESCE(NULLIF(TRIM(p.pcontractDate), ''), p.pstart)) >= 4
      GROUP BY y
      HAVING y >= ? AND y <= ?
    ''');

    final collBy = await qMap('''
      SELECT SUBSTR(c.cdate, 1, 4) AS y, SUM(c.camount) AS t
      FROM PlaceCollection c
      JOIN Place p ON p.pid = c.pid AND p.pcomplete != 2
      WHERE LENGTH(c.cdate) >= 4
      GROUP BY y
      HAVING y >= ? AND y <= ?
    ''');

    final costRows = await db.rawQuery(
      '''
      SELECT y, SUM(price) AS t
      FROM (
        SELECT SUBSTR(pwd.workDate, 1, 4) AS y, pwd.dailyWage AS price
        FROM PlaceWorkDay pwd
        JOIN Human h ON pwd.hid = h.hid AND h.hdelete = 0
        JOIN Place pl ON pl.pid = pwd.pid AND pl.pcomplete != 2
        WHERE LENGTH(pwd.workDate) >= 4
        UNION ALL
        SELECT SUBSTR(m.mdate, 1, 4) AS y, m.mprice AS price
        FROM MaterialCost m
        JOIN Place pl ON pl.pid = m.mpid AND pl.pcomplete != 2
        WHERE LENGTH(m.mdate) >= 4
      )
      GROUP BY y
      HAVING y >= ? AND y <= ?
      ''',
      [fromKey, toKey],
    );
    final costBy = <String, int>{};
    for (final r in costRows) {
      final y = r['y'] as String?;
      if (y == null) continue;
      costBy[y] = (r['t'] as int?) ?? 0;
    }

    final newRows = await db.rawQuery(
      '''
      SELECT SUBSTR(COALESCE(NULLIF(TRIM(p.pcontractDate), ''), p.pstart), 1, 4) AS y,
             COUNT(*) AS t
      FROM Place p
      WHERE p.pcomplete != 2
        AND LENGTH(COALESCE(NULLIF(TRIM(p.pcontractDate), ''), p.pstart)) >= 4
      GROUP BY y
      HAVING y >= ? AND y <= ?
      ''',
      [fromKey, toKey],
    );
    final newBy = <String, int>{};
    for (final r in newRows) {
      final y = r['y'] as String?;
      if (y == null) continue;
      newBy[y] = (r['t'] as int?) ?? 0;
    }

    final doneRows = await db.rawQuery(
      '''
      SELECT SUBSTR(p.pend, 1, 4) AS y, COUNT(*) AS t
      FROM Place p
      WHERE p.pcomplete = 1
        AND p.pend IS NOT NULL
        AND p.pend != '0'
        AND LENGTH(p.pend) >= 4
      GROUP BY y
      HAVING y >= ? AND y <= ?
      ''',
      [fromKey, toKey],
    );
    final doneBy = <String, int>{};
    for (final r in doneRows) {
      final y = r['y'] as String?;
      if (y == null) continue;
      doneBy[y] = (r['t'] as int?) ?? 0;
    }

    final marginRows = await db.rawQuery(
      '''
      SELECT
        SUBSTR(p.pend, 1, 4) AS y,
        SUM(p.pcontractTotal) AS sum_c,
        SUM(
          COALESCE(col.coll, 0) -
          (COALESCE(wc.wcst, 0) + COALESCE(mc.mct, 0))
        ) AS sum_p
      FROM Place p
      LEFT JOIN (
        SELECT pwd.pid AS pid, SUM(pwd.dailyWage) AS wcst
        FROM PlaceWorkDay pwd
        JOIN Human h ON pwd.hid = h.hid AND h.hdelete = 0
        GROUP BY pwd.pid
      ) wc ON wc.pid = p.pid
      LEFT JOIN (
        SELECT mpid AS pid, SUM(mprice) AS mct
        FROM MaterialCost
        GROUP BY mpid
      ) mc ON mc.pid = p.pid
      LEFT JOIN (
        SELECT
          pid,
          SUM(camount) AS coll,
          SUM(CASE WHEN ckind = '선수금' THEN camount ELSE 0 END) AS adv
        FROM PlaceCollection
        GROUP BY pid
      ) col ON col.pid = p.pid
      WHERE p.pcomplete = 1
        AND p.pcontractTotal > 0
        AND p.pend IS NOT NULL
        AND p.pend != '0'
        AND LENGTH(p.pend) >= 4
      GROUP BY SUBSTR(p.pend, 1, 4)
      HAVING y >= ? AND y <= ?
      ''',
      [fromKey, toKey],
    );
    final marginPctByYear = <String, double>{};
    final completedProfitByYear = <String, int>{};
    for (final r in marginRows) {
      final y = r['y'] as String?;
      if (y == null) continue;
      final sc = (r['sum_c'] as int?) ?? 0;
      final sp = (r['sum_p'] as int?) ?? 0;
      completedProfitByYear[y] = sp;
      marginPctByYear[y] = sc > 0 ? (sp / sc) * 100.0 : 0.0;
    }

    final out = <YearlyDashboardPoint>[];
    for (int y = fromYear; y <= toYear; y++) {
      final key = y.toString().padLeft(4, '0');
      out.add(
        YearlyDashboardPoint(
          year: y,
          contractTotal: contractBy[key] ?? 0,
          collectionTotal: collBy[key] ?? 0,
          costTotal: costBy[key] ?? 0,
          newProjectCount: newBy[key] ?? 0,
          completedProjectCount: doneBy[key] ?? 0,
          completedContractMarginPct: marginPctByYear[key] ?? 0.0,
          completedProfitTotal: completedProfitByYear[key] ?? 0,
        ),
      );
    }
    return out;
  }

  /// 현장별 공사금액·수금·원가·미수금 (진행/완료 현장, 삭제 제외).
  Future<List<DashboardPlaceRow>> getDashboardPlaceRows() async {
    final Database db = await initializeDB();
    final rows = await db.rawQuery('''
      SELECT
        p.pid AS pid,
        p.pname AS pname,
        p.pcontractTotal AS contractTotal,
        COALESCE(col.coll, 0) AS collected,
        COALESCE(wc.wcst, 0) + COALESCE(mc.mct, 0) AS costTotal,
        COALESCE((
          SELECT SUM(pc.camount)
          FROM PlaceCollection pc
          WHERE pc.pid = p.pid AND pc.ckind = '선수금'
        ), 0) AS advanceCollected,
        COALESCE((
          SELECT GROUP_CONCAT(entry, '\n')
          FROM (
            SELECT
              SUBSTR(pc.cdate, 1, 10) || '|' ||
              COALESCE(NULLIF(TRIM(pc.ckind), ''), '잔금') || '|' ||
              CAST(pc.camount AS TEXT) AS entry
            FROM PlaceCollection pc
            WHERE pc.pid = p.pid AND pc.ckind != '선수금'
            ORDER BY pc.cdate ASC, pc.cid ASC
          )
        ), '') AS balanceBreakdown,
        CASE
          WHEN (
            p.pcontractTotal -
            COALESCE(col.coll, 0)
          ) > 0
          THEN (
            p.pcontractTotal -
            COALESCE(col.coll, 0)
          )
          ELSE 0
        END AS outstanding
      FROM Place p
      LEFT JOIN (
        SELECT
          pid,
          SUM(camount) AS coll,
          SUM(CASE WHEN ckind = '선수금' THEN camount ELSE 0 END) AS adv
        FROM PlaceCollection
        GROUP BY pid
      ) col ON col.pid = p.pid
      LEFT JOIN (
        SELECT pwd.pid AS pid, SUM(pwd.dailyWage) AS wcst
        FROM PlaceWorkDay pwd
        JOIN Human h ON pwd.hid = h.hid AND h.hdelete = 0
        GROUP BY pwd.pid
      ) wc ON wc.pid = p.pid
      LEFT JOIN (
        SELECT mpid AS pid, SUM(mprice) AS mct
        FROM MaterialCost
        GROUP BY mpid
      ) mc ON mc.pid = p.pid
      WHERE p.pcomplete != 2
      ORDER BY outstanding DESC, p.pname
    ''');

    return rows
        .map(
          (e) => DashboardPlaceRow(
            pid: e['pid'] as int,
            pname: (e['pname'] as String?) ?? '',
            contractTotal: (e['contractTotal'] as int?) ?? 0,
            collected: (e['collected'] as int?) ?? 0,
            costTotal: (e['costTotal'] as int?) ?? 0,
            outstanding: (e['outstanding'] as int?) ?? 0,
            advanceCollected: (e['advanceCollected'] as int?) ?? 0,
            balanceBreakdown: (e['balanceBreakdown'] as String?) ?? '',
          ),
        )
        .toList();
  }

  Future<DashboardDataBundle> loadDashboardDataBundle({
    required int selectedYear,
    int? kpiYear,
    int? kpiMonth,
  }) async {
    final now = DateTime.now();
    final kpi = await getDashboardKpiForMonth(
      kpiYear ?? now.year,
      kpiMonth ?? now.month,
    );
    final monthly = await getMonthlyDashboardSummary(selectedYear);
    final fromY = selectedYear - 5;
    final yearly = await getYearlyDashboardPoints(
      fromYear: fromY,
      toYear: selectedYear,
    );
    final places = await getDashboardPlaceRows();
    return DashboardDataBundle(
      kpi: kpi,
      monthly: monthly,
      yearly: yearly,
      places: places,
    );
  }

  /// 대시보드용 월별 집계 (연도 기준).
  ///
  /// - **공사금액**: `pcontractDate`(없으면 `pstart`)가 속한 월에 `pcontractTotal` 합산
  /// - **수금**: `PlaceCollection.cdate` 월별 합산
  /// - **원가**: `PlaceWorkDay` + `MaterialCost` 발생 월 합산
  Future<List<MonthlySummaryModel>> getMonthlyDashboardSummary(int year) async {
    final Database db = await initializeDB();
    final yearKey = year.toString().padLeft(4, '0');

    final costRows = await db.rawQuery(
      '''
      SELECT ym, SUM(price) AS totalCost
      FROM (
        SELECT SUBSTR(pwd.workDate, 1, 7) AS ym, pwd.dailyWage AS price
        FROM PlaceWorkDay pwd
        JOIN Human h ON pwd.hid = h.hid AND h.hdelete = 0
        JOIN Place pl ON pl.pid = pwd.pid AND pl.pcomplete != 2
        WHERE SUBSTR(pwd.workDate, 1, 4) = ?
        UNION ALL
        SELECT SUBSTR(m.mdate, 1, 7) AS ym, m.mprice AS price
        FROM MaterialCost m
        JOIN Place pl ON pl.pid = m.mpid AND pl.pcomplete != 2
        WHERE SUBSTR(m.mdate, 1, 4) = ?
      )
      GROUP BY ym
      ''',
      [yearKey, yearKey],
    );

    final costByYm = <String, int>{};
    for (final r in costRows) {
      final ym = (r['ym'] as String?) ?? '';
      if (ym.isEmpty) continue;
      costByYm[ym] = (r['totalCost'] as int?) ?? 0;
    }

    final contractRows = await db.rawQuery(
      '''
      SELECT SUBSTR(COALESCE(NULLIF(TRIM(p.pcontractDate), ''), p.pstart), 1, 7) AS ym,
             SUM(p.pcontractTotal) AS t,
             COUNT(*) AS cnt
      FROM Place p
      WHERE p.pcomplete != 2
        AND LENGTH(COALESCE(NULLIF(TRIM(p.pcontractDate), ''), p.pstart)) >= 7
        AND SUBSTR(COALESCE(NULLIF(TRIM(p.pcontractDate), ''), p.pstart), 1, 4) = ?
      GROUP BY SUBSTR(COALESCE(NULLIF(TRIM(p.pcontractDate), ''), p.pstart), 1, 7)
      ''',
      [yearKey],
    );

    final contractByYm = <String, int>{};
    final newCountByYm = <String, int>{};
    for (final r in contractRows) {
      final ym = (r['ym'] as String?) ?? '';
      if (ym.isEmpty) continue;
      contractByYm[ym] = (r['t'] as int?) ?? 0;
      newCountByYm[ym] = (r['cnt'] as int?) ?? 0;
    }

    final collectionRows = await db.rawQuery(
      '''
      SELECT SUBSTR(c.cdate, 1, 7) AS ym, SUM(c.camount) AS t
      FROM PlaceCollection c
      JOIN Place p ON p.pid = c.pid AND p.pcomplete != 2
      WHERE SUBSTR(c.cdate, 1, 4) = ?
      GROUP BY ym
      ''',
      [yearKey],
    );

    final collectionByYm = <String, int>{};
    for (final r in collectionRows) {
      final ym = (r['ym'] as String?) ?? '';
      if (ym.isEmpty) continue;
      collectionByYm[ym] = (r['t'] as int?) ?? 0;
    }

    final completedRows = await db.rawQuery(
      '''
      SELECT SUBSTR(p.pend, 1, 7) AS ym, COUNT(*) AS cnt
      FROM Place p
      WHERE p.pcomplete = 1
        AND p.pend IS NOT NULL
        AND p.pend != '0'
        AND LENGTH(p.pend) >= 7
        AND SUBSTR(p.pend, 1, 4) = ?
      GROUP BY ym
      ''',
      [yearKey],
    );

    final completedByYm = <String, int>{};
    for (final r in completedRows) {
      final ym = (r['ym'] as String?) ?? '';
      if (ym.isEmpty) continue;
      completedByYm[ym] = (r['cnt'] as int?) ?? 0;
    }

    final marginRows = await db.rawQuery(
      '''
      SELECT
        SUBSTR(p.pend, 1, 7) AS ym,
        SUM(p.pcontractTotal) AS sum_c,
        SUM(
          COALESCE(col.coll, 0) -
          (COALESCE(wc.wcst, 0) + COALESCE(mc.mct, 0))
        ) AS sum_p
      FROM Place p
      LEFT JOIN (
        SELECT pwd.pid AS pid, SUM(pwd.dailyWage) AS wcst
        FROM PlaceWorkDay pwd
        JOIN Human h ON pwd.hid = h.hid AND h.hdelete = 0
        GROUP BY pwd.pid
      ) wc ON wc.pid = p.pid
      LEFT JOIN (
        SELECT mpid AS pid, SUM(mprice) AS mct
        FROM MaterialCost
        GROUP BY mpid
      ) mc ON mc.pid = p.pid
      LEFT JOIN (
        SELECT
          pid,
          SUM(camount) AS coll,
          SUM(CASE WHEN ckind = '선수금' THEN camount ELSE 0 END) AS adv
        FROM PlaceCollection
        GROUP BY pid
      ) col ON col.pid = p.pid
      WHERE p.pcomplete = 1
        AND p.pcontractTotal > 0
        AND p.pend IS NOT NULL
        AND p.pend != '0'
        AND LENGTH(p.pend) >= 7
        AND SUBSTR(p.pend, 1, 4) = ?
      GROUP BY SUBSTR(p.pend, 1, 7)
      ''',
      [yearKey],
    );

    final marginPctByYm = <String, double>{};
    final completedProfitByYm = <String, int>{};
    for (final r in marginRows) {
      final ym = (r['ym'] as String?) ?? '';
      if (ym.isEmpty) continue;
      final sc = (r['sum_c'] as int?) ?? 0;
      final sp = (r['sum_p'] as int?) ?? 0;
      completedProfitByYm[ym] = sp;
      marginPctByYm[ym] =
          sc > 0 ? (sp / sc) * 100.0 : 0.0;
    }

    final out = <MonthlySummaryModel>[];
    for (int m = 1; m <= 12; m++) {
      final ym = '$yearKey-${m.toString().padLeft(2, '0')}';
      out.add(
        MonthlySummaryModel(
          year: year,
          month: m,
          contractAmount: contractByYm[ym] ?? 0,
          collectionAmount: collectionByYm[ym] ?? 0,
          costAmount: costByYm[ym] ?? 0,
          newProjectCount: newCountByYm[ym] ?? 0,
          completedProjectCount: completedByYm[ym] ?? 0,
          completedContractMarginPct: marginPctByYm[ym] ?? 0.0,
          completedProfitAmount: completedProfitByYm[ym] ?? 0,
        ),
      );
    }
    return out;
  }

  // --- ScheduleMemo (상황판 일정·메모) ---

  Future<int> _nextScheduleSortOrder(String taskDate) async {
    final Database db = await initializeDB();
    final rows = await db.rawQuery(
      '''
      SELECT COALESCE(MAX(sortOrder), -1) + 1 AS n
      FROM ScheduleMemo WHERE taskDate = ?
      ''',
      [taskDate],
    );
    return (rows.first['n'] as int?) ?? 0;
  }

  Future<List<ScheduleMemoModel>> getScheduleMemosBetween(
    String dateFrom,
    String dateTo,
  ) async {
    final Database db = await initializeDB();
    final rows = await db.query(
      'ScheduleMemo',
      where: 'taskDate >= ? AND taskDate <= ?',
      whereArgs: [dateFrom, dateTo],
      orderBy: 'taskDate ASC, sortOrder ASC, sid ASC',
    );
    return rows.map((e) => ScheduleMemoModel.fromMap(e)).toList();
  }

  Future<ScheduleMemoModel?> getScheduleMemoBySid(int sid) async {
    final Database db = await initializeDB();
    final rows = await db.query(
      'ScheduleMemo',
      where: 'sid = ?',
      whereArgs: [sid],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return ScheduleMemoModel.fromMap(rows.first);
  }

  Future<int> insertScheduleMemo(ScheduleMemoModel m) async {
    final Database db = await initializeDB();
    final sort = await _nextScheduleSortOrder(m.taskDate);
    final ms = DateTime.now().millisecondsSinceEpoch;
    return db.insert('ScheduleMemo', {
      'taskDate': m.taskDate,
      'taskTime': m.taskTime,
      'title': m.title,
      'memo': m.memo,
      'done': m.done ? 1 : 0,
      'alarmEnabled': m.alarmEnabled ? 1 : 0,
      'alarmOffsetMinutes': m.alarmOffsetMinutes,
      'sortOrder': sort,
      'createdAtMs': ms,
    });
  }

  Future<void> updateScheduleMemo(ScheduleMemoModel m) async {
    if (m.sid == null) return;
    final Database db = await initializeDB();
    await db.update(
      'ScheduleMemo',
      {
        'taskDate': m.taskDate,
        'taskTime': m.taskTime,
        'title': m.title,
        'memo': m.memo,
        'done': m.done ? 1 : 0,
        'alarmEnabled': m.alarmEnabled ? 1 : 0,
        'alarmOffsetMinutes': m.alarmOffsetMinutes,
        'sortOrder': m.sortOrder,
      },
      where: 'sid = ?',
      whereArgs: [m.sid],
    );
  }

  Future<void> deleteScheduleMemo(int sid) async {
    final Database db = await initializeDB();
    await db.delete(
      'ScheduleMemo',
      where: 'sid = ?',
      whereArgs: [sid],
    );
  }

  Future<List<PlacePhotoGroupModel>> getPlacePhotoGroups(int pid) async {
    final db = await initializeDB();
    final rows = await db.rawQuery(
      '''
      SELECT
        g.pgid,
        g.pid,
        g.photoDate,
        g.title,
        g.sortOrder,
        g.createdAtMs,
        COUNT(p.phid) AS photoCount,
        COALESCE(GROUP_CONCAT(p.photoUrl, '|||'), '') AS photoUrls
      FROM PlacePhotoGroup g
      LEFT JOIN PlacePhoto p ON p.pgid = g.pgid
      WHERE g.pid = ?
      GROUP BY g.pgid, g.pid, g.photoDate, g.title, g.sortOrder, g.createdAtMs
      ORDER BY g.photoDate DESC, g.sortOrder ASC, g.pgid DESC
      ''',
      [pid],
    );
    return rows.map((e) => PlacePhotoGroupModel.fromMap(e)).toList();
  }

  Future<void> insertPlacePhotoGroup({
    required int pid,
    required String photoDate,
    required String title,
    required List<String> photoUrls,
  }) async {
    if (photoUrls.isEmpty) return;
    final db = await initializeDB();
    final dateKey = photoDate.length >= 10 ? photoDate.substring(0, 10) : photoDate;
    final ms = DateTime.now().millisecondsSinceEpoch;
    await db.transaction((txn) async {
      final orderRow = await txn.rawQuery(
        '''
        SELECT COALESCE(MAX(sortOrder), -1) + 1 AS n
        FROM PlacePhotoGroup
        WHERE pid = ? AND photoDate = ?
        ''',
        [pid, dateKey],
      );
      final nextOrder = (orderRow.first['n'] as int?) ?? 0;
      final pgid = await txn.insert('PlacePhotoGroup', {
        'pid': pid,
        'photoDate': dateKey,
        'title': title.trim().isEmpty ? '사진 묶음' : title.trim(),
        'sortOrder': nextOrder,
        'createdAtMs': ms,
      });
      for (int i = 0; i < photoUrls.length; i++) {
        final url = photoUrls[i].trim();
        if (url.isEmpty) continue;
        await txn.insert('PlacePhoto', {
          'pgid': pgid,
          'photoUrl': url,
          'originalName': '',
          'sortOrder': i,
          'createdAtMs': ms,
        });
      }
    });
  }

  Future<void> deletePlacePhotoGroup(int pgid) async {
    final db = await initializeDB();
    await db.transaction((txn) async {
      await txn.delete(
        'PlacePhoto',
        where: 'pgid = ?',
        whereArgs: [pgid],
      );
      await txn.delete(
        'PlacePhotoGroup',
        where: 'pgid = ?',
        whereArgs: [pgid],
      );
    });
  }

  Future<bool> _tableHasColumn(
    Database database,
    String tableName,
    String columnName,
  ) async {
    final rows = await database.rawQuery('PRAGMA table_info($tableName)');
    for (final row in rows) {
      if ((row['name'] as String?) == columnName) {
        return true;
      }
    }
    return false;
  }
}
