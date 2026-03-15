import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:sqflite/sqflite.dart';
import 'package:w0001/enums.dart';
import 'package:w0001/data/datasources/local/dbhelper.dart';
import 'package:w0001/data/model/place_info_model.dart';
import 'package:w0001/data/model/place_model.dart';
import 'package:w0001/util/fetch_data.dart';

class PlaceListController extends GetxController {
  @override
  void onInit() async {
    super.onInit();
    initValues();
    await fetchAllPlace();
  }

  /////////// variable ////////////////
  var dbHelper = DbHelper();
  late TextEditingController placeNameController;
  late TextEditingController placeRevenueController;
  List<PlaceInfoModel> placeList = [];
  List<PlaceInfoModel> filteredPlaceList = [];
  PlaceState placeState = PlaceState.incomplete;
  String updateText = '';

  ////////// Function /////////////
  // DB
  Future<void> fetchAllPlace() async {
    placeList = await dbHelper.getAllPlaces();
    int complete = placeState == PlaceState.complete ? 1 : 0;
    filteredPlaceList =
        placeList.where((place) => place.pcomplete.isEqual(complete)).toList();
    update();
  }

  void resetTextContoller() {
    placeNameController.text = '';
    placeRevenueController.text = '0';
    updateText = '';
  }

  Future<void> insertPlace() async {
    String revenueString = placeRevenueController.text.trim();
    revenueString = revenueString.replaceAll(RegExp(r'[,원]'), '');
    int? revenue = int.tryParse(revenueString);
    if (placeNameController.text.isEmpty) {
      updateText = '현장 이름을 입력해주세요.';
      update();
    } else if (placeRevenueController.text.isEmpty) {
      updateText = '선수금을 입력해주세요.';
      update();
    } else {
      PlaceModel place = PlaceModel(
        prevenue: revenue!,
        pname: placeNameController.text,
        pstart: DateTime.now().toString(),
        pend: '0',
        pcomplete: 0,
      );
      await dbHelper.insertPlace(place);
      fetchAllPlace();
      Get.back();
    }
  }

  void initValues() {
    placeNameController = TextEditingController();
    placeRevenueController = TextEditingController(text: 0.toString());
  }

  void stateValueChanged(value) {
    placeState = value;
    if (value == PlaceState.complete) {
      filteredPlaceList =
          placeList.where((element) => element.pcomplete == 1).toList();
    } else {
      filteredPlaceList =
          placeList.where((element) => element.pcomplete == 0).toList();
    }
    update();
  }

  Future<void> updatePcomplete(int index) async {
    int pcomplete = filteredPlaceList[index].pcomplete == 1 ? 0 : 1;
    int pid = filteredPlaceList[index].pid!;
    String endDate = pcomplete == 1 ? DateTime.now().toString() : '0';
    await dbHelper.updatePlaceCompletionStatus(pid, pcomplete, endDate);
    await fetchAllPlace();
  }

  Future<bool> updatePlace(int pid, String pname, int prevenue) async {
    if (pname == '') {
      updateText = '현장 이름을 입력해주세요.';
      update();
      return false;
    }else if (prevenue == -1) {
      updateText = '선수금을 입력해주세요.';
      update();
      return false;
    }  else {
      PlaceModel placeModel = PlaceModel(
        prevenue: prevenue,
        pname: pname,
        pcomplete: 0,
        pstart: '',
        pend: '',
        pid: pid,
      );
      await dbHelper.updatePlace(placeModel);
      fetchAllPlace();
      Get.back();
      return true;
    }
  }

  Future<void> deletePlace(int pid) async {
    await dbHelper.updatePlaceCompletionStatus(pid, 2, '0');
    fetchAllPlace();
  }

  Future<void> exportDB() async {
    try {
      // 디비 파일 경로 얻기
      String databasesPath = await getDatabasesPath();
      String path = '$databasesPath/w00001.db';

      // 디비 파일을 공유
      await Share.shareXFiles([XFile(path)], text: 'SQLite Database');
    } catch (e) {
      debugPrint(e.toString());
    }
  }

  Future<void> importUserDatabase(Database db) async {
    String? databaseFilePath =
        await FilePicker.platform.pickFiles().then((result) {
      if (result != null) {
        return result.files.single.path;
      }
      return null;
    });

    if (databaseFilePath != null) {
      // 사용자 데이터베이스 파일을 임시 파일로 복사
      Directory tempDir = await getTemporaryDirectory();
      String tempPath = join(tempDir.path, 'user_db.db');
      await File(databaseFilePath).copy(tempPath);

      // 임시 파일에서 데이터를 기존 데이터베이스로 복사
      await db.execute('ATTACH DATABASE "$tempPath" AS user_db');
      await _copyTableData(db, 'user_db');
      await db.execute('DETACH DATABASE user_db');

      // 임시 파일 삭제
      await File(tempPath).delete();
    }
  }

  Future<void> _copyTableData(Database db, String attachedDbName) async {
    // 사용자 데이터베이스에서 테이블 목록 가져오기
    List<Map<String, Object?>> tables = await db.rawQuery(
        'SELECT name FROM sqlite_master WHERE type = "table" AND name NOT LIKE "sqlite_%"');

    for (Map<String, Object?> table in tables) {
      String tableName = table['name'] as String;

      // 기존 테이블 삭제
      await db.execute('DROP TABLE IF EXISTS main.$tableName');

      // 새로운 데이터 삽입
      await db.execute('''
      CREATE TABLE main.$tableName AS
      SELECT * FROM $attachedDbName.$tableName
    ''');
    }
  }

// 버튼 클릭 이벤트 처리
  importDB() async {
    Database db = await dbHelper.initializeDB();
    await importUserDatabase(db);
    FetchData.fetchAllData();
  }
}
