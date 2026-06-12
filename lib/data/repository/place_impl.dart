import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:w0001/access/user_role_capabilities.dart';
import 'package:w0001/data/model/auth_models.dart';
import 'package:w0001/data/datasources/remote/http_client.dart';
import 'package:w0001/data/datasources/remote/place/places_api.dart';
import 'package:w0001/data/datasources/remote/place/place_photo_groups_api.dart';
import 'package:w0001/data/datasources/remote/place/place_photos_api.dart';
import 'package:w0001/data/mappers/remote_mappers.dart';
import 'package:w0001/data/model/place_info_model.dart';
import 'package:w0001/data/model/place_model.dart';
import 'package:w0001/data/model/place_photo_entry.dart';
import 'package:w0001/data/model/place_photo_group_model.dart';
import 'package:w0001/data/model/remote/super_admin_dtos.dart';
import 'package:w0001/data/model/total_cost_model.dart';
import 'package:w0001/domain/repository/dashboard_remote_abst.dart';
import 'package:w0001/domain/cost_place_picker_filter.dart';
import 'package:w0001/domain/repository/place_abst.dart';
import 'package:w0001/domain/repository/super_admin_remote_abst.dart';
import 'package:w0001/util/funtions.dart' show normalizeToIsoDateString;
import 'package:w0001/util/image_attachment/image_upload_result.dart';
import 'package:w0001/util/image_attachment/upload_image_remote.dart';
import 'package:w0001/util/place_photo/upload_place_photo_remote.dart';

Map<String, dynamic> _placePhotoCreateBodyImage({
  required int pgid,
  required int sortOrder,
  required int createdAtMs,
  required String displayUrl,
  required String originalUrl,
  required String originalname,
  String mediakind = 'image',
}) =>
    <String, dynamic>{
      'pgid': pgid,
      'mediakind': mediakind,
      'display_url': displayUrl,
      'original_url': originalUrl,
      'originalname': originalname,
      'sortorder': sortOrder,
      'createdatms': createdAtMs,
    };

int _intCat(Map<String, int> m, String k) => m[k] ?? 0;

int? _httpStatusFrom(Object e) {
  if (e is HttpStatusException) return e.statusCode;
  if (e is DioException) return e.response?.statusCode;
  return null;
}

Future<List<PlacePhotoGroupModel>> _placePhotoGroupsFromRestFiltered({
  required int pid,
  required String photoType,
}) async {
  final groupsApi = PlacePhotoGroupsRemoteApi(AppHttpClient.I);
  final apiPhotos = PlacePhotosRemoteApi(AppHttpClient.I);
  final groupsRaw = await groupsApi.list(pid: pid);
  final groupsFiltered = groupsRaw.where((g) {
    final gType = g.phototype.trim();
    if (gType.isNotEmpty && gType != photoType) return false;
    return true;
  }).toList();
  groupsFiltered.sort((a, b) {
    final c = b.photodate.compareTo(a.photodate);
    if (c != 0) return c;
    final s = a.sortorder.compareTo(b.sortorder);
    if (s != 0) return s;
    return b.pgid.compareTo(a.pgid);
  });
  final photoLists = await Future.wait(
    groupsFiltered
        .where((g) => g.pgid > 0)
        .map((g) => apiPhotos.list(pgid: g.pgid)),
  );
  var li = 0;
  final out = <PlacePhotoGroupModel>[];
  for (final g in groupsFiltered) {
    if (g.pgid <= 0) continue;
    var rows = photoLists[li];
    li++;
    rows = rows.where((p) {
      final pt = p.phototype.trim();
      if (pt.isEmpty) return true;
      return pt == photoType;
    }).toList();
    rows.sort((a, b) => a.sortorder.compareTo(b.sortorder));
    final gd = g.photodate;
    final dateKey = gd.length >= 10 ? gd.substring(0, 10) : gd;
    final typeOut = g.phototype.trim().isNotEmpty ? g.phototype : photoType;
    final tt = g.title.trim();
    final titleOut = tt.isNotEmpty ? g.title : '작업 사진';
    out.add(
      PlacePhotoGroupModel(
        pgid: g.pgid,
        pid: g.pid != 0 ? g.pid : pid,
        photoDate: dateKey,
        photoType: typeOut,
        title: titleOut,
        sortOrder: g.sortorder,
        createdAtMs: g.createdatms,
        photos: rows
            .map(
              (e) => PlacePhotoEntry(
                phid: e.phid,
                displayUrl: e.photourl,
                originalName: e.originalname,
                createdByUid: e.createdByUid,
                authorDisplayName: e.uploaderDisplayName,
                memo: e.memo,
              ),
            )
            .toList(),
      ),
    );
  }
  return out;
}

