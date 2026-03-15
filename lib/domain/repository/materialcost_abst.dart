import 'package:w0001/data/model/materialcost_model.dart';

/// 자재비(MaterialCost) 도메인 저장소 추상
abstract class MaterialCostRepository {
  Future<bool> addMaterialCosts(List<MaterialCostModel> mCostList);
  Future<void> updateMaterialCostItem(MaterialCostModel materialCost);
  Future<void> deleteMaterialCost(int mid);
}
