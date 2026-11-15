import '../../models/building.dart';
import '../../models/room.dart';

bool shouldOpenNavigatorBuilding(Building building, bool hasFloors) =>
    building.status == BuildingStatus.published && hasFloors;

List<Room> filterRooms(Iterable<Room> rooms, String query) {
  final normalized = query.trim().toLowerCase();
  if (normalized.isEmpty) return rooms.toList();
  return rooms.where((room) => room.nameLower.contains(normalized) || room.codeLower.contains(normalized)).toList();
}