Map<String, int> _materialCategorySums(Iterable<MaterialCostRead> rows) {
  final m = <String, int>{};
  for (final r in rows) {
    m['all'] = (m['all'] ?? 0) + r.mprice;
    m[r.mcategory] = (m[r.mcategory] ?? 0) + r.mprice;
  }
  return m;
}

class PlaceRepositoryImpl implements PlaceRepository {
  PlaceRepositoryImpl(this._sa, this._dashboard);

  final SuperAdminRemoteRepository _sa;
  final DashboardRemoteRepository _dashboard;

  @override
  Future<List<PlaceInfoModel>> getAllPlaces({
    bool managementPlacesInfoFirst = true,
    UserRole? role,
  }) async {
    final scopedApi = PlacesRemoteApi(AppHttpClient.I);
    if (managementPlacesInfoFirst && role?.canAccessDashboardPlacesInfo == true) {
      try {
        final list = await _dashboard.placesInfo();
        return sortPlacesInfoByPidDesc(list);
      } catch (_) {
        // 슈퍼관리자: `/dashboard/places-info` 실패 시 전체 `GET /places`
      }
      final places = await _sa.placesList();
      final out = places.map(placeReadToPlaceInfoSummaryZeros).toList();
      return sortPlacesInfoByPidDesc(out);
    }
    if (managementPlacesInfoFirst) {
      // 일반 관리자 — `GET /places`는 super_admin 전용일 수 있어 스코프 목록 사용
      final places = await scopedApi.listMine();
      final out = places.map(placeReadToPlaceInfoSummaryZeros).toList();
      return sortPlacesInfoByPidDesc(out);
    }
    final places = await scopedApi.listMine();
    final out = places.map(placeReadToPlaceInfoSummaryZeros).toList();
    return sortPlacesInfoByPidDesc(out);
  }

  @override
  Future<PlaceModel> insertPlace(PlaceModel place) async {
    final all = await _sa.placesList();
    final used = all.where((p) => p.pcomplete != 2).map((p) => p.pname).toSet();
    var newName = place.pname;
    var c = 1;
    while (used.contains(newName)) {
      newName = '${place.pname}($c)';
      c++;
    }
    final dkey = contractDateKey(place.pcontractDate, place.pstart);
    final body = <String, dynamic>{
      'pname': newName,
      'pstart': place.pstart,
      'pend': place.pend,
      'paddress': place.paddress,
      'pcomplete': place.pcomplete,
      'prevenue': place.prevenue,
      'pcontracttotal': place.pcontractTotal,
      'pcontractdate': dkey,
    };
    final created = await _sa.placeCreate(body);
    return placeReadToModel(created);
  }

  @override
  Future<void> updatePlace(PlaceModel placeModel) async {
    if (placeModel.pid == null) return;
    final dkey = contractDateKey(placeModel.pcontractDate, placeModel.pstart);
    await _sa.placePatch(
      placeModel.pid!,
      <String, dynamic>{
        'pname': placeModel.pname,
        'pstart': placeModel.pstart,
        'pend': placeModel.pend,
        'paddress': placeModel.paddress,
        'pcomplete': placeModel.pcomplete,
        'prevenue': placeModel.prevenue,
        'pcontracttotal': placeModel.pcontractTotal,
        'pcontractdate': dkey,
      },
    );
  }

  @override
  Future<void> updatePlaceCompletionStatus(
    int pid,
    int pcomplete,
    String endDate,
  ) {
    return _sa.placePatch(
      pid,
      <String, dynamic>{'pcomplete': pcomplete, 'pend': endDate},
    );
  }

  @override
  Future<void> deletePlace(int pid) {
    return _sa.placeDelete(pid);
  }

