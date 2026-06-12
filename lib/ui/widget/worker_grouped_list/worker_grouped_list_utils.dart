/// 한글 이름 초성 인덱스·그룹 키 (인력 목록 바텀시트 공용).
const List<String> kKoreanInitialIndex = <String>[
  'ㄱ',
  'ㄴ',
  'ㄷ',
  'ㄹ',
  'ㅁ',
  'ㅂ',
  'ㅅ',
  'ㅇ',
  'ㅈ',
  'ㅊ',
  'ㅋ',
  'ㅌ',
  'ㅍ',
  'ㅎ',
];

/// 쌍자음·된소리 등은 목록/칩에서 쓰는 14개 초성(ㄱ~ㅎ)으로 통합.
const Map<String, String> kKoreanInitialToChip = <String, String>{
  'ㄲ': 'ㄱ',
  'ㄸ': 'ㄷ',
  'ㅃ': 'ㅂ',
  'ㅆ': 'ㅅ',
  'ㅉ': 'ㅈ',
};

String normalizeKoreanInitialChipKey(String key) {
  return kKoreanInitialToChip[key] ?? key;
}

String initialIndexKeyForName(String name) {
  final trimmed = name.trim();
  if (trimmed.isEmpty) return '#';
  final code = trimmed.runes.first;
  if (code >= 0xAC00 && code <= 0xD7A3) {
    final sIndex = code - 0xAC00;
    final lIndex = sIndex ~/ 588;
    const leads = <String>[
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
    return normalizeKoreanInitialChipKey(leads[lIndex]);
  }
  final ch = String.fromCharCode(code).toUpperCase();
  final isAZ = ch.codeUnitAt(0) >= 65 && ch.codeUnitAt(0) <= 90;
  return isAZ ? ch : '#';
}

Map<String, List<T>> groupWorkersByInitial<T>(
  Iterable<T> items,
  String Function(T) nameSelector,
) {
  final sections = <String, List<T>>{};
  for (final item in items) {
    final k = initialIndexKeyForName(nameSelector(item));
    (sections[k] ??= <T>[]).add(item);
  }
  return sections;
}

Map<String, List<T>> groupWorkersByRole<T>(
  Iterable<T> items,
  String Function(T) roleSelector,
) {
  final sections = <String, List<T>>{};
  for (final item in items) {
    final role = roleSelector(item).trim();
    final k = role.isEmpty ? '역할 미지정' : role;
    (sections[k] ??= <T>[]).add(item);
  }
  return sections;
}

List<String> orderedInitialSectionKeys(Map<String, Object?> sections) {
  return <String>[
    ...kKoreanInitialIndex.where(sections.containsKey),
    ...sections.keys
        .where((k) => !kKoreanInitialIndex.contains(k) && k != '#')
        .toList()
      ..sort(),
    if (sections.containsKey('#')) '#',
  ];
}

List<String> orderedRoleSectionKeys(Map<String, Object?> sections) {
  final keys = sections.keys.toList()..sort();
  if (keys.remove('역할 미지정')) keys.add('역할 미지정');
  return keys;
}

/// 인력 찾기 목록 부제: `일당 150,000원 [목수]`
String formatWorkerGroupedPersonSubtitle({
  required String wageLabel,
  required String role,
}) {
  final r = role.trim();
  if (r.isEmpty) return wageLabel;
  return '$wageLabel [$r]';
}
