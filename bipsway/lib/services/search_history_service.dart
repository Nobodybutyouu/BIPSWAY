import 'package:hive_flutter/hive_flutter.dart';

import '../models/building.dart';
import '../models/room.dart';

abstract interface class SearchHistoryService {
  Future<void> recordSearch(Room room, Building building);
  Future<void> setSaveSearchHistory(bool enabled);
}

class HiveSearchHistoryService implements SearchHistoryService {
  static const _boxName = 'bipsway_search_history';
  static const _preferenceKey = 'saveSearchHistory';

  Future<Box<dynamic>> _box() async {
    if (!Hive.isBoxOpen(_boxName)) return Hive.openBox<dynamic>(_boxName);
    return Hive.box<dynamic>(_boxName);
  }

  @override
  Future<void> recordSearch(Room room, Building building) async {
    final box = await _box();
    if (box.get(_preferenceKey, defaultValue: true) != true) return;
    final key = '${building.id}:${room.id}';
    await box.put(key, {
      'buildingId': building.id,
      'buildingName': building.name,
      'roomId': room.id,
      'roomName': room.name,
      'searchedAt': DateTime.now().toIso8601String(),
    });
  }

  @override
  Future<void> setSaveSearchHistory(bool enabled) async {
    final box = await _box();
    await box.put(_preferenceKey, enabled);
  }
}

final searchHistoryService = HiveSearchHistoryService();
