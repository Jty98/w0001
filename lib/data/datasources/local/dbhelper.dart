import 'package:flutter/material.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:w0001/data/model/human_model.dart';
import 'package:w0001/data/model/materialcost_model.dart';
import 'package:w0001/data/model/place_dropdown_model.dart';
import 'package:w0001/data/model/place_info_model.dart';
import 'package:w0001/data/model/place_model.dart';
import 'package:w0001/data/model/revenue_model.dart';
import 'package:w0001/data/model/total_cost_model.dart';
import 'package:w0001/data/model/total_workcost_model.dart';
import 'package:w0001/data/model/workcost_model.dart';

class DbHelper {
  final int curruntVersion = 4;
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
          hstar INTEGER,
          hdelete INTEGER DEFAULT 0
        )''');

        // Place 테이블 생성
        await database.execute('''CREATE TABLE IF NOT EXISTS Place (
          pid INTEGER PRIMARY KEY AUTOINCREMENT,
          pname TEXT,
          pstart TEXT,
          pend TEXT,
          pcomplete INTEGER DEFAULT 0,
          prevenue INTEGER DEFAULT 0
        )''');

        // WorkCost 테이블 생성
        await database.execute('''CREATE TABLE IF NOT EXISTS WorkCost (
          wid INTEGER PRIMARY KEY AUTOINCREMENT,
          whid INTEGER,
          wdate TEXT,
          wprice INTEGER,
          wpid INTEGER,
          wcomplete INTEGER DEFAULT 0,
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
          FOREIGN KEY (rpid) REFERENCES Place(pid)
        )''');
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
          SUBSTR(pwd.workDate, 1, 10) AS dateString
    FROM PlaceWorkDay pwd
    JOIN Human h ON pwd.hid = h.hid
    JOIN Place p ON pwd.pid = p.pid
    WHERE p.pcomplete != 2
    AND h.hdelete = 0
    UNION
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

      events.putIfAbsent(dateTime, () => []).add(placeName);
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
            pwd.workDate AS date,
            pwd.dailyWage AS price,
            'w' AS category,
            pwd.pwdid AS id,
            pwd.paid AS wcomplete
        FROM PlaceWorkDay pwd
        JOIN Human h ON pwd.hid = h.hid
        JOIN Place p ON pwd.pid = p.pid
        WHERE pwd.workDate = '$dateKey' 
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
              -1 AS mcomplete
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
              pwd.workDate AS date,
              pwd.dailyWage AS price,
              'w' AS category,
              pwd.pwdid AS id,
              pwd.paid AS wcomplete
        FROM PlaceWorkDay pwd
        JOIN Human h ON pwd.hid = h.hid
        JOIN Place p ON pwd.pid = p.pid
        WHERE pwd.pid = $pid
        AND h.hdelete = 0
        UNION ALL
        SELECT p.pname AS pname,
              p.pcomplete AS pcomplete,
              m.mname AS name,
              m.mdate AS date,
              m.mprice AS price,
              m.mcategory AS category,
              m.mid AS id,
              -1 AS mcomplete
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

  Future<void> updateWorker(HumanModel humanModel) async {
    final Database db = await initializeDB();
    await db.rawUpdate(
        "update Human set hname = ?, hnumber = ?, hmemo = ?, hdailyWage = ? where hid = ?",
        [
      humanModel.hname,
      humanModel.hnumber,
      humanModel.hmemo,
      humanModel.hdailyWage,
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

    // 새로운 이름으로 Place 추가 한양아파트(1)
    await db.rawInsert(
      'INSERT INTO Place(pname, pstart, pend, pcomplete, prevenue) VALUES (?,?,?,?,?)',
      [
        newName,
        place.pstart,
        place.pend,
        place.pcomplete,
        place.prevenue,
      ],
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

  // 사람 추가
  Future<void> addWorker(HumanModel worker) async {
    final Database db = await initializeDB();
    await db.rawInsert(
      'INSERT INTO Human(hname, hnumber, hmemo, hdailyWage, hstar) VALUES (?,?,?,?,?)',
      [
        worker.hname,
        worker.hnumber, // null 허용
        worker.hmemo,
        worker.hdailyWage,
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
          'INSERT INTO WorkCost(wpid, whid, wdate, wprice, wcomplete) VALUES (?,?,?,?,?)',
          [
            wCost.wpid,
            wCost.whid, // null 허용
            wCost.wdate,
            wCost.wprice,
            wCost.wcomplete
          ],
        );

        // 신규 원천 테이블(PlaceWorkDay)에도 함께 저장 (호환 유지)
        await db.rawInsert(
          'INSERT INTO PlaceWorkDay(pid, hid, workDate, dailyWage, paid) VALUES (?,?,?,?,?)',
          [
            wCost.wpid,
            wCost.whid,
            // wdate는 DateTime.toString() 기반이므로 앞 10자리(yyyy-MM-dd)만 저장
            wCost.wdate.length >= 10 ? wCost.wdate.substring(0, 10) : wCost.wdate,
            wCost.wprice,
            wCost.wcomplete,
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
    await db.rawUpdate(
      "UPDATE Place SET pname = ?, prevenue = ? WHERE pid = ?",
      [
        placeModel.pname,
        placeModel.prevenue,
        placeModel.pid,
      ],
    );
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
        pwd.workDate as 날짜,
        p.pcomplete as pcomplete,
        pwd.pwdid as wid,
        pwd.dailyWage as 금액,
        pwd.paid as wcomplete
        FROM PlaceWorkDay pwd
        JOIN Human h ON pwd.hid = h.hid
        JOIN Place p ON pwd.pid = p.pid
        WHERE pwd.workDate >= '$startKey' AND pwd.workDate < '$endNextKey'
        AND h.hdelete = 0
        AND p.pcomplete != 2
        ORDER BY hstar DESC, 이름, pwd.workDate;
                ''';
    final List<Map<String, Object?>> queryResults = await db.rawQuery(query);
    return queryResults.map((e) => TotalWorkCostModel.fromMap(e)).toList();
  }

  Future<List<RevenueModel>> getAllRevenues(int placeId) async {
    final Database db = await initializeDB();
    final List<Map<String, Object?>> queryResults = await db.rawQuery(
      'SELECT * FROM PlaceRevenue WHERE rpid = ? ORDER BY rorder',
      [placeId],
    );
    return queryResults.map((e) => RevenueModel.fromMap(e)).toList();
  }

  Future<void> deleteRevenue(int revenueId, int placeId) async {
    final db = await initializeDB();
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

  Future<void> insertRevenue(
      {required int pid, required int rprice, required String rname}) async {
    final db = await initializeDB();
    await db.insert(
      'PlaceRevenue',
      {'rpid': pid, 'rprice': rprice, 'rname': rname},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    await _updateRevenueOrder(pid);
  }

  Future<void> updateRevenue(
      {required RevenueModel revenue, required int placeId}) async {
    final db = await initializeDB();
    await db.update(
      'PlaceRevenue',
      {'rprice': revenue.rprice, 'rname': revenue.rname},
      where: 'rid = ?',
      whereArgs: [revenue.rid],
    );
    await _updateRevenueOrder(placeId);
  }
}
