import 'package:w0001/data/datasources/local/dbhelper.dart';
import 'package:w0001/data/model/materialcost_model.dart';

/// 자재비(MaterialCost) 관련 로컬 데이터소스 (SQLite)
abstract class MaterialCostLocalDataSource {
  Future<bool> addMaterialCosts(List<MaterialCostModel> mCostList);
  Future<void> updateMaterialCostItem(MaterialCostModel materialCost);
  Future<void> deleteMaterialCost(int mid);
}

class MaterialCostLocalDataSourceImpl implements MaterialCostLocalDataSource {
  MaterialCostLocalDataSourceImpl(this._dbHelper);

  final DbHelper _dbHelper;

  @override
  Future<bool> addMaterialCosts(List<MaterialCostModel> mCostList) {
    return _dbHelper.addMaterialCosts(mCostList);
  }

  @override
  Future<void> updateMaterialCostItem(MaterialCostModel materialCost) {
    return _dbHelper.updateMaterialCostItem(materialCost);
  }

  @override
  Future<void> deleteMaterialCost(int mid) {
    return _dbHelper.deleteMaterialCost(mid);
  }
}

