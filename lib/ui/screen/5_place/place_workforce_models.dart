import 'package:w0001/data/model/place_info_model.dart';
import 'package:w0001/data/model/place_model.dart';

/// [PlaceDetailScreen]·공정표·라우터에서 [PlaceWorkforceScreen]으로 전달.
class PlaceWorkforceRouteExtra {
  const PlaceWorkforceRouteExtra({
    required this.placeInfo,
    this.initialWorkDate,
  });

  final PlaceInfoModel placeInfo;

  /// 공정표 날짜 헤더 탭으로 들어온 경우 캘린더 초기 선택일.
  final DateTime? initialWorkDate;
}

PlaceModel placeModelForAddCost(PlaceInfoModel i) => PlaceModel(
      pid: i.pid,
      pname: i.pname,
      pcomplete: i.pcomplete,
      pstart: i.pstart,
      pend: i.pend,
      paddress: i.paddress,
      prevenue: i.pfirstrevenue,
      pcontractTotal: i.pcontractTotal,
    );
