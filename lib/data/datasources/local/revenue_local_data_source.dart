import 'package:w0001/data/datasources/local/dbhelper.dart';
import 'package:w0001/data/model/revenue_model.dart';

/// 수익(Revenue) 관련 로컬 데이터소스 (SQLite)
abstract class RevenueLocalDataSource {
  Future<List<RevenueModel>> getAllRevenues(int placeId);
  Future<void> insertRevenue({
    required int pid,
    required int rprice,
    required String rname,
  });
  Future<void> updateRevenue({
    required RevenueModel revenue,
    required int placeId,
  });
  Future<void> deleteRevenue(int revenueId, int placeId);
}

class RevenueLocalDataSourceImpl implements RevenueLocalDataSource {
  RevenueLocalDataSourceImpl(this._dbHelper);

  final DbHelper _dbHelper;

  @override
  Future<List<RevenueModel>> getAllRevenues(int placeId) {
    return _dbHelper.getAllRevenues(placeId);
  }

  @override
  Future<void> insertRevenue({
    required int pid,
    required int rprice,
    required String rname,
  }) {
    return _dbHelper.insertRevenue(pid: pid, rprice: rprice, rname: rname);
  }

  @override
  Future<void> updateRevenue({
    required RevenueModel revenue,
    required int placeId,
  }) {
    return _dbHelper.updateRevenue(revenue: revenue, placeId: placeId);
  }

  @override
  Future<void> deleteRevenue(int revenueId, int placeId) {
    return _dbHelper.deleteRevenue(revenueId, placeId);
  }
}

