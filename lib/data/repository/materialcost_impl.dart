import 'package:w0001/data/datasources/local/materialcost_local_data_source.dart';
import 'package:w0001/domain/repository/materialcost_abst.dart';
import 'package:w0001/data/model/materialcost_model.dart';

class MaterialCostRepositoryImpl implements MaterialCostRepository {
  MaterialCostRepositoryImpl(this._localDataSource);

  final MaterialCostLocalDataSource _localDataSource;

  @override
  Future<bool> addMaterialCosts(List<MaterialCostModel> mCostList) {
    return _localDataSource.addMaterialCosts(mCostList);
  }

  @override
  Future<void> updateMaterialCostItem(MaterialCostModel materialCost) {
    return _localDataSource.updateMaterialCostItem(materialCost);
  }

  @override
  Future<void> deleteMaterialCost(int mid) {
    return _localDataSource.deleteMaterialCost(mid);
  }
}

