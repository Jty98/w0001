import 'package:w0001/data/model/revenue_model.dart';

/// 수익(Revenue) 도메인 저장소 추상
abstract class RevenueRepository {
  Future<List<RevenueModel>> getAllRevenues(int placeId);
  Future<RevenueModel> insertRevenue({
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
