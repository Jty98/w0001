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
import 'package:w0001/domain/place_archive.dart';
import 'package:w0001/domain/repository/place_abst.dart';
import 'package:w0001/domain/repository/super_admin_remote_abst.dart';
import 'package:w0001/data/datasources/remote/list_query.dart';
import 'package:w0001/data/model/paged_result.dart';
import 'package:w0001/data/repository/remote_entity_lookup.dart';
import 'package:w0001/util/concurrent_task_runner.dart';
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

PlacePhotoEntry _photoEntryFromRead(PlacePhotoRead e) => PlacePhotoEntry(
      phid: e.phid,
      displayUrl: e.photourl,
      originalName: e.originalname,
      originalUrl: e.originalUrl,
      mediaKind: e.mediakind,
      createdByUid: e.createdByUid,
      authorDisplayName: e.uploaderDisplayName,
      memo: e.memo,
    );

bool _placePhotoMatchesType(PlacePhotoRead p, String photoType) {
  final pt = p.phototype.trim();
  if (pt.isEmpty) return true;
  return pt == photoType;
}

Future<ImageUploadResult> _uploadOneDevicePlacePhoto({
  required String path,
  required int pid,
  required int pgid,
  required String photoType,
  required String dateKey,
  required int sortOrder,
  required String memo,
  required ImageUploadCategory uploadCategory,
}) {
  if (shouldUsePlacePhotoMultipartUpload(path)) {
    return uploadLocalPlacePhotoMultipart(
      absolutePath: path,
      pid: pid,
      pgid: pgid,
      photoType: photoType,
      photoDate: dateKey,
      sortOrder: sortOrder,
      memo: memo,
    );
  }
  return uploadLocalImageFile(path, category: uploadCategory);
}

