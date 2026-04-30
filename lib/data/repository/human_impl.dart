import 'package:w0001/data/mappers/remote_mappers.dart';
import 'package:w0001/data/model/human_model.dart';
import 'package:w0001/data/model/remote/super_admin_dtos.dart';
import 'package:w0001/domain/repository/human_abst.dart';
import 'package:w0001/domain/repository/super_admin_remote_abst.dart';

class HumanRepositoryImpl implements HumanRepository {
  HumanRepositoryImpl(this._remote);

  final SuperAdminRemoteRepository _remote;

  @override
  Future<List<HumanModel>> getAllWorkers() async {
    final list = await _remote.humansList();
    final active = list.where((h) => h.hdelete == 0).toList();
    active.sort((a, b) {
      final c = b.hstar.compareTo(a.hstar);
      if (c != 0) return c;
      return a.hname.compareTo(b.hname);
    });
    return active.map(humanReadToModel).toList();
  }

  @override
  Future<HumanModel> addWorker(HumanModel worker) async {
    final body = <String, dynamic>{
      'hname': worker.hname,
      'hnumber': worker.hnumber,
      'hmemo': worker.hmemo,
      'hdailywage': worker.hdailyWage,
      'hdefaultrole': worker.hdefaultRole,
      'hstar': worker.hstar,
      'hdelete': 0,
    };
    final created = await _remote.humanCreate(body);
    return humanReadToModel(created);
  }

  @override
  Future<void> updateWorker(HumanModel humanModel) async {
    if (humanModel.hid == null) return;
    await _remote.humanPatch(humanModel.hid!, <String, dynamic>{
      'hname': humanModel.hname,
      'hnumber': humanModel.hnumber,
      'hmemo': humanModel.hmemo,
      'hdailywage': humanModel.hdailyWage,
      'hdefaultrole': humanModel.hdefaultRole,
    });
  }

  @override
  Future<void> toggleWorkerStarStatus(int hid, bool isStarred) {
    return _remote.humanPatch(hid, <String, dynamic>{'hstar': isStarred ? 1 : 0});
  }

  @override
  Future<void> deleteWorker(int hid) {
    return _remote.humanPatch(hid, <String, dynamic>{'hdelete': 1});
  }

  @override
  Future<void> upsertPlaceWorkerRecent(int pid, int hid) async {
    final ms = DateTime.now().millisecondsSinceEpoch;
    final all = await _remote.placeWorkerRecentsList();
    final hit = all.any((e) => e.pid == pid && e.hid == hid);
    if (hit) {
      await _remote.placeWorkerRecentPatch(pid, hid, <String, dynamic>{'lastusedms': ms});
    } else {
      await _remote.placeWorkerRecentCreate(<String, dynamic>{
        'pid': pid,
        'hid': hid,
        'lastusedms': ms,
      });
    }
  }

  @override
  Future<List<int>> getPlaceWorkerRecentHids(int pid) async {
    final all = await _remote.placeWorkerRecentsList();
    final forPid = all.where((e) => e.pid == pid);
    final humans = await _remote.humansList();
    final byHid = {for (final h in humans) h.hid: h};
    final rows = forPid
        .map((e) => byHid[e.hid])
        .whereType<HumanRead>()
        .where((h) => h.hdelete == 0)
        .toList();
    rows.sort((a, b) => a.hname.compareTo(b.hname));
    return rows.map((h) => h.hid).toList();
  }

  @override
  Future<void> deletePlaceWorkerRecent(int pid, int hid) {
    return _remote.placeWorkerRecentDelete(pid, hid);
  }
}
