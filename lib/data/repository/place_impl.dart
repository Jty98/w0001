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
import 'package:w0001/util/image_attachment/image_upload_result.dart';
import 'package:w0001/util/image_attachment/upload_image_remote.dart';

Map<String, dynamic> _placePhotoCreateBodyImage({
  required int pgid,
  required int sortOrder,
  required int createdAtMs,
  required String displayUrl,
  required String originalUrl,
  required String originalname,
}) =>
    <String, dynamic>{
      'pgid': pgid,
      'mediakind': 'image',
      'display_url': displayUrl,
      'original_url': originalUrl,
      'originalname': originalname,
      'sortorder': sortOrder,
      'createdatms': createdAtMs,
    };

int _intCat(Map<String, int> m, String k) => m[k] ?? 0;

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
  Future<List<PlaceInfoModel>> getAllPlaces() async {
    try {
      final list = await _dashboard.placesInfo();
      return sortPlacesInfoByPidDesc(list);
    } catch (_) {
      // non–super_admin 등에서 /dashboard/places-info 가 막힌 경우 GET /places 로 목록은 채움(집계 0, 상세에서 보완)
      final places = await _sa.placesList();
      final out = places.map(placeReadToPlaceInfoSummaryZeros).toList();
      return sortPlacesInfoByPidDesc(out);
    }
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
  Future<List<PlaceModel>> getIncompletePlaces() =>
      getPlacesForCostPicker(filter: CostPlacePickerFilter.inProgress);

  @override
  Future<List<PlaceModel>> getPlacesForCostPicker({
    required CostPlacePickerFilter filter,
  }) async {
    final all = await _sa.placesList();
    final rows = all.where((p) {
      if (p.pcomplete == 2) return false;
      switch (filter) {
        case CostPlacePickerFilter.all:
          return p.pcomplete == 0 || p.pcomplete == 1;
        case CostPlacePickerFilter.inProgress:
          return p.pcomplete == 0;
        case CostPlacePickerFilter.completed:
          return p.pcomplete == 1;
      }
    }).map(placeReadToModel).toList();
    rows.sort((a, b) => a.pname.compareTo(b.pname));
    return rows;
  }

  @override
  Future<List<TotalCostModel>> getTotalCostsForPlace(int pid) async {
    final wcs = await _sa.workCostsList();
    final mcs = await _sa.materialCostsList();
    final places = await _sa.placesList();
    final humans = await _sa.humansList();
    final pMap = {for (final p in places) p.pid: p};
    final hMap = {for (final h in humans) h.hid: h};
    final p0 = pMap[pid];
    if (p0 == null) return const [];

    final out = <TotalCostModel>[];
    for (final w in wcs) {
      if (w.wpid != pid) continue;
      final h = hMap[w.whid];
      if (h == null || h.hdelete != 0) continue;
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
    if (p0 == null) return [ <String, dynamic>{} ];

    final materials = (await _sa.materialCostsList()).where((m) => m.mpid == pid);
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
    return groups
        .map(
          (g) {
            final rows = (byGid[g.pgid] ?? const [])
                .map(
                  (e) => PlacePhotoEntry(
                    phid: e.phid,
                    displayUrl: e.photourl,
                    originalName: e.originalname,
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
        )
        .toList();
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
    final allG = await _sa.placePhotoGroupsList();
    final same = allG
        .where(
          (g) => g.pid == pid && g.photodate == dateKey && g.phototype == photoType,
        )
        .toList();
    final nextOrder = same.isEmpty
        ? 0
        : (same
                .map((e) => e.sortorder)
                .reduce((a, b) => a > b ? a : b) +
            1);

    final t = title.trim();
    final created = await _sa.placePhotoGroupCreate(
      <String, dynamic>{
        'pid': pid,
        'photodate': dateKey,
        'phototype': photoType,
        'title': t.isEmpty ? '사진 묶음' : t,
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
  }) async {
    final paths = localFilePaths.map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    if (paths.isEmpty) return;
    final dateKey =
        photoDate.length >= 10 ? photoDate.substring(0, 10) : photoDate;
    final ms = DateTime.now().millisecondsSinceEpoch;
    final allG = await _sa.placePhotoGroupsList();
    final same = allG
        .where(
          (g) => g.pid == pid && g.photodate == dateKey && g.phototype == photoType,
        )
        .toList();
    final nextOrder = same.isEmpty
        ? 0
        : (same
                .map((e) => e.sortorder)
                .reduce((a, b) => a > b ? a : b) +
            1);

    final t = title.trim();
    final created = await _sa.placePhotoGroupCreate(
      <String, dynamic>{
        'pid': pid,
        'photodate': dateKey,
        'phototype': photoType,
        'title': t.isEmpty ? '사진 묶음' : t,
        'sortorder': nextOrder,
        'createdatms': ms,
      },
    );
    final uploadCategory = ImageUploadCategory.fromPlacePhotoType(photoType);
    var i = 0;
    for (final path in paths) {
      final up = await uploadLocalImageFile(path, category: uploadCategory);
      await _sa.placePhotoCreate(
        _placePhotoCreateBodyImage(
          pgid: created.pgid,
          sortOrder: i,
          createdAtMs: ms,
          displayUrl: up.displayUrl,
          originalUrl: up.originalUrl,
          originalname: up.originalname,
        ),
      );
      i++;
    }
  }

  @override
  Future<void> deletePlacePhotoGroup(int pgid) async {
    final all = await _sa.placePhotosList();
    for (final p in all.where((e) => e.pgid == pgid)) {
      await _sa.placePhotoDelete(p.phid);
    }
    await _sa.placePhotoGroupDelete(pgid);
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull {
    final it = iterator;
    if (!it.moveNext()) return null;
    return it.current;
  }
}