Future<void> _registerUploadedPlacePhoto({
  required PlacePhotosRemoteApi api,
  required ImageUploadResult up,
  required String path,
  required int pgid,
  required int pid,
  required String photoType,
  required String dateKey,
  required int sortOrder,
  required int createdAtMs,
  required String memo,
}) async {
  if (up.skipPlacePhotoCreate) return;
  final body = <String, dynamic>{
    ..._placePhotoCreateBodyImage(
      pgid: pgid,
      sortOrder: sortOrder,
      createdAtMs: createdAtMs,
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

Future<void> _uploadDevicePlacePhotoBatch({
  required PlacePhotosRemoteApi api,
  required int pid,
  required int pgid,
  required String photoType,
  required String dateKey,
  required int createdAtMs,
  required List<String> paths,
  List<String>? memosPerFile,
  required ImageUploadCategory uploadCategory,
}) async {
  if (paths.isEmpty) return;

  final uploads = await runWithConcurrencyLimit<ImageUploadResult>(
    List.generate(paths.length, (i) {
      final path = paths[i];
      final memo = (memosPerFile != null && i < memosPerFile.length)
          ? memosPerFile[i].trim()
          : '';
      return () => _uploadOneDevicePlacePhoto(
            path: path,
            pid: pid,
            pgid: pgid,
            photoType: photoType,
            dateKey: dateKey,
            sortOrder: i,
            memo: memo,
            uploadCategory: uploadCategory,
          );
    }),
    limit: 4,
  );

  for (var i = 0; i < uploads.length; i++) {
    final memo = (memosPerFile != null && i < memosPerFile.length)
        ? memosPerFile[i].trim()
        : '';
    await _registerUploadedPlacePhoto(
      api: api,
      up: uploads[i],
      path: paths[i],
      pgid: pgid,
      pid: pid,
      photoType: photoType,
      dateKey: dateKey,
      sortOrder: i,
      createdAtMs: createdAtMs,
      memo: memo,
    );
  }
}

Future<List<PlacePhotoGroupModel>> _mapPhotoGroupsFromReads({
  required int pid,
  required String photoType,
  required List<PlacePhotoGroupRead> groupsRaw,
  bool refreshPhotos = false,
}) async {
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

  final neededPgids =
      groupsFiltered.where((g) => g.pgid > 0).map((g) => g.pgid).toSet();
  if (neededPgids.isEmpty) return const [];

  final byGid = await _placePhotosGroupedByPgid(
    pid: pid,
    photoType: photoType,
    neededPgids: neededPgids,
    refresh: refreshPhotos,
  );

  final out = <PlacePhotoGroupModel>[];
  for (final g in groupsFiltered) {
    if (g.pgid <= 0) continue;
    var rows = List<PlacePhotoRead>.from(byGid[g.pgid] ?? const []);
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
        photos: rows.map(_photoEntryFromRead).toList(),
      ),
    );
  }
  return out;
}

Future<List<PlacePhotoGroupModel>> _placePhotoGroupsFromRestFiltered({
  required int pid,
  required String photoType,
}) async {
  final groupsApi = PlacePhotoGroupsRemoteApi(AppHttpClient.I);
  final groupsRaw = await groupsApi.list(pid: pid);
  return _mapPhotoGroupsFromReads(
    pid: pid,
    photoType: photoType,
    groupsRaw: groupsRaw,
  );
}

/// 작업자 토큰은 `GET /place-photo-groups` 가 403인 경우가 많아
/// `GET /place-photos?pid=&photo_type=` 만으로 묶음을 재구성한다.
Future<List<PlacePhotoGroupModel>> _placePhotoGroupsFromPhotosOnly({
  required int pid,
  required String photoType,
  bool refreshPhotos = false,
}) async {
  final rows = await _listPlacePhotosForPid(
    pid: pid,
    photoType: photoType,
    refresh: refreshPhotos,
  );
  final byGid = <int, List<PlacePhotoRead>>{};
  for (final p in rows) {
    if (p.pgid <= 0) continue;
    final pt = p.phototype.trim();
    if (pt.isNotEmpty && pt != photoType) continue;
    byGid.putIfAbsent(p.pgid, () => []).add(p);
  }
  final out = <PlacePhotoGroupModel>[];
  for (final entry in byGid.entries) {
    final photos = List<PlacePhotoRead>.from(entry.value)
      ..sort((a, b) => a.sortorder.compareTo(b.sortorder));
    if (photos.isEmpty) continue;
    final first = photos.first;
    final gd = first.photodate.trim();
    final dateKey = gd.length >= 10 ? gd.substring(0, 10) : gd;
    final tt = (first.title ?? '').trim();
    final titleOut = tt.isNotEmpty ? first.title! : '작업 사진';
    out.add(
      PlacePhotoGroupModel(
        pgid: entry.key,
        pid: first.pid != 0 ? first.pid : pid,
        photoDate: dateKey.isNotEmpty ? dateKey : '1970-01-01',
        photoType: photoType,
        title: titleOut,
        sortOrder: photos.map((e) => e.sortorder).reduce(
              (a, b) => a < b ? a : b,
            ),
        createdAtMs: photos.map((e) => e.createdatms).reduce(
              (a, b) => a > b ? a : b,
            ),
        photos: photos.map(_photoEntryFromRead).toList(),
      ),
    );
  }
  out.sort((a, b) {
    final c = b.photoDate.compareTo(a.photoDate);
    if (c != 0) return c;
    final s = a.sortOrder.compareTo(b.sortOrder);
    if (s != 0) return s;
    return b.pgid.compareTo(a.pgid);
  });
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

final _placePhotosListCache = <String, List<PlacePhotoRead>>{};

String _placePhotosCacheKey(int pid, String photoType) => '$pid|$photoType';

void _invalidatePlacePhotosListCacheForPid(int pid) {
  final prefix = '$pid|';
  _placePhotosListCache.removeWhere((k, _) => k.startsWith(prefix));
}

/// 묶음별 사진 목록 — 우선 `?pid=&photo_type=` 일괄 조회, 400이면 `?pgid=` 로 폴백.
Future<Map<int, List<PlacePhotoRead>>> _placePhotosGroupedByPgid({
  required int pid,
  required String photoType,
  required Set<int> neededPgids,
  bool refresh = false,
}) async {
  if (neededPgids.isEmpty) return const {};

  try {
    final allRows = await _listPlacePhotosForPid(
      pid: pid,
      photoType: photoType,
      refresh: refresh,
    );
    final byGid = <int, List<PlacePhotoRead>>{};
    for (final p in allRows) {
      if (!neededPgids.contains(p.pgid)) continue;
      byGid.putIfAbsent(p.pgid, () => []).add(p);
    }
    return byGid;
  } catch (e) {
    if (_httpStatusFrom(e) != 400) rethrow;
    debugPrint(
      '_placePhotosGroupedByPgid bulk list 400 — per-pgid fallback ($e)',
    );
  }

  final api = PlacePhotosRemoteApi(AppHttpClient.I);
  final pgids = neededPgids.toList()..sort();
  final photoLists =
      await Future.wait(pgids.map((pgid) => api.list(pgid: pgid)));
  return Map.fromIterables(pgids, photoLists);
}

Future<List<PlacePhotoRead>> _listPlacePhotosForPid({
  required int pid,
  required String photoType,
  bool refresh = false,
}) async {
  final key = _placePhotosCacheKey(pid, photoType);
  if (!refresh) {
    final cached = _placePhotosListCache[key];
    if (cached != null) return cached;
  }
  final api = PlacePhotosRemoteApi(AppHttpClient.I);
  try {
    final rows = await api.list(pid: pid, photoType: photoType);
    _placePhotosListCache[key] = rows;
    return rows;
  } catch (e) {
    if (_httpStatusFrom(e) != 400) rethrow;
    debugPrint(
        '_listPlacePhotosForPid pid+photo_type 400 — pid-only retry ($e)');
    final rows = await api.list(pid: pid);
    final filtered =
        rows.where((p) => _placePhotoMatchesType(p, photoType)).toList();
    _placePhotosListCache[key] = filtered;
    return filtered;
  }
}

class PlaceRepositoryImpl implements PlaceRepository {
  PlaceRepositoryImpl(this._sa, this._dashboard);

  final SuperAdminRemoteRepository _sa;
  final DashboardRemoteRepository _dashboard;

  @override
  Future<List<PlaceInfoModel>> getAllPlaces({
    bool managementPlacesInfoFirst = true,
    UserRole? role,
  }) {
    return _fetchAllPlacesPages(
      managementPlacesInfoFirst: managementPlacesInfoFirst,
      role: role,
    );
  }

  /// cursor로 현장 전 페이지 수집 (캘린더·피커 등 전체 목록 필요 시).
  Future<List<PlaceInfoModel>> _fetchAllPlacesPages({
    required bool managementPlacesInfoFirst,
    UserRole? role,
    ListQuery baseQuery = const ListQuery(),
  }) async {
    final all = <PlaceInfoModel>[];
    String? cursor;
    var guard = 0;
    while (guard < 500) {
      guard++;
      final q = cursor == null
          ? baseQuery.copyWith(clearCursor: true)
          : baseQuery.copyWith(cursor: cursor);
      final page = await fetchPlacesPage(
        query: q,
        managementPlacesInfoFirst: managementPlacesInfoFirst,
        role: role,
      );
      all.addAll(page.items);
      if (!page.canLoadMore) break;
      cursor = page.nextCursor!.trim();
    }
    return sortPlacesInfoByPidDesc(all);
  }

  @override
  Future<PagedResult<PlaceInfoModel>> fetchPlacesPage({
    required ListQuery query,
    bool managementPlacesInfoFirst = true,
    UserRole? role,
  }) async {
    final scopedApi = PlacesRemoteApi(AppHttpClient.I);
    if (managementPlacesInfoFirst &&
        role?.canAccessDashboardPlacesInfo == true) {
      try {
        final page = await _dashboard.placesInfoPage(query);
        return page.copyWith(items: sortPlacesInfoByPidDesc(page.items));
      } catch (_) {
        // `/dashboard/places-info` 실패 시 `GET /places`
      }
      final page = await scopedApi.listPage(query);
      final out = page.items.map(placeReadToPlaceInfoSummaryZeros).toList();
      return PagedResult(
        items: sortPlacesInfoByPidDesc(out),
        nextCursor: page.nextCursor,
        hasMore: page.hasMore,
        totalCount: page.totalCount,
      );
    }
    final page = await scopedApi.listMinePage(query);
    final out = page.items.map(placeReadToPlaceInfoSummaryZeros).toList();
    return PagedResult(
      items: sortPlacesInfoByPidDesc(out),
      nextCursor: page.nextCursor,
      hasMore: page.hasMore,
      totalCount: page.totalCount,
    );
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
  Future<void> deletePlace(int pid, {bool permanent = false}) {
    return _sa.placeDelete(pid, permanent: permanent);
  }

  @override
  Future<List<PlaceModel>> getIncompletePlaces() =>
      getPlacesForCostPicker(filter: CostPlacePickerFilter.inProgress);

  @override
  Future<List<PlaceModel>> getPlacesForCostPicker({
    required CostPlacePickerFilter filter,
  }) async {
    final all = <PlaceModel>[];
    String? cursor;
    var guard = 0;
    while (guard < 500) {
      guard++;
      final q = ListQuery(
        pcomplete: filter.pcompleteQuery,
        limit: kListPageSize,
        cursor: cursor,
      );
      final page = await fetchPlacesForCostPickerPage(
        query: q,
        filter: filter,
      );
      all.addAll(page.items);
      if (!page.canLoadMore) break;
      cursor = page.nextCursor!.trim();
    }
    return all;
  }

  @override
  Future<PagedResult<PlaceModel>> fetchPlacesForCostPickerPage({
    required ListQuery query,
    required CostPlacePickerFilter filter,
    UserRole? role,
  }) async {
    final scopedApi = PlacesRemoteApi(AppHttpClient.I);
    final mergedQuery = query.copyWith(
      pcomplete: query.pcomplete ?? filter.pcompleteQuery,
    );
    final page = role?.canAccessDashboardPlacesInfo == true
        ? await scopedApi.listPage(mergedQuery)
        : await scopedApi.listMinePage(mergedQuery);
    final items = page.items
        .where((p) => filter.matchesPlace(p.pcomplete))
        .map(placeReadToModel)
        .toList()
      ..sort((a, b) => a.pname.compareTo(b.pname));
    return PagedResult(
      items: items,
      nextCursor: page.nextCursor,
      hasMore: page.hasMore,
      totalCount: page.totalCount,
    );
  }

  @override
  Future<List<TotalCostModel>> getTotalCostsForPlace(
    int pid, {
    DateTime? from,
    DateTime? to,
  }) async {
    final ListQuery costQ;
    if (from != null && to != null) {
      costQ = listQueryForDateRange(from, to, pid: pid);
    } else {
      costQ = ListQuery(pid: pid);
    }
    final wcs = await _sa.workCostsQuery(costQ);
    final mcs = await _sa.materialCostsQuery(costQ);
    final pwdList = await _sa.placeWorkDaysQuery(costQ);
    final p0 = await _sa.placeGet(pid);
    final hMap = await loadHumanMapForHids(_sa, wcs.map((w) => w.whid));

    final pwdByKey = buildPlaceWorkDayByKey(pwdList);

    final out = <TotalCostModel>[];
    for (final w in wcs) {
      if (w.wpid != pid) continue;
      final h = hMap[w.whid];
      if (h == null || h.hdelete != 0) continue;
      final wk = w.wdate.length >= 10 ? w.wdate.substring(0, 10) : w.wdate;
      final pwd =
          pwdByKey['${w.whid}|${w.wpid}|${normalizeToIsoDateString(wk)}'];
      final role = pwd != null && pwd.workrole.trim().isNotEmpty
          ? pwd.workrole.trim()
          : w.wrole.trim();
      out.add(
        TotalCostModel(
          pname: formatPlaceDisplayName(p0.pname, pcomplete: p0.pcomplete),
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
          pname: formatPlaceDisplayName(p0.pname, pcomplete: p0.pcomplete),
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
    // CSV 추출은 목록 query/cursor 의존 대신 원본 전체를 가져온 뒤
    // 클라이언트에서 범위를 필터링해 동일명 데이터 누락 가능성을 줄인다.
    final rangeStart = DateTime(startDate.year, startDate.month, startDate.day);
    final rangeEnd = DateTime(endDate.year, endDate.month, endDate.day);
    bool inDateRange(String rawDate) {
      final key = rawDate.length >= 10 ? rawDate.substring(0, 10) : rawDate;
      final parsed = DateTime.tryParse(normalizeToIsoDateString(key));
      if (parsed == null) return true;
      final day = DateTime(parsed.year, parsed.month, parsed.day);
      return !day.isBefore(rangeStart) && !day.isAfter(rangeEnd);
    }

    final wcs = (await _sa.workCostsList())
        .where((w) => w.wpid == pid && inDateRange(w.wdate))
        .toList();
    final mcs = (await _sa.materialCostsList())
        .where((m) => m.mpid == pid && inDateRange(m.mdate))
        .toList();
    final hMap = await loadHumanMapForHids(_sa, wcs.map((w) => w.whid));

    final rows = <Map<String, dynamic>>[];
    for (final w in wcs) {
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
      final d = '${b['항목']}'.compareTo('${a['항목']}');
      if (d != 0) return d;
      final e = '${a['지출내역']}'.compareTo('${b['지출내역']}');
      if (e != 0) return e;
      return ('${a['지출금액']}').compareTo('${b['지출금액']}');
    });
    return rows;
  }

  @override
  Future<PagedResult<PlacePhotoGroupModel>> fetchPlacePhotoGroupsPage(
    int pid, {
    required String photoType,
    required ListQuery query,
  }) async {
    try {
      final groupsApi = PlacePhotoGroupsRemoteApi(AppHttpClient.I);
      // `photo_type`은 클라이언트에서 필터 — 작업자 토큰·레거시 서버와 호환.
      final page = await groupsApi.listPage(query.copyWith(pid: pid));
      final refreshPhotos =
          query.cursor == null || query.cursor!.trim().isEmpty;
      final models = await _mapPhotoGroupsFromReads(
        pid: pid,
        photoType: photoType,
        groupsRaw: page.items,
        refreshPhotos: refreshPhotos,
      );
      return PagedResult(
        items: models,
        nextCursor: page.nextCursor,
        hasMore: page.hasMore,
        totalCount: page.totalCount,
      );
    } catch (e, st) {
      debugPrint('fetchPlacePhotoGroupsPage REST $e $st');
      final code = _httpStatusFrom(e);
      if (code == 401 || code == 403) {
        try {
          final models = await _placePhotoGroupsFromPhotosOnly(
            pid: pid,
            photoType: photoType,
          );
          return PagedResult(
            items: models,
            hasMore: false,
            totalCount: models.length,
          );
        } catch (e2, st2) {
          debugPrint('fetchPlacePhotoGroupsPage photos-only $e2 $st2');
          return const PagedResult(items: [], hasMore: false);
        }
      }
      rethrow;
    }
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
      // 작업자 토큰은 `/place-photos`만 허용되는 경우가 많음.
      if (code == 401 || code == 403) {
        try {
          return await _placePhotoGroupsFromPhotosOnly(
            pid: pid,
            photoType: photoType,
          );
        } catch (e2, st2) {
          debugPrint('getPlacePhotoGroups photos-only $e2 $st2');
          return const [];
        }
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
          final rows =
              (byGid[g.pgid] ?? const []).map(_photoEntryFromRead).toList();
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
      _invalidatePlacePhotosListCacheForPid(pid);
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
    _invalidatePlacePhotosListCacheForPid(pid);
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
      await _uploadDevicePlacePhotoBatch(
        api: api,
        pid: pid,
        pgid: createdGroup.pgid,
        photoType: photoType,
        dateKey: dateKey,
        createdAtMs: ms,
        paths: paths,
        memosPerFile: memosPerFile,
        uploadCategory: uploadCategory,
      );
      _invalidatePlacePhotosListCacheForPid(pid);
      return;
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
    try {
      final api = PlacePhotosRemoteApi(AppHttpClient.I);
      await _uploadDevicePlacePhotoBatch(
        api: api,
        pid: pid,
        pgid: created.pgid,
        photoType: photoType,
        dateKey: dateKey,
        createdAtMs: ms,
        paths: paths,
        memosPerFile: memosPerFile,
        uploadCategory: uploadCategory,
      );
    } catch (e, st) {
      debugPrint('insertPlacePhotoGroupFromDeviceFiles fallback upload $e $st');
      var i = 0;
      for (final path in paths) {
        final memo = (memosPerFile != null && i < memosPerFile.length)
            ? memosPerFile[i].trim()
            : '';
        final up = await _uploadOneDevicePlacePhoto(
          path: path,
          pid: pid,
          pgid: created.pgid,
          photoType: photoType,
          dateKey: dateKey,
          sortOrder: i,
          memo: memo,
          uploadCategory: uploadCategory,
        );
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
    _invalidatePlacePhotosListCacheForPid(pid);
  }

  @override
  Future<void> deletePlacePhotoGroup(int pgid, {int? pid}) async {
    try {
      final api = PlacePhotosRemoteApi(AppHttpClient.I);
      final groupsApi = PlacePhotoGroupsRemoteApi(AppHttpClient.I);
      if (pgid < 0) {
        await api.delete(-pgid);
        if (pid != null) _invalidatePlacePhotosListCacheForPid(pid);
        return;
      }
      try {
        await groupsApi.delete(pgid);
        if (pid != null) _invalidatePlacePhotosListCacheForPid(pid);
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
          _invalidatePlacePhotosListCacheForPid(pid);
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
    if (pid != null) _invalidatePlacePhotosListCacheForPid(pid);
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

  @override
  Future<Map<String, dynamic>> bulkAssignWorkforce({
    required int pid,
    required Map<String, dynamic> requestBody,
  }) async {
    print('💾 [REPOSITORY] bulkAssignWorkforce 호출');
    print('   - PID: $pid');
    print('   - Request: $requestBody');

    final startTime = DateTime.now();
    final result =
        await _sa.placeBulkAssignWorkforce(pid: pid, body: requestBody);
    final duration = DateTime.now().difference(startTime).inMilliseconds;

    print('💾 [REPOSITORY] bulkAssignWorkforce 완료: ${duration}ms');
    return result;
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull {
    final it = iterator;
    if (!it.moveNext()) return null;
    return it.current;
  }
}
