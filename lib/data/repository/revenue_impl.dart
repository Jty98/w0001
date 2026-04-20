import 'package:w0001/data/datasources/local/revenue_local_data_source.dart';
import 'package:w0001/domain/repository/revenue_abst.dart';
import 'package:w0001/data/model/revenue_model.dart';

class RevenueRepositoryImpl implements RevenueRepository {
  RevenueRepositoryImpl(this._localDataSource);

  final RevenueLocalDataSource _localDataSource;

  @override
  Future<List<RevenueModel>> getAllRevenues(int placeId) {
    return _localDataSource.getAllRevenues(placeId);
  }

  @override
  Future<RevenueModel> insertRevenue({
    required int pid,
    required int rprice,
    required String rname,
    required String rdate,
  }) async {
    final rid = await _localDataSource.insertRevenue(
      pid: pid,
      rprice: rprice,
      rname: rname,
      rdate: rdate,
    );
    return RevenueModel(
      rid: rid,
      rpid: pid,
      rname: rname,
      rorder: 0,
      rprice: rprice,
      rdate: rdate,
    );
  }

  @override
  Future<void> updateRevenue({
    required RevenueModel revenue,
    required int placeId,
  }) {
    return _localDataSource.updateRevenue(
      revenue: revenue,
      placeId: placeId,
    );
  }

  @override
  Future<void> deleteRevenue(int revenueId, int placeId) {
    return _localDataSource.deleteRevenue(revenueId, placeId);
  }
}

