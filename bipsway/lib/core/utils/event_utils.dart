import 'package:timezone/timezone.dart' as tz;

import 'date_utils.dart' as app_dates;

tz.TZDateTime manilaDateTime({
  required DateTime date,
  required int hour,
  required int minute,
}) => tz.TZDateTime(app_dates.manilaLocation, date.year, date.month, date.day, hour, minute);

String eventLocationLabel({required String buildingName, String? roomName}) =>
    roomName == null || roomName.trim().isEmpty ? buildingName.trim() : '${buildingName.trim()} · ${roomName.trim()}';

List<T> filterPersonnel<T>({required Iterable<T> people, required String query, required String Function(T) name, required String Function(T) position}) {
  final normalized = query.trim().toLowerCase();
  if (normalized.isEmpty) return people.toList();
  return people.where((person) => name(person).toLowerCase().contains(normalized) || position(person).toLowerCase().contains(normalized)).toList();
}
