/// 동시 실행 수를 제한해 작업 목록을 처리한다.
Future<List<T>> runWithConcurrencyLimit<T>(
  Iterable<Future<T> Function()> taskBuilders, {
  int limit = 4,
}) async {
  final builders = taskBuilders.toList();
  if (builders.isEmpty) return const [];
  final cap = limit.clamp(1, builders.length);
  final results = List<T?>.filled(builders.length, null);
  var nextIndex = 0;

  Future<void> worker() async {
    while (true) {
      final i = nextIndex;
      nextIndex++;
      if (i >= builders.length) return;
      results[i] = await builders[i]();
    }
  }

  await Future.wait(List.generate(cap, (_) => worker()));
  return results.cast<T>();
}
