import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../core/constants/map_config.dart';
import '../../core/utils/navigator_utils.dart';
import '../../core/utils/room_pin_utils.dart';
import '../../core/widgets/app_network_image.dart';
import '../../core/widgets/async_value_view.dart';
import '../../core/widgets/campus_map.dart';
import '../../models/building.dart';
import '../../models/floor.dart';
import '../../models/room.dart';
import '../../services/building_repository.dart';
import '../../services/floor_repository.dart';
import '../../services/room_repository.dart';
import '../../services/search_history_service.dart';

class NavigatorMapHomeScreen extends ConsumerWidget {
  const NavigatorMapHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('BiPSU Map')),
      body: AsyncValueView<List<Building>>(
        value: ref.watch(buildingsProvider),
        emptyMessage: 'No buildings yet',
        isEmpty: (items) => items.isEmpty,
        onRetry: () => ref.invalidate(buildingsProvider),
        builder: (context, buildings) {
          final markers = buildings.where((building) => building.location != null).map((building) {
            final point = LatLng(building.location!.latitude, building.location!.longitude);
            return Marker(
              point: point,
              width: 110,
              height: 70,
              child: GestureDetector(
                onTap: () => _openBuilding(context, building),
                child: Column(children: [
                  Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), color: Colors.white.withValues(alpha: 0.9), child: Text(building.code, overflow: TextOverflow.ellipsis)),
                  const Icon(Icons.location_pin, color: Colors.indigo, size: 42),
                ]),
              ),
            );
          }).toList();
          return CampusMap(center: MapConfig.campusCenter, markers: markers);
        },
      ),
    );
  }

  void _openBuilding(BuildContext context, Building building) {
    if (building.status != BuildingStatus.published) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This building is not available yet.')),
      );
      return;
    }
    // Let the building screen load its floors. This makes every published
    // campus pin respond, even when its content is still being prepared.
    context.push('/navigator/home/building/${building.id}');
  }
}

class NavigatorBuildingRouteScreen extends ConsumerWidget {
  const NavigatorBuildingRouteScreen({required this.buildingId, super.key});
  final String buildingId;

  @override
  Widget build(BuildContext context, WidgetRef ref) => ref.watch(buildingProvider(buildingId)).when(
        loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
        error: (error, stack) => Scaffold(body: Center(child: Text('$error'))),
        data: (building) => building == null
            ? const _NavigatorMessagePage('Building not found')
            : building.status != BuildingStatus.published
                ? const _NavigatorMessagePage('Coming soon')
                : NavigatorBuildingScreen(building: building),
      );
}

class NavigatorBuildingScreen extends ConsumerStatefulWidget {
  const NavigatorBuildingScreen({required this.building, super.key});
  final Building building;
  @override
  ConsumerState<NavigatorBuildingScreen> createState() => _NavigatorBuildingScreenState();
}

class _NavigatorBuildingScreenState extends ConsumerState<NavigatorBuildingScreen> {
  int? selectedFloor;
  int tab = 0;

  @override
  Widget build(BuildContext context) {
    final floors = ref.watch(floorsProvider(widget.building.id));
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.building.name),
        actions: [IconButton(icon: const Icon(Icons.search), onPressed: () => context.push('/navigator/home/building/${widget.building.id}/search'))],
      ),
      body: floors.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: TextButton(onPressed: () => ref.invalidate(floorsProvider(widget.building.id)), child: Text('Retry: $error'))),
        data: (items) {
          if (items.isEmpty) return const _NavigatorMessagePage('Coming soon');
          final numbers = items.map((floor) => floor.number).toList()..sort();
          selectedFloor ??= numbers.first;
          final floorNumber = numbers.contains(selectedFloor) ? selectedFloor! : numbers.first;
          return Column(children: [
            SizedBox(height: 54, child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), children: [for (final number in numbers) Padding(padding: const EdgeInsets.only(right: 8), child: ChoiceChip(label: Text('Floor $number'), selected: number == floorNumber, onSelected: (_) => setState(() => selectedFloor = number)))])),
            Row(children: [for (var index = 0; index < 3; index++) Expanded(child: TextButton(onPressed: () => setState(() => tab = index), child: Text(['${widget.building.code} MAP', 'EVENT', 'ORG STAFF'][index], style: TextStyle(fontWeight: tab == index ? FontWeight.bold : FontWeight.normal))))]),
            Expanded(
              child: tab == 0
                  ? Column(children: [
                      if (widget.building.mapImageUrl != null)
                        SizedBox(
                          height: 220,
                          width: double.infinity,
                          child: InteractiveViewer(
                            minScale: 0.5,
                            maxScale: 4,
                            child: AppNetworkImage(
                              url: widget.building.mapImageUrl,
                              fit: BoxFit.contain,
                            ),
                          ),
                        )
                      else
                        const Padding(
                          padding: EdgeInsets.all(16),
                          child: Text('Building map not available yet.'),
                        ),
                      Expanded(child: _RoomList(building: widget.building, floorNumber: floorNumber)),
                    ])
                  : const Center(child: Text('Coming in the next update')),
            ),
          ]);
        },
      ),
    );
  }
}

