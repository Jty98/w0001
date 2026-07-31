import 'package:w0001/data/datasources/remote/list_query.dart';
import 'package:w0001/data/mappers/remote_mappers.dart';
import 'package:w0001/data/model/revenue_model.dart';
import 'package:w0001/domain/repository/revenue_abst.dart';
import 'package:w0001/domain/repository/super_admin_remote_abst.dart';

class RevenueRepositoryImpl implements RevenueRepository {
  RevenueRepositoryImpl(this._remote);

  final SuperAdminRemoteRepository _remote;

  @override
  Future<List<RevenueModel>> getAllRevenues(int placeId) async {
    final mine = await _remote.placeRevenuesQuery(ListQuery(pid: placeId));
    mine.sort((a, b) {
      final c = a.rdate.compareTo(b.rdate);
      if (c != 0) return c;
      return a.rorder.compareTo(b.rorder);
    });
    return mine.map(revenueReadToModel).toList();
  }

  @override
  Future<RevenueModel> insertRevenue({
    required int pid,
    required int rprice,
    required String rname,
    required String rdate,
  }) async {
    final created = await _remote.placeRevenueCreate(<String, dynamic>{
      'rpid': pid,
      'rprice': rprice,
      'rname': rname,
      'rdate': rdate,
    });
    return revenueReadToModel(created);
  }

  @override
  Future<void> updateRevenue({
    required RevenueModel revenue,
    required int placeId,
  }) {
    return _remote.placeRevenuePatch(
      revenue.rid,
      <String, dynamic>{
        'rprice': revenue.rprice,
        'rname': revenue.rname,
        'rdate': revenue.rdate,
      },
    );
  }

  @override
  Future<void> deleteRevenue(int revenueId, int placeId) {
    return _remote.placeRevenueDelete(revenueId);
  }
}
