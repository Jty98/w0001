import 'package:w0001/data/model/human_model.dart';

/// 인건비 1단 목록(인력별 요약) — 서버 `GET /work-costs/worker-summaries` 항목.
class WorkCostWorkerSummary {
  const WorkCostWorkerSummary({
    required this.hid,
    required this.hname,
    required this.hnumber,
    required this.hstar,
    required this.unpaidCount,
    required this.unpaidAmount,
    required this.paidCount,
    required this.paidAmount,
    this.hdailyWage = 0,
    this.hdefaultRole = '',
    this.workerRank,
    this.primarySpecialty,
    this.specialties = const [],
  });

  final int hid;
  final String hname;
  final String hnumber;
  final int hstar;
  final int unpaidCount;
  final int unpaidAmount;
  final int paidCount;
  final int paidAmount;
  final int hdailyWage;
  final String hdefaultRole;
  final String? workerRank;
  final String? primarySpecialty;
  final List<String> specialties;

  int get totalAmount => unpaidAmount + paidAmount;
  int get totalCount => unpaidCount + paidCount;

  String get uniqueHumanKey => 'name:$hname#number:$hnumber';

  factory WorkCostWorkerSummary.fromJson(Map<String, dynamic> json) {
    int pickInt(String snake, String camel) {
      final v = json[snake] ?? json[camel];
      if (v is int) return v;
      if (v is num) return v.toInt();
      if (v is String) return int.tryParse(v.trim()) ?? 0;
      return 0;
    }

    String pickStr(String snake, String camel) {
      final v = json[snake] ?? json[camel];
      return v?.toString().trim() ?? '';
    }

    int pickDailyWage() {
      for (final key in ['hdailywage', 'hdaily_wage', 'hdailyWage']) {
        final v = json[key];
        if (v is int) return v;
        if (v is num) return v.toInt();
        if (v is String) {
          final n = int.tryParse(v.trim());
          if (n != null) return n;
        }
      }
      return 0;
    }

    return WorkCostWorkerSummary(
      hid: pickInt('hid', 'hid'),
      hname: pickStr('hname', 'hname'),
      hnumber: pickStr('hnumber', 'hnumber'),
      hstar: pickInt('hstar', 'hstar'),
      unpaidCount: pickInt('unpaid_count', 'unpaidCount'),
      unpaidAmount: pickInt('unpaid_amount', 'unpaidAmount'),
      paidCount: pickInt('paid_count', 'paidCount'),
      paidAmount: pickInt('paid_amount', 'paidAmount'),
      hdailyWage: pickDailyWage(),
      hdefaultRole: pickStr('hdefault_role', 'hdefaultRole'),
      workerRank: pickStr('worker_rank', 'workerRank').isEmpty
          ? null
          : pickStr('worker_rank', 'workerRank'),
      primarySpecialty: pickStr('primary_specialty', 'primarySpecialty').isEmpty
          ? null
          : pickStr('primary_specialty', 'primarySpecialty'),
      specialties: const [],
    );
  }

  HumanModel? toHumanModel() {
    if (hid <= 0 && hname.isEmpty) return null;
    return HumanModel(
      hid: hid,
      hname: hname,
      hnumber: hnumber,
      hstar: hstar,
      hdelete: 0,
      hdailyWage: hdailyWage,
      hdefaultRole: hdefaultRole,
      workerRank: workerRank ?? '',
      primarySpecialty: primarySpecialty,
      specialties: specialties,
    );
  }
}
