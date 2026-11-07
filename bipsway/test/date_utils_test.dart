import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest.dart' as timezone_data;
import 'package:timezone/timezone.dart' as timezone;

import 'package:bipsway/core/utils/date_utils.dart' as app_dates;

void main() {
  setUpAll(() {
    timezone_data.initializeTimeZones();
    timezone.setLocalLocation(timezone.getLocation(app_dates.manilaTimeZone));
  });

  test('calculates Monday and next Monday in Manila', () {
    final value = timezone.TZDateTime(
      app_dates.manilaLocation,
      2026,
      11,
      11,
      14,
      30,
    );
    final monday = app_dates.startOfManilaWeek(value);
    final nextMonday = app_dates.startOfNextManilaWeek(value);

    expect(monday.weekday, DateTime.monday);
    expect(monday.hour, 0);
    expect(monday.minute, 0);
    expect(nextMonday.difference(monday), const Duration(days: 7));
  });

  test('hides past events and splits visible events at next Monday', () {
    final now = timezone.TZDateTime(
      app_dates.manilaLocation,
      2026,
      11,
      11,
      12,
    );
    final events = [
      _Event('past', now.subtract(const Duration(days: 2)), now.subtract(const Duration(hours: 1))),
      _Event('this week', now.add(const Duration(hours: 1)), now.add(const Duration(hours: 2))),
      _Event('upcoming', app_dates.startOfNextManilaWeek(now).add(const Duration(hours: 1)), app_dates.startOfNextManilaWeek(now).add(const Duration(hours: 2))),
    ];

    final buckets = app_dates.splitEventsByManilaWeek(
      events: events,
      startAt: (event) => event.start,
      endAt: (event) => event.end,
      now: now,
    );

    expect(buckets.thisWeek.map((event) => event.name), ['this week']);
    expect(buckets.upcoming.map((event) => event.name), ['upcoming']);
  });
}

class _Event {
  const _Event(this.name, this.start, this.end);
  final String name;
  final DateTime start;
  final DateTime end;
}
