class PlaceInfoModel {
  final int? pid;
  final String pname;
  final String pstart;
  final String pend;
  final int pcomplete;
  final int pfirstrevenue;
  final int workerCount;
  final int totalAdditionalRevenue;
  final int mTotal;
  final int woodTotal;
  final int metalTotal;
  final int electricTotal;
  final int lightingTotal;
  final int cleaningTotal;
  final int filmTotal;
  final int landscapeTotal;
  final int hardwareTotal;
  final int paintTotal;
  final int facilityTotal;
  final int tileTotal;
  final int glassTotal;
  final int fuelTotal;
  final int accommodationTotal;
  final int foodTotal;
  final int personalExpensesTotal;
  final int firefightingTotal;
  final int signageTotal;
  final int airConditioningTotal;
  final int demolitionTotal;
  final int customMadeTotal;
  final int otherExpensesTotal;
  final int wTotal;
  final int wIncomplete;

  PlaceInfoModel({
    required this.pid,
    required this.pname,
    required this.pcomplete,
    required this.pstart,
    required this.pend,
    required this.pfirstrevenue,
    required this.workerCount,
    required this.totalAdditionalRevenue,
    required this.mTotal,
    required this.woodTotal,
    required this.metalTotal,
    required this.electricTotal,
    required this.lightingTotal,
    required this.cleaningTotal,
    required this.filmTotal,
    required this.landscapeTotal,
    required this.hardwareTotal,
    required this.paintTotal,
    required this.facilityTotal,
    required this.tileTotal,
    required this.glassTotal,
    required this.fuelTotal,
    required this.accommodationTotal,
    required this.foodTotal,
    required this.personalExpensesTotal,
    required this.firefightingTotal,
    required this.signageTotal,
    required this.airConditioningTotal,
    required this.demolitionTotal,
    required this.customMadeTotal,
    required this.otherExpensesTotal,
    required this.wTotal,
    required this.wIncomplete,
  });

  PlaceInfoModel.fromMap(Map<String, dynamic> res)
      : pid = res['pid'],
        pname = res['pname'] ?? '', // null 대신 빈 문자열 할당
        pcomplete = res['pcomplete'] ?? 0,
        pfirstrevenue = res['prevenue'] ?? 0,
        pstart = res['pstart'] ?? '',
        pend = res['pend'] ?? '',
        workerCount = res['workerCount'] ?? 0,
        totalAdditionalRevenue = res['totalAdditionalRevenue'] ?? 0,
        mTotal = res['mTotal'] ?? 0,
        woodTotal = res['woodTotal'] ?? 0,
        metalTotal = res['metalTotal'] ?? 0,
        electricTotal = res['electricTotal'] ?? 0,
        lightingTotal = res['lightingTotal'] ?? 0,
        cleaningTotal = res['cleaningTotal'] ?? 0,
        filmTotal = res['filmTotal'] ?? 0,
        landscapeTotal = res['landscapeTotal'] ?? 0,
        hardwareTotal = res['hardwareTotal'] ?? 0,
        paintTotal = res['paintTotal'] ?? 0,
        facilityTotal = res['facilityTotal'] ?? 0,
        tileTotal = res['tileTotal'] ?? 0,
        glassTotal = res['glassTotal'] ?? 0,
        fuelTotal = res['fuelTotal'] ?? 0,
        accommodationTotal = res['accommodationTotal'] ?? 0,
        foodTotal = res['foodTotal'] ?? 0,
        personalExpensesTotal = res['personalExpensesTotal'] ?? 0,
        firefightingTotal = res['firefightingTotal'] ?? 0,
        signageTotal = res['signageTotal'] ?? 0,
        airConditioningTotal = res['airConditioningTotal'] ?? 0,
        demolitionTotal = res['demolitionTotal'] ?? 0,
        customMadeTotal = res['customMadeTotal'] ?? 0,
        otherExpensesTotal = res['otherExpensesTotal'] ?? 0,
        wTotal = res['wTotal'] ?? 0,
        wIncomplete = res['wIncomplete'] ?? 0;
}

final Map<String, int Function(PlaceInfoModel)> categoryMapping = {
  '식대': (model) => model.foodTotal,
  '숙박': (model) => model.accommodationTotal,
  '유류비': (model) => model.fuelTotal,
  '철물': (model) => model.hardwareTotal,
  '목재': (model) => model.woodTotal,
  '금속': (model) => model.metalTotal,
  '전기': (model) => model.electricTotal,
  '조명': (model) => model.lightingTotal,
  '페인트': (model) => model.paintTotal,
  '설비': (model) => model.facilityTotal,
  '타일': (model) => model.tileTotal,
  '공조': (model) => model.airConditioningTotal,
  '소방': (model) => model.firefightingTotal,
  '유리': (model) => model.glassTotal,
  '조경': (model) => model.landscapeTotal,
  '필름': (model) => model.filmTotal,
  '사인물': (model) => model.signageTotal,
  '철거': (model) => model.demolitionTotal,
  '청소': (model) => model.cleaningTotal,
  '기타주문제작': (model) => model.customMadeTotal,
  '기타경비': (model) => model.otherExpensesTotal,
  '개인경비': (model) => model.personalExpensesTotal,
};