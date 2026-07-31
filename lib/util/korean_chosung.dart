import 'package:w0001/ui/widget/worker_grouped_list/worker_grouped_list_utils.dart';

export 'package:w0001/ui/widget/worker_grouped_list/worker_grouped_list_utils.dart'
    show
        kKoreanInitialIndex,
        initialIndexKeyForName,
        normalizeKoreanInitialChipKey,
        orderedInitialSectionKeys,
        groupWorkersByInitial;

/// 한글 음절·자모에서 초성만 추출한 문자열.
///
/// 예: `가스켓` → `ㄱㅅㅋ`, `ㄱㅅ` → `ㄱㅅ`
String toChosungString(String text) {
  final buffer = StringBuffer();
  for (final code in text.runes) {
    if (code >= 0xAC00 && code <= 0xD7A3) {
      final lIndex = (code - 0xAC00) ~/ 588;
      buffer.write(_leads[lIndex]);
      continue;
    }
    final ch = String.fromCharCode(code);
    if (_chosungSet.contains(ch)) {
      buffer.write(normalizeKoreanInitialChipKey(ch));
    }
  }
  return buffer.toString();
}

/// 입력이 초성(자모)만으로 이뤄졌는지.
bool isChosungOnlyQuery(String query) {
  final trimmed = query.trim();
  if (trimmed.isEmpty) return false;
  for (final code in trimmed.runes) {
    final ch = String.fromCharCode(code);
    if (!_chosungSet.contains(ch) && ch != ' ') return false;
  }
  return true;
}

/// 제목·표준어·별칭에 대해 텍스트 또는 초성 검색 매칭.
bool matchesDictionaryQuery({
  required String title,
  required String query,
  String? standardName,
  List<String> aliases = const [],
}) {
  final q = query.trim();
  if (q.isEmpty) return true;

  if (isChosungOnlyQuery(q)) {
    final needle = q.replaceAll(' ', '');
    if (toChosungString(title).contains(needle)) return true;
    if (standardName != null &&
        toChosungString(standardName).contains(needle)) {
      return true;
    }
    for (final alias in aliases) {
      if (toChosungString(alias).contains(needle)) return true;
    }
    return false;
  }

  final lower = q.toLowerCase();
  if (title.toLowerCase().contains(lower)) return true;
  if (standardName != null && standardName.toLowerCase().contains(lower)) {
    return true;
  }
  for (final alias in aliases) {
    if (alias.toLowerCase().contains(lower)) return true;
  }
  return false;
}

const List<String> _leads = <String>[
  'ㄱ',
  'ㄲ',
  'ㄴ',
  'ㄷ',
  'ㄸ',
  'ㄹ',
  'ㅁ',
  'ㅂ',
  'ㅃ',
  'ㅅ',
  'ㅆ',
  'ㅇ',
  'ㅈ',
  'ㅉ',
  'ㅊ',
  'ㅋ',
  'ㅌ',
  'ㅍ',
  'ㅎ',
];

const Set<String> _chosungSet = <String>{
  'ㄱ',
  'ㄲ',
  'ㄴ',
  'ㄷ',
  'ㄸ',
  'ㄹ',
  'ㅁ',
  'ㅂ',
  'ㅃ',
  'ㅅ',
  'ㅆ',
  'ㅇ',
  'ㅈ',
  'ㅉ',
  'ㅊ',
  'ㅋ',
  'ㅌ',
  'ㅍ',
  'ㅎ',
};