  @override
  Future<List<PlaceModel>> getIncompletePlaces() =>
      getPlacesForCostPicker(filter: CostPlacePickerFilter.inProgress);

  @override
  Future<List<PlaceModel>> getPlacesForCostPicker({
    required CostPlacePickerFilter filter,
  }) async {
    final all = await _sa.placesList();
    final rows = all
        .where((p) {
          if (p.pcomplete == 2) return false;
          switch (filter) {
            case CostPlacePickerFilter.all:
              return p.pcomplete == 0 || p.pcomplete == 1;
            case CostPlacePickerFilter.inProgress:
              return p.pcomplete == 0;
            case CostPlacePickerFilter.completed:
              return p.pcomplete == 1;
          }
        })
        .map(placeReadToModel)
        .toList();
    rows.sort((a, b) => a.pname.compareTo(b.pname));
    return rows;
  }

  @override
  Future<List<TotalCostModel>> getTotalCostsForPlace(int pid) async {
    final wcs = await _sa.workCostsList();
    final mcs = await _sa.materialCostsList();
    final places = await _sa.placesList();
    final humans = await _sa.humansList();
    final pwdList = await _sa.placeWorkDaysList();
    final pMap = {for (final p in places) p.pid: p};
    final hMap = {for (final h in humans) h.hid: h};
    final p0 = pMap[pid];
    if (p0 == null) return const [];

    final pwdByKey = <String, PlaceWorkDayRead>{};
    for (final pwd in pwdList) {
      if (pwd.pid != pid) continue;
      final k =
          '${pwd.hid}|${pwd.pid}|${normalizeToIsoDateString(pwd.workdate)}';
      final prev = pwdByKey[k];
      if (prev == null ||
          (prev.workrole.trim().isEmpty && pwd.workrole.trim().isNotEmpty)) {
        pwdByKey[k] = pwd;
      }
    }

    final out = <TotalCostModel>[];
    for (final w in wcs) {
      if (w.wpid != pid) continue;
      final h = hMap[w.whid];
      if (h == null || h.hdelete != 0) continue;
      final wk = w.wdate.length >= 10 ? w.wdate.substring(0, 10) : w.wdate;
      final pwd = pwdByKey['${w.whid}|${w.wpid}|${normalizeToIsoDateString(wk)}'];
      final role = pwd != null && pwd.workrole.trim().isNotEmpty
          ? pwd.workrole.trim()
          : w.wrole.trim();
      out.add(
        TotalCostModel(
          pname: p0.pname,
          pcomplete: p0.pcomplete,
          name: h.hname,
          date: w.wdate,
          price: w.wprice,
          category: 'w',
          id: w.wid,
          wcomplete: w.wcomplete,
          wcompletedAt: w.wcompletedAt,
          whid: w.whid,
          wpid: w.wpid,
          workrole: role,
        ),
      );
    }
    for (final m in mcs) {
      if (m.mpid != pid) continue;
      out.add(
        TotalCostModel(
          pname: p0.pname,
          pcomplete: p0.pcomplete,
          name: m.mname,
          date: m.mdate,
          price: m.mprice,
          category: m.mcategory,
          id: m.mid,
          wcomplete: -1,
        ),
      );
    }
    out.sort((a, b) {
      final c = b.date.compareTo(a.date);
      if (c != 0) return c;
      final d = b.category.compareTo(a.category);
      if (d != 0) return d;
      return a.name.compareTo(b.name);
    });
    return out;
  }

