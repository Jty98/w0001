import 'package:w0001/data/model/materialcost_model.dart';
import 'package:w0001/domain/repository/materialcost_abst.dart';
import 'package:w0001/domain/repository/super_admin_remote_abst.dart';

class MaterialCostRepositoryImpl implements MaterialCostRepository {
  MaterialCostRepositoryImpl(this._remote);

  final SuperAdminRemoteRepository _remote;

  @override
  Future<bool> addMaterialCosts(List<MaterialCostModel> mCostList) async {
    for (final m in mCostList) {
      await _remote.materialCostCreate(<String, dynamic>{
        'mpid': m.mpid,
        'mname': m.mname,
        'mdate': m.mdate,
        'mprice': m.mprice,
        'mcategory': m.mcategory,
      });
    }
    return true;
  }

  @override
  Future<void> updateMaterialCostItem(MaterialCostModel materialCost) async {
    if (materialCost.mid == null) return;
    await _remote.materialCostPatch(
      materialCost.mid!,
      <String, dynamic>{
        'mname': materialCost.mname,
        'mdate': materialCost.mdate,
        'mprice': materialCost.mprice,
        'mcategory': materialCost.mcategory,
      },
    );
  }

  @override
  Future<void> deleteMaterialCost(int mid) {
    return _remote.materialCostDelete(mid);
  }
}
