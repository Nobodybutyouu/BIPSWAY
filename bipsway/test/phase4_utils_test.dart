import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'package:bipsway/core/utils/date_utils.dart' as app_dates;
import 'package:bipsway/core/utils/event_utils.dart';
import 'package:bipsway/core/utils/org_chart_utils.dart';
import 'package:bipsway/models/org_position.dart';
import 'package:bipsway/models/person.dart';

void main() {
  setUpAll(() { tzdata.initializeTimeZones(); });

  test('event date and time are constructed in Asia/Manila', () {
    final value = manilaDateTime(date: DateTime(2026, 11, 14), hour: 9, minute: 30);
    expect(value.location, app_dates.manilaLocation);
    expect(value.hour, 9);
    expect(value.minute, 30);
    expect(value.timeZoneOffset, const Duration(hours: 8));
  });

  test('event time and location helpers', () {
    final start = manilaDateTime(date: DateTime(2026, 11, 14), hour: 9, minute: 0);
    final end = manilaDateTime(date: DateTime(2026, 11, 14), hour: 10, minute: 0);
    expect(end.isAfter(start), isTrue);
    expect(eventLocationLabel(buildingName: 'STCS Building', roomName: 'T-203'), 'STCS Building · T-203');
  });

  test('org chart renders orphans at the top and prevents cycles', () {
    const dean = OrgPosition(id: 'dean', department: 'STCS', positionTitle: 'Dean', fullName: 'Dean', reportsTo: null, photoUrl: null);
    const chair = OrgPosition(id: 'chair', department: 'STCS', positionTitle: 'Chairperson', fullName: 'Chair', reportsTo: 'dean', photoUrl: null);
    const orphan = OrgPosition(id: 'orphan', department: 'STCS', positionTitle: 'Others', fullName: 'Orphan', reportsTo: 'missing', photoUrl: null);
    final levels = buildOrgLevels([dean, chair, orphan]);
    expect(levels.first.map((position) => position.id), containsAll(<String>['dean', 'orphan']));
    expect(wouldCreateOrgCycle(positionId: 'dean', reportsTo: 'chair', positions: [dean, chair]), isTrue);
    expect(wouldCreateOrgCycle(positionId: 'chair', reportsTo: 'dean', positions: [dean, chair]), isFalse);
  });

  test('personnel filter matches name or position case-insensitively', () {
    const people = [
      Person(id: '1', fullName: 'Ana Cruz', nameLower: 'ana cruz', position: 'Instructor', department: 'STCS', details: null, photoUrl: null),
      Person(id: '2', fullName: 'Ben Santos', nameLower: 'ben santos', position: 'President', department: 'Office', details: null, photoUrl: null),
    ];
    expect(filterPersonnel(people: people, query: 'INSTRUCT', name: (person) => person.fullName, position: (person) => person.position).single.id, '1');
  });

  test('manila utility has the expected location', () {
    final value = tz.TZDateTime(app_dates.manilaLocation, 2026, 1, 1);
    expect(value.location.name, 'Asia/Manila');
  });
}