  @override
  Future<List<Map<String, dynamic>>> getPlaceSummaryForCsv(int pid) async {
    final places = await _sa.placesList();
    final p0 = places.where((p) => p.pid == pid).firstOrNull;
    if (p0 == null) return [<String, dynamic>{}];

    final materials =
        (await _sa.materialCostsList()).where((m) => m.mpid == pid);
    final cat = _materialCategorySums(materials);

    final wcs = (await _sa.workCostsList()).where((w) => w.wpid == pid);
    final humans = await _sa.humansList();
    final hMap = {for (final h in humans) h.hid: h};

    var totalW = 0;
    var workerCount = 0;
    for (final w in wcs) {
      final h = hMap[w.whid];
      if (h == null || h.hdelete != 0) continue;
      totalW += w.wprice;
      workerCount += 1;
    }

    return [
      <String, dynamic>{
        '총 합계금액': totalW + (cat['all'] ?? 0),
        '인건비 총계': totalW,
        '자재비 총계': cat['all'] ?? 0,
        '총 품수': workerCount,
        ' ': ' ',
        '식대': _intCat(cat, '식대'),
        '숙박': _intCat(cat, '숙박'),
        '유류비': _intCat(cat, '유류비'),
        '철물': _intCat(cat, '철물'),
        '목재': _intCat(cat, '목재'),
        '금속': _intCat(cat, '금속'),
        '전기': _intCat(cat, '전기'),
        '조명': _intCat(cat, '조명'),
        '페인트': _intCat(cat, '페인트'),
        '설비': _intCat(cat, '설비'),
        '타일': _intCat(cat, '타일'),
        '공조': _intCat(cat, '공조'),
        '소방': _intCat(cat, '소방'),
        '유리': _intCat(cat, '유리'),
        '조경': _intCat(cat, '조경'),
        '필름': _intCat(cat, '필름'),
        '사인물': _intCat(cat, '사인물'),
        '철거': _intCat(cat, '철거'),
        '청소': _intCat(cat, '청소'),
        '기타주문제작': _intCat(cat, '기타주문제작'),
        '기타경비': _intCat(cat, '기타경비'),
        '개인경비': _intCat(cat, '개인경비'),
      },
    ];
  }

  @override
  Future<List<Map<String, dynamic>>> getPlaceTotalCostsForCsv(
    DateTime startDate,
    DateTime endDate,
    int pid,
  ) async {
    final endN = endDate.add(const Duration(days: 1));
    final wcs = (await _sa.workCostsList()).where((w) => w.wpid == pid);
    final mcs = (await _sa.materialCostsList()).where((m) => m.mpid == pid);
    final humans = await _sa.humansList();
    final hMap = {for (final h in humans) h.hid: h};

    final rows = <Map<String, dynamic>>[];
    for (final w in wcs) {
      if (!inDateRangeYmd(w.wdate, startDate, endN)) continue;
      final h = hMap[w.whid];
      if (h == null || h.hdelete != 0) continue;
      final dk = w.wdate.length >= 10 ? w.wdate.substring(0, 10) : w.wdate;
      rows.add(<String, dynamic>{
        '날짜': dk,
        '항목': '인건비',
        '지출내역': h.hname,
        '지출금액': w.wprice,
      });
    }
    for (final m in mcs) {
      if (!inDateRangeYmd(m.mdate, startDate, endN)) continue;
      final dk = m.mdate.length >= 10 ? m.mdate.substring(0, 10) : m.mdate;
      rows.add(<String, dynamic>{
        '날짜': dk,
        '항목': m.mcategory,
        '지출내역': m.mname,
        '지출금액': m.mprice,
      });
    }
    rows.sort((a, b) {
      final c = '${a['날짜']}'.compareTo('${b['날짜']}');
      if (c != 0) return c;
      return '${b['항목']}'.compareTo('${a['항목']}');
    });
    return rows;
  }