class _RoomList extends ConsumerWidget {
  const _RoomList({required this.building, required this.floorNumber});
  final Building building;
  final int floorNumber;

  @override
  Widget build(BuildContext context, WidgetRef ref) => AsyncValueView<List<Room>>(
        value: ref.watch(roomsProvider(RoomQuery(buildingId: building.id, floorNumber: floorNumber))),
        emptyMessage: 'No rooms on this floor yet',
        isEmpty: (items) => items.isEmpty,
        onRetry: () => ref.invalidate(roomsProvider(RoomQuery(buildingId: building.id, floorNumber: floorNumber))),
        builder: (context, rooms) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            for (final room in rooms)
              Card(
                child: ListTile(
                  title: Text(room.name),
                  subtitle: Text(room.code),
                  trailing: FilledButton(
                    onPressed: () {
                      unawaited(searchHistoryService.recordSearch(room, building));
                      context.push('/navigator/home/building/${building.id}/room/${room.id}');
                    },
                    child: const Text('Locate'),
                  ),
                ),
              ),
          ],
        ),
      );
}

class NavigatorSearchScreen extends ConsumerStatefulWidget {
  const NavigatorSearchScreen({required this.buildingId, super.key});
  final String buildingId;
  @override
  ConsumerState<NavigatorSearchScreen> createState() => _NavigatorSearchScreenState();
}

class _NavigatorSearchScreenState extends ConsumerState<NavigatorSearchScreen> {
  final controller = TextEditingController();
  Timer? timer;
  String query = '';

  @override
  void dispose() { timer?.cancel(); controller.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final building = ref.watch(buildingProvider(widget.buildingId));
    final rooms = ref.watch(buildingRoomsProvider(widget.buildingId));
    return Scaffold(
      appBar: AppBar(title: const Text('Search rooms')),
      body: building.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Text('$error'),
        data: (value) {
          if (value == null) return const _NavigatorMessagePage('Building not found');
          return Column(children: [
            Padding(padding: const EdgeInsets.all(16), child: TextField(
              controller: controller,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Search room or code', prefixIcon: Icon(Icons.search)),
              onChanged: (text) {
                timer?.cancel();
                timer = Timer(const Duration(milliseconds: 250), () { if (mounted) setState(() => query = text); });
              },
            )),
            Expanded(child: rooms.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => Center(child: TextButton(onPressed: () => ref.invalidate(buildingRoomsProvider(widget.buildingId)), child: Text('Retry: $error'))),
              data: (items) {
                if (query.trim().isEmpty) return const Center(child: Text('Search by room name or code'));
                final filtered = filterRooms(items, query);
                if (filtered.isEmpty) return const Center(child: Text('No rooms found'));
                return ListView(padding: const EdgeInsets.all(16), children: [
                  for (final room in filtered)
                    Card(child: ListTile(
                      title: Text(room.name),
                      subtitle: Text('Floor ${room.floorNumber} - ${room.code}'),
                      trailing: FilledButton(onPressed: () { unawaited(searchHistoryService.recordSearch(room, value)); context.push('/navigator/home/building/${value.id}/room/${room.id}'); }, child: const Text('Locate')),
                    )),
                ]);
              },
            )),
          ]);
        },
      ),
    );
  }
}

class NavigatorBuildingMapScreen extends ConsumerWidget {
  const NavigatorBuildingMapScreen({required this.buildingId, super.key});
  final String buildingId;

