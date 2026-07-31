import 'package:w0001/data/model/materialcost_model.dart';
import 'package:w0001/domain/repository/materialcost_abst.dart';
import 'package:w0001/domain/repository/super_admin_remote_abst.dart';
import 'package:w0001/util/funtions.dart';

class MaterialCostRepositoryImpl implements MaterialCostRepository {
  MaterialCostRepositoryImpl(this._remote);

  final SuperAdminRemoteRepository _remote;

  Map<String, dynamic> _createBody(MaterialCostModel m) => <String, dynamic>{
        'mpid': m.mpid,
        'mname': m.mname,
        'mdate': normalizeToIsoDateString(m.mdate),
        'mprice': m.mprice,
        'mcategory': m.mcategory,
      };

  @override
  Future<bool> addMaterialCosts(List<MaterialCostModel> mCostList) async {
    if (mCostList.isEmpty) return true;
    await Future.wait(
      mCostList.map((m) => _remote.materialCostCreate(_createBody(m))),
    );
    return true;
  }

  @override
  Future<void> updateMaterialCostItem(MaterialCostModel materialCost) async {
    if (materialCost.mid == null) return;
    await _remote.materialCostPatch(
      materialCost.mid!,
      <String, dynamic>{
        'mname': materialCost.mname,
        'mdate': normalizeToIsoDateString(materialCost.mdate),
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
