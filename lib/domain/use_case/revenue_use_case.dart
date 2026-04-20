import 'package:w0001/domain/repository/revenue_abst.dart';
import 'package:w0001/data/model/revenue_model.dart';

class RevenueUseCase {
  RevenueUseCase(this._repository);

  final RevenueRepository _repository;

  Future<List<RevenueModel>> getAllRevenues(int placeId) {
    return _repository.getAllRevenues(placeId);
  }

  Future<RevenueModel> insertRevenue({
    required int pid,
    required int rprice,
    required String rname,
    required String rdate,
  }) {
    return _repository.insertRevenue(
      pid: pid,
      rprice: rprice,
      rname: rname,
      rdate: rdate,
    );
  }

  Future<void> updateRevenue({
    required RevenueModel revenue,
    required int placeId,
  }) {
    return _repository.updateRevenue(
      revenue: revenue,
      placeId: placeId,
    );
  }

  Future<void> deleteRevenue(int revenueId, int placeId) {
    return _repository.deleteRevenue(revenueId, placeId);
  }
}