  @override
  Widget build(BuildContext context, WidgetRef ref) => ref.watch(buildingProvider(buildingId)).when(
        loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
        error: (error, stack) => Scaffold(body: Center(child: Text('$error'))),
        data: (building) {
          if (building == null) return const _NavigatorMessagePage('Building not found');
          return Scaffold(
            appBar: AppBar(title: Text('${building.code} building map')),
            body: building.mapImageUrl == null
                ? const Center(child: Text('Map not available yet'))
                : InteractiveViewer(minScale: 0.5, maxScale: 4, child: Center(child: AppNetworkImage(url: building.mapImageUrl, fit: BoxFit.contain))),
          );
        },
      );
}

class NavigatorRoomLocationRouteScreen extends ConsumerWidget {
  const NavigatorRoomLocationRouteScreen({required this.buildingId, required this.roomId, super.key});
  final String buildingId;
  final String roomId;

  @override
  Widget build(BuildContext context, WidgetRef ref) => ref.watch(roomProvider(roomId)).when(
        loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
        error: (error, stack) => Scaffold(body: Center(child: Text('$error'))),
        data: (room) => room == null || room.buildingId != buildingId
            ? const _NavigatorMessagePage('Room not found')
            : NavigatorRoomLocationScreen(buildingId: buildingId, room: room),
      );
}

class NavigatorRoomLocationScreen extends ConsumerWidget {
  const NavigatorRoomLocationScreen({required this.buildingId, required this.room, super.key});
  final String buildingId;
  final Room room;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final floors = ref.watch(floorsProvider(buildingId));
    return floors.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, stack) => Scaffold(body: Center(child: Text('$error'))),
      data: (items) {
        Floor? floor;
        for (final item in items) {
          if (item.number.toString() == room.floorNumber) { floor = item; break; }
        }
        final currentFloor = floor;
        if (currentFloor == null) return const _NavigatorMessagePage('Floor not found');
        return Scaffold(
          appBar: AppBar(title: Text('${room.name} (${room.code})')),
          body: Column(children: [
            Expanded(child: currentFloor.planImageUrl == null ? const Center(child: Text('Floor plan not available yet')) : _PlanWithPin(floor: currentFloor, room: room)),
            Card(margin: EdgeInsets.zero, child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(currentFloor.label, style: Theme.of(context).textTheme.titleMedium), Text(room.name, style: Theme.of(context).textTheme.titleLarge), Text(room.info.isEmpty ? 'Room Info' : room.info)]))),
          ]),
        );
      },
    );
  }
}

class _PlanWithPin extends StatefulWidget {
  const _PlanWithPin({required this.floor, required this.room});
  final Floor floor;
  final Room room;

  @override
  State<_PlanWithPin> createState() => _PlanWithPinState();
}

class _PlanWithPinState extends State<_PlanWithPin> {
  ImageStream? stream;
  ImageStreamListener? listener;
  Size? loadedSize;

  @override
  void initState() {
    super.initState();
    if (widget.floor.imageWidth == null && widget.floor.planImageUrl != null) {
      final imageStream = NetworkImage(widget.floor.planImageUrl!).resolve(const ImageConfiguration());
      final imageListener = ImageStreamListener((info, synchronousCall) {
        if (mounted) setState(() => loadedSize = Size(info.image.width.toDouble(), info.image.height.toDouble()));
      });
      imageStream.addListener(imageListener);
      stream = imageStream;
      listener = imageListener;
    }
  }

  @override
  void dispose() {
    if (stream != null && listener != null) stream!.removeListener(listener!);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final width = widget.floor.imageWidth ?? loadedSize?.width ?? 4;
    final height = widget.floor.imageHeight ?? loadedSize?.height ?? 3;
    return InteractiveViewer(
      minScale: 0.5,
      maxScale: 5,
      child: Center(child: AspectRatio(aspectRatio: width / height, child: LayoutBuilder(builder: (context, constraints) {
        final offset = offsetFromNormalizedPin(widget.room.pin, Size(constraints.maxWidth, constraints.maxHeight));
        return Stack(fit: StackFit.expand, children: [
          Image.network(widget.floor.planImageUrl!, fit: BoxFit.contain, errorBuilder: (context, error, stack) => const Center(child: Icon(Icons.broken_image_outlined))),
          Positioned(left: offset.dx - 16, top: offset.dy - 34, child: Container(decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle), child: const Icon(Icons.location_pin, color: Colors.indigo, size: 42))),
        ]);
      }))),
    );
  }
}

class _NavigatorMessagePage extends StatelessWidget {
  const _NavigatorMessagePage(this.message);
  final String message;
  @override
  Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: Text(message)), body: Center(child: FilledButton(onPressed: () => context.pop(), child: const Text('Back'))));
}
