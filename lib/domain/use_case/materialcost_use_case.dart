import 'package:w0001/domain/repository/materialcost_abst.dart';
import 'package:w0001/data/model/materialcost_model.dart';

class MaterialCostUseCase {
  MaterialCostUseCase(this._repository);

  final MaterialCostRepository _repository;

  Future<bool> addMaterialCosts(List<MaterialCostModel> mCostList) {
    return _repository.addMaterialCosts(mCostList);
  }

  Future<void> updateMaterialCostItem(MaterialCostModel materialCost) {
    return _repository.updateMaterialCostItem(materialCost);
  }

  Future<void> deleteMaterialCost(int mid) {
    return _repository.deleteMaterialCost(mid);
  }
}
