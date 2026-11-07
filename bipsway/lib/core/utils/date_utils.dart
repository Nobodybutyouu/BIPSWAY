import 'package:timezone/timezone.dart' as tz;

const manilaTimeZone = 'Asia/Manila';

tz.Location get manilaLocation => tz.getLocation(manilaTimeZone);

tz.TZDateTime nowInManila() => tz.TZDateTime.now(manilaLocation);

tz.TZDateTime startOfManilaWeek([tz.TZDateTime? value]) {
  final current = value == null
      ? nowInManila()
      : tz.TZDateTime.from(value, manilaLocation);
  final midnight = tz.TZDateTime(
    manilaLocation,
    current.year,
    current.month,
    current.day,
  );
  return midnight.subtract(Duration(days: current.weekday - DateTime.monday));
}

tz.TZDateTime startOfNextManilaWeek([tz.TZDateTime? value]) {
  return startOfManilaWeek(value).add(const Duration(days: 7));
}

class EventBuckets<T> {
  const EventBuckets({required this.thisWeek, required this.upcoming});

  final List<T> thisWeek;
  final List<T> upcoming;
}

/// Applies Section 8.1: hide past events, then split visible events at the
/// start of next Monday in Asia/Manila.
EventBuckets<T> splitEventsByManilaWeek<T>({
  required Iterable<T> events,
  required DateTime Function(T event) startAt,
  required DateTime Function(T event) endAt,
  tz.TZDateTime? now,
}) {
  final current = now ?? nowInManila();
  final nextWeek = startOfNextManilaWeek(current);
  final thisWeek = <T>[];
  final upcoming = <T>[];

  for (final event in events) {
    final end = tz.TZDateTime.from(endAt(event), manilaLocation);
    final start = tz.TZDateTime.from(startAt(event), manilaLocation);
    if (end.isBefore(current)) continue;
    if (start.isBefore(nextWeek)) {
      thisWeek.add(event);
    } else {
      upcoming.add(event);
    }
  }

  int compareByStart(T left, T right) =>
      startAt(left).compareTo(startAt(right));
  thisWeek.sort(compareByStart);
  upcoming.sort(compareByStart);
  return EventBuckets(thisWeek: thisWeek, upcoming: upcoming);
}
