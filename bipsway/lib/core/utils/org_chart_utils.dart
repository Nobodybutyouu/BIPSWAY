import '../../models/org_position.dart';

List<List<OrgPosition>> buildOrgLevels(Iterable<OrgPosition> positions) {
  final all = positions.toList();
  final ids = all.map((position) => position.id).toSet();
  final children = <String?, List<OrgPosition>>{};
  for (final position in all) {
    final parent = ids.contains(position.reportsTo) ? position.reportsTo : null;
    children.putIfAbsent(parent, () => []).add(position);
  }
  final levels = <List<OrgPosition>>[];
  void visit(List<OrgPosition> nodes, int depth) {
    while (levels.length <= depth) {
      levels.add([]);
    }
    for (final node in nodes) {
      levels[depth].add(node);
      visit(children[node.id] ?? const [], depth + 1);
    }
  }
  visit(children[null] ?? all.where((position) => !ids.contains(position.reportsTo)).toList(), 0);
  final visited = levels.expand((level) => level).map((position) => position.id).toSet();
  final orphans = all.where((position) => !visited.contains(position.id)).toList();
  if (orphans.isNotEmpty) levels.insert(0, orphans);
  return levels.where((level) => level.isNotEmpty).toList();
}

bool wouldCreateOrgCycle({
  required String positionId,
  required String? reportsTo,
  required Iterable<OrgPosition> positions,
}) {
  if (reportsTo == null || reportsTo.isEmpty || reportsTo == positionId) return reportsTo == positionId;
  final byId = {for (final position in positions) position.id: position};
  var current = byId[reportsTo];
  final seen = <String>{};
  while (current != null && seen.add(current.id)) {
    if (current.id == positionId) return true;
    current = current.reportsTo == null ? null : byId[current.reportsTo];
  }
  return false;
}

bool orgPositionHasChildren(String id, Iterable<OrgPosition> positions) => positions.any((position) => position.reportsTo == id);