  @override
  Future<List<PlacePhotoGroupModel>> getPlacePhotoGroups(
    int pid, {
    required String photoType,
  }) async {
    try {
      return await _placePhotoGroupsFromRestFiltered(
        pid: pid,
        photoType: photoType,
      );
    } catch (e, st) {
      debugPrint('getPlacePhotoGroups REST $e $st');
      final code = _httpStatusFrom(e);
      // 작업자 토큰은 `/place-photos`만 허용되는 경우가 많음. 여기서 403이면
      // 슈퍼어드민 전용 폴백을 호출하지 않아야 "접근 권한 없음" 연쇄 오류가 나지 않는다.
      if (code == 401 || code == 403) {
        return const [];
      }
    }

    try {
      final groups = (await _sa.placePhotoGroupsList())
          .where((g) => g.pid == pid && g.phototype == photoType)
          .toList();
      groups.sort((a, b) {
        final c = b.photodate.compareTo(a.photodate);
        if (c != 0) return c;
        final s = a.sortorder.compareTo(b.sortorder);
        if (s != 0) return s;
        return b.pgid.compareTo(a.pgid);
      });
      final photos = await _sa.placePhotosList();
      final byGid = <int, List<PlacePhotoRead>>{};
      for (final p in photos) {
        byGid.putIfAbsent(p.pgid, () => []).add(p);
      }
      for (final e in byGid.values) {
        e.sort((a, b) => a.sortorder.compareTo(b.sortorder));
      }
      return groups.map(
        (g) {
          final rows = (byGid[g.pgid] ?? const [])
              .map(
                (e) => PlacePhotoEntry(
                  phid: e.phid,
                  displayUrl: e.photourl,
                  originalName: e.originalname,
                  createdByUid: e.createdByUid,
                  authorDisplayName: e.uploaderDisplayName,
                  memo: e.memo,
                ),
              )
              .toList();
          return PlacePhotoGroupModel(
            pgid: g.pgid,
            pid: g.pid,
            photoDate: g.photodate,
            photoType: g.phototype,
            title: g.title,
            sortOrder: g.sortorder,
            createdAtMs: g.createdatms,
            photos: rows,
          );
        },
      ).toList();
    } catch (e2, st2) {
      debugPrint('getPlacePhotoGroups super-admin path $e2 $st2');
      final c2 = _httpStatusFrom(e2);
      if (c2 == 401 || c2 == 403) {
        return const [];
      }
      rethrow;
    }
  }

  @override
  Future<void> insertPlacePhotoGroup({
    required int pid,
    required String photoDate,
    required String photoType,
    required String title,
    required List<String> photoUrls,
  }) async {
    if (photoUrls.isEmpty) return;
    final dateKey =
        photoDate.length >= 10 ? photoDate.substring(0, 10) : photoDate;
    final ms = DateTime.now().millisecondsSinceEpoch;
    final t = title.trim();
    final titled = t.isEmpty ? '사진 묶음' : t;

    try {
      final api = PlacePhotosRemoteApi(AppHttpClient.I);
      final groupsApi = PlacePhotoGroupsRemoteApi(AppHttpClient.I);
      final allGroups = await groupsApi.list(pid: pid);
      final sameGroups = allGroups.where((g) {
        if (g.pid != pid) return false;
        if (g.phototype != photoType) return false;
        final gd = g.photodate;
        final gdk = gd.length >= 10 ? gd.substring(0, 10) : gd;
        return gdk == dateKey;
      }).toList();
      final nextGroupSort = sameGroups.isEmpty
          ? 0
          : sameGroups.map((e) => e.sortorder).reduce((a, b) => a > b ? a : b) +
              1;
      final createdGroup = await groupsApi.create(<String, dynamic>{
        'pid': pid,
        'photodate': dateKey,
        'phototype': photoType,
        'title': titled,
        'sortorder': nextGroupSort,
        'createdatms': ms,
      });
      var i = 0;
      for (final url in photoUrls) {
        final u = url.trim();
        if (u.isEmpty) continue;
        await api.create(<String, dynamic>{
          ..._placePhotoCreateBodyImage(
            pgid: createdGroup.pgid,
            sortOrder: i,
            createdAtMs: ms,
            displayUrl: u,
            originalUrl: u,
            originalname: '',
          ),
          'pid': pid,
          'photodate': dateKey,
          'phototype': photoType,
        });
        i++;
      }
      if (i > 0) return;
    } catch (e, st) {
      debugPrint('insertPlacePhotoGroup REST $e $st');
    }

    final allG = await _sa.placePhotoGroupsList();
    final same = allG
        .where(
          (g) =>
              g.pid == pid &&
              g.photodate == dateKey &&
              g.phototype == photoType,
        )
        .toList();
    final nextOrder = same.isEmpty
        ? 0
        : (same.map((e) => e.sortorder).reduce((a, b) => a > b ? a : b) + 1);

    final created = await _sa.placePhotoGroupCreate(
      <String, dynamic>{
        'pid': pid,
        'photodate': dateKey,
        'phototype': photoType,
        'title': titled,
        'sortorder': nextOrder,
        'createdatms': ms,
      },
    );
    var i = 0;
    for (final url in photoUrls) {
      final u = url.trim();
      if (u.isEmpty) continue;
      await _sa.placePhotoCreate(
        _placePhotoCreateBodyImage(
          pgid: created.pgid,
          sortOrder: i,
          createdAtMs: ms,
          displayUrl: u,
          originalUrl: u,
          originalname: '',
        ),
      );
      i++;
    }
  }

