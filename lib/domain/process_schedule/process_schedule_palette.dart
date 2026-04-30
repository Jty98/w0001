/// UI 색 배정(인접 행 대비). [ProcessScheduleTask.paletteIndex]에 대응.
class ProcessSchedulePalette {
  ProcessSchedulePalette._();

  static const spreadStep = 7;
  static const minNeighborCircDist = 5;

  static int get length => _argbValues.length;

  static int argbAt(int i) => _argbValues[i % _argbValues.length];

  /// 인접 행끼리 원형 거리를 넓히도록 인덱스 배열 생성.
  static List<int> adjacentContrastIndices(int rowCount) {
    final nRows = rowCount;
    final nPal = length;
    if (nRows == 0) return [];

    int circDist(int a, int b) {
      final d = (a - b).abs();
      return d <= nPal - d ? d : nPal - d;
    }

    final chosen = List<int>.generate(
      nRows,
      (i) => (i * spreadStep) % nPal,
    );

    int neighborScore(int idx, int c) {
      var s = 0;
      if (idx > 0) s += circDist(c, chosen[idx - 1]);
      if (idx < nRows - 1) s += circDist(c, chosen[idx + 1]);
      return s;
    }

    bool rowNeighborsOk(int i) {
      if (i > 0 && circDist(chosen[i], chosen[i - 1]) < minNeighborCircDist) {
        return false;
      }
      if (i < nRows - 1 &&
          circDist(chosen[i], chosen[i + 1]) < minNeighborCircDist) {
        return false;
      }
      return true;
    }

    for (var pass = 0; pass < 6; pass++) {
      var changed = false;
      for (var i = 0; i < nRows; i++) {
        if (rowNeighborsOk(i)) continue;
        final usedByOthers = <int>{
          for (var j = 0; j < nRows; j++)
            if (j != i) chosen[j],
        };
        var bestC = chosen[i];
        var bestS = neighborScore(i, bestC);
        for (var c = 0; c < nPal; c++) {
          if (nRows <= nPal && usedByOthers.contains(c)) continue;
          final sc = neighborScore(i, c);
          if (sc > bestS) {
            bestS = sc;
            bestC = c;
          }
        }
        if (bestC != chosen[i]) {
          chosen[i] = bestC;
          changed = true;
        }
      }
      if (!changed) break;
    }

    return chosen;
  }

  static const _argbValues = <int>[
    0xFFC62828,
    0xFF0277BD,
    0xFF2E7D32,
    0xFF6A1B9A,
    0xFFEF6C00,
    0xFF283593,
    0xFFAD1457,
    0xFF00695C,
    0xFFF9A825,
    0xFF4E342E,
    0xFF00838F,
    0xFF558B2F,
    0xFF4527A0,
    0xFFE64A19,
    0xFF1565C0,
    0xFF7B1FA2,
    0xFF00796B,
    0xFF37474F,
    0xFFFF6F00,
    0xFF5D4037,
  ];
}
