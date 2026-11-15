# Navigator map and building code map

All Navigator content routes are children of the Navigator StatefulShellRoute
Home branch. They receive IDs from URL parameters and load documents through
Riverpod providers; they do not depend on `state.extra`.

| Screen | File/class | Route | Providers/repository methods |
| --- | --- | --- | --- |
| N-05 BiPSU Map | `lib/features/navigator/navigator_screens.dart` / `NavigatorMapHomeScreen` | `/navigator/home` | `buildingsProvider`, `floorsProvider`, `BuildingRepository.watchBuildings`, `FloorRepository.watchFloors` |
| N-06 Building page | same / `NavigatorBuildingRouteScreen`, `NavigatorBuildingScreen` | `/navigator/home/building/:buildingId` | `buildingProvider`, `floorsProvider`, `roomsProvider` |
| N-07 Search | same / `NavigatorSearchScreen` | `/navigator/home/building/:buildingId/search` | `buildingProvider`, `buildingRoomsProvider`, `SearchHistoryService.recordSearch` |
| N-08 Building map | same / `NavigatorBuildingMapScreen` | `/navigator/home/building/:buildingId/map` | `buildingProvider` |
| N-09 Room location | same / `NavigatorRoomLocationRouteScreen`, `NavigatorRoomLocationScreen` | `/navigator/home/building/:buildingId/room/:roomId` | `roomProvider`, `floorsProvider` |

The reusable `BipswayDrawer` is defined in `lib/app/router.dart` and is used by
the shell and by Navigator child screens with a burger icon. Search history is
currently local Hive storage only; Firestore synchronization remains deferred to
the later Settings/search-history phase.