  @override
  Future<void> insertPlacePhotoGroupFromDeviceFiles({
    required int pid,
    required String photoDate,
    required String photoType,
    required String title,
    required List<String> localFilePaths,
    List<String>? memosPerFile,
  }) async {
    final paths =
        localFilePaths.map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    if (paths.isEmpty) return;
    final dateKey =
        photoDate.length >= 10 ? photoDate.substring(0, 10) : photoDate;
    final ms = DateTime.now().millisecondsSinceEpoch;
    final t = title.trim();
    final titled = t.isEmpty ? '사진 묶음' : t;
    final uploadCategory = ImageUploadCategory.fromPlacePhotoType(photoType);

    try {
      final api = PlacePhotosRemoteApi(AppHttpClient.I);
      final groupsApi = PlacePhotoGroupsRemoteApi(AppHttpClient.I);
      final allGroups = await groupsApi.list(pid: pid);
      final sameGroups = allGroups.where((g) {
        if (g.pid != pid) return false;
        if (g.phototype != photoType) return false;
        final gd = g.photodate;
        final gdk = gd.length >= 10 ? gd.substring(0, 10) : gd;
        return gdk == dateKey;
      }).toList();
      final nextGroupSort = sameGroups.isEmpty
          ? 0
          : sameGroups.map((e) => e.sortorder).reduce((a, b) => a > b ? a : b) +
              1;
      final createdGroup = await groupsApi.create(<String, dynamic>{
        'pid': pid,
        'photodate': dateKey,
        'phototype': photoType,
        'title': titled,
        'sortorder': nextGroupSort,
        'createdatms': ms,
      });
      for (var i = 0; i < paths.length; i++) {
        final path = paths[i];
        final memo = (memosPerFile != null && i < memosPerFile.length)
            ? memosPerFile[i].trim()
            : '';
        final ImageUploadResult up;
        if (shouldUsePlacePhotoMultipartUpload(path)) {
          up = await uploadLocalPlacePhotoMultipart(
            absolutePath: path,
            pid: pid,
            pgid: createdGroup.pgid,
            photoType: photoType,
            photoDate: dateKey,
            sortOrder: i,
            memo: memo,
          );
        } else {
          up = await uploadLocalImageFile(path, category: uploadCategory);
        }
        if (up.skipPlacePhotoCreate) {
          continue;
        }
        final body = <String, dynamic>{
          ..._placePhotoCreateBodyImage(
            pgid: createdGroup.pgid,
            sortOrder: i,
            createdAtMs: ms,
            displayUrl: up.displayUrl,
            originalUrl: up.originalUrl,
            originalname: up.originalname,
            mediakind:
                shouldUsePlacePhotoMultipartUpload(path) ? 'document' : 'image',
          ),
          'pid': pid,
          'photodate': dateKey,
          'phototype': photoType,
        };
        if (memo.isNotEmpty) body['memo'] = memo;
        await api.create(body);
      }
      if (paths.isNotEmpty) return;
    } catch (e, st) {
      debugPrint('insertPlacePhotoGroupFromDeviceFiles REST $e $st');
    }

    final allG = await _sa.placePhotoGroupsList();
    final same = allG
        .where(
          (g) =>
              g.pid == pid &&
              g.photodate == dateKey &&
              g.phototype == photoType,
        )
        .toList();
    final nextOrder = same.isEmpty
        ? 0
        : (same.map((e) => e.sortorder).reduce((a, b) => a > b ? a : b) + 1);

    final created = await _sa.placePhotoGroupCreate(
      <String, dynamic>{
        'pid': pid,
        'photodate': dateKey,
        'phototype': photoType,
        'title': titled,
        'sortorder': nextOrder,
        'createdatms': ms,
      },
    );
    var i = 0;
    for (final path in paths) {
      final memo = (memosPerFile != null && i < memosPerFile.length)
          ? memosPerFile[i].trim()
          : '';
      final ImageUploadResult up;
      if (shouldUsePlacePhotoMultipartUpload(path)) {
        up = await uploadLocalPlacePhotoMultipart(
          absolutePath: path,
          pid: pid,
          pgid: created.pgid,
          photoType: photoType,
          photoDate: dateKey,
          sortOrder: i,
          memo: memo,
        );
      } else {
        up = await uploadLocalImageFile(path, category: uploadCategory);
      }
      if (!up.skipPlacePhotoCreate) {
        final body = _placePhotoCreateBodyImage(
          pgid: created.pgid,
          sortOrder: i,
          createdAtMs: ms,
          displayUrl: up.displayUrl,
          originalUrl: up.originalUrl,
          originalname: up.originalname,
          mediakind:
              shouldUsePlacePhotoMultipartUpload(path) ? 'document' : 'image',
        );
        if (memo.isNotEmpty) body['memo'] = memo;
        await _sa.placePhotoCreate(body);
      }
      i++;
    }
  }

