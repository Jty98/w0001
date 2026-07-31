import 'package:flutter_test/flutter_test.dart';

import 'package:scrollable_calendar_package/calendar.dart';

void main() {
  test('CalendarConfig generates month pages around initialDate', () {
    final config = CalendarConfig(
      initialDate: DateTime(2026, 3, 1),
      yearRange: 1,
    );
    final generated = config.generate();

    expect(generated.months.length, 36);
    expect(generated.initialPage, 14);
  });
}