  @override
  Future<void> deletePlacePhotoGroup(int pgid, {int? pid}) async {
    try {
      final api = PlacePhotosRemoteApi(AppHttpClient.I);
      final groupsApi = PlacePhotoGroupsRemoteApi(AppHttpClient.I);
      if (pgid < 0) {
        await api.delete(-pgid);
        return;
      }
      try {
        await groupsApi.delete(pgid);
        return;
      } catch (eG, stG) {
        final c = _httpStatusFrom(eG);
        if (c == 404) return;
        debugPrint('deletePlacePhotoGroup REST group $eG $stG');
      }
      if (pid != null) {
        final flat = await api.list(pid: pid);
        final phids = flat
            .where((p) => p.pgid == pgid && p.pgid > 0)
            .map((p) => p.phid)
            .toSet();
        for (final id in phids) {
          await api.delete(id);
        }
        if (phids.isNotEmpty) {
          try {
            await groupsApi.delete(pgid);
          } catch (_) {}
          return;
        }
      }
    } catch (e, st) {
      debugPrint('deletePlacePhotoGroup REST $e $st');
    }

    final all = await _sa.placePhotosList();
    for (final p in all.where((e) => e.pgid == pgid)) {
      await _sa.placePhotoDelete(p.phid);
    }
    await _sa.placePhotoGroupDelete(pgid);
  }

  @override
  Future<void> patchPlacePhoto(
    int phid, {
    String? memo,
    String? displayUrl,
    String? originalUrl,
    String? originalname,
  }) async {
    if (phid <= 0) return;
    final body = <String, dynamic>{};
    if (memo != null) body['memo'] = memo;
    if (displayUrl != null && displayUrl.isNotEmpty) {
      body['display_url'] = displayUrl;
    }
    if (originalUrl != null && originalUrl.isNotEmpty) {
      body['original_url'] = originalUrl;
    }
    if (originalname != null) body['originalname'] = originalname;
    if (body.isEmpty) return;
    try {
      await PlacePhotosRemoteApi(AppHttpClient.I).patch(phid, body);
      return;
    } catch (e, st) {
      debugPrint('patchPlacePhoto REST $e $st');
      final h = unwrapHttpClientException(e);
      final c = h?.statusCode ?? _httpStatusFrom(e);
      if (c == 401 || c == 403) {
        throw h ?? e;
      }
    }
    await _sa.placePhotoPatch(phid, body);
  }

  @override
  Future<void> patchPlacePhotoGroupMeta(
    int pgid, {
    String? title,
    String? photoDate,
  }) async {
    if (pgid <= 0) return;
    final body = <String, dynamic>{};
    if (title != null) body['title'] = title;
    if (photoDate != null) body['photodate'] = photoDate;
    if (body.isEmpty) return;
    try {
      await PlacePhotoGroupsRemoteApi(AppHttpClient.I).patch(pgid, body);
      return;
    } catch (e, st) {
      debugPrint('patchPlacePhotoGroupMeta REST $e $st');
      final h = unwrapHttpClientException(e);
      final c = h?.statusCode ?? _httpStatusFrom(e);
      if (c == 401 || c == 403) {
        throw h ?? e;
      }
    }
    await _sa.placePhotoGroupPatch(pgid, body);
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull {
    final it = iterator;
    if (!it.moveNext()) return null;
    return it.current;
  }
}
