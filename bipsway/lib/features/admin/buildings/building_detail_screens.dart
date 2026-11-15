import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/widgets/app_network_image.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../../core/widgets/confirm_delete_dialog.dart';
import '../../../models/building.dart';
import '../../../models/floor.dart';
import '../../../models/room.dart';
import '../../../services/building_repository.dart';
import '../../../services/floor_repository.dart';
import '../../../services/image_upload_service.dart';
import '../../../services/room_repository.dart';

class BuildingDetailScreen extends ConsumerStatefulWidget {
  const BuildingDetailScreen({required this.buildingId, this.initial, super.key});

  final String buildingId;
  final Building? initial;

  @override
  ConsumerState<BuildingDetailScreen> createState() => _BuildingDetailScreenState();
}

class _BuildingDetailScreenState extends ConsumerState<BuildingDetailScreen> {
  bool deleting = false;

  @override
  Widget build(BuildContext context) {
    if (deleting) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final buildingValue = ref.watch(buildingProvider(widget.buildingId));
    return buildingValue.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, stack) => Scaffold(body: Center(child: Text(error.toString()))),
      data: (value) {
        final building = value ?? widget.initial;
        if (building == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Building not found')),
            body: Center(child: FilledButton(onPressed: () => context.go('/admin/manage/buildings'), child: const Text('Back to Buildings'))),
          );
        }
        return _BuildingDetailBody(building: building, onDelete: () => _deleteBuilding(building));
      },
    );
  }

  Future<void> _deleteBuilding(Building building) async {
    final confirmed = await ConfirmDeleteDialog.show(
      context,
      title: 'Confirm Delete',
      message: 'This will delete the building, its floors, rooms, and related events.',
    );
    if (!confirmed || !mounted) return;
    setState(() => deleting = true);
    try {
      await ref.read(buildingRepositoryProvider).deleteBuilding(building.id);
      if (mounted) context.go('/admin/manage/buildings?message=${Uri.encodeComponent('Building deleted successfully.')}');
    } catch (error) {
      if (mounted) {
        setState(() => deleting = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    }
  }
}

class _BuildingDetailBody extends ConsumerWidget {
  const _BuildingDetailBody({required this.building, required this.onDelete});
  final Building building;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final floors = ref.watch(floorsProvider(building.id));
    return Scaffold(
      appBar: AppBar(
        title: Text(building.name),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Back to Buildings',
          onPressed: () => Navigator.of(context).canPop()
              ? context.pop()
              : context.go('/admin/manage/buildings'),
        ),
        actions: [
          IconButton(
            onPressed: () => context.push('/admin/manage/buildings/${building.id}/edit'),
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Edit Building',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addFloor(context, ref, building, floors.value ?? const []),
        icon: const Icon(Icons.add),
        label: const Text('Add Floor'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(building.code, style: Theme.of(context).textTheme.titleMedium),
          if (building.description.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(building.description),
          ],
          const SizedBox(height: 16),
          const Text('Floors'),
          const SizedBox(height: 8),
          AsyncValueView<List<Floor>>(
            value: floors,
            emptyMessage: 'No floors yet',
            isEmpty: (items) => items.isEmpty,
            onRetry: () => ref.invalidate(floorsProvider(building.id)),
            builder: (context, items) => Column(
              children: items
                  .map((floor) => _FloorTile(building: building, floor: floor))
                  .toList(),
            ),
          ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: onDelete,
            icon: const Icon(Icons.delete_outline),
            label: const Text('Delete Building'),
          ),
        ],
      ),
    );
  }

  Future<void> _addFloor(
    BuildContext context,
    WidgetRef ref,
    Building building,
    List<Floor> floors,
  ) async {
    final used = floors.map((floor) => floor.number).toSet();
    final available = [1, 2, 3, 4].where((number) => !used.contains(number)).toList();
    if (available.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Floors 1-4 already exist.')));
      return;
    }
    final number = await showModalBottomSheet<int>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          for (final item in available)
            ListTile(title: Text('Floor $item'), onTap: () => Navigator.pop(context, item)),
        ]),
      ),
    );
    if (number == null) return;
    await ref.read(floorRepositoryProvider).save(Floor(
          id: '',
          buildingId: building.id,
          number: number,
          label: 'Floor $number',
          planImageUrl: null,
          imageWidth: null,
          imageHeight: null,
        ));
    ref.invalidate(floorsProvider(building.id));
  }

}

class _FloorTile extends ConsumerWidget {
  const _FloorTile({required this.building, required this.floor});
  final Building building;
  final Floor floor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rooms = ref.watch(roomsProvider(RoomQuery(buildingId: building.id, floorNumber: floor.number)));
    final count = rooms.when(data: (items) => '${items.length} rooms', loading: () => 'Loading rooms...', error: (error, stackTrace) => 'Rooms unavailable');
    return Card(
      child: ListTile(
        title: Text(floor.label),
        subtitle: Text(count),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => context.push('/admin/manage/buildings/${building.id}/floors/${floor.id}'),
      ),
    );
  }
}

class FloorDetailScreen extends ConsumerStatefulWidget {
  const FloorDetailScreen({required this.buildingId, required this.floorId, this.initial, super.key});
  final String buildingId;
  final String floorId;
  final Floor? initial;

  @override
  ConsumerState<FloorDetailScreen> createState() => _FloorDetailScreenState();
}

class _FloorDetailScreenState extends ConsumerState<FloorDetailScreen> {
  bool deleting = false;

  @override
  Widget build(BuildContext context) {
    if (deleting) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final floorValue = ref.watch(floorProvider(FloorQuery(buildingId: widget.buildingId, floorId: widget.floorId)));
    return floorValue.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, stack) => Scaffold(body: Center(child: Text(error.toString()))),
      data: (value) {
        final floor = value ?? widget.initial;
        if (floor == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Floor not found')),
            body: Center(child: FilledButton(onPressed: () => context.go('/admin/manage/buildings/${widget.buildingId}'), child: const Text('Back to Building'))),
          );
        }
        return _FloorDetailBody(floor: floor, onDelete: () => _deleteFloor(floor));
      },
    );
  }

  Future<void> _deleteFloor(Floor floor) async {
    final confirmed = await ConfirmDeleteDialog.show(context, message: 'This will delete the floor and its rooms.');
    if (!confirmed || !mounted) return;
    setState(() => deleting = true);
    try {
      await ref.read(floorRepositoryProvider).deleteFloor(floor);
      if (mounted) context.go('/admin/manage/buildings/${floor.buildingId}');
    } catch (error) {
      if (mounted) {
        setState(() => deleting = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    }
  }
}

class _FloorDetailBody extends ConsumerStatefulWidget {
  const _FloorDetailBody({required this.floor, required this.onDelete});
  final Floor floor;
  final VoidCallback onDelete;

  @override
  ConsumerState<_FloorDetailBody> createState() => _FloorDetailBodyState();
}

class _FloorDetailBodyState extends ConsumerState<_FloorDetailBody> {
  bool busy = false;

  @override
  Widget build(BuildContext context) {
    final rooms = ref.watch(roomsProvider(RoomQuery(buildingId: widget.floor.buildingId, floorNumber: widget.floor.number)));
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.floor.label),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Back to Building',
          onPressed: () => Navigator.of(context).canPop()
              ? context.pop()
              : context.go('/admin/manage/buildings/${widget.floor.buildingId}'),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: widget.floor.planImageUrl == null
            ? null
            : () => context.push('/admin/manage/buildings/${widget.floor.buildingId}/floors/${widget.floor.id}/rooms/new'),
        icon: const Icon(Icons.add),
        label: const Text('Add Room'),
      ),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        if (widget.floor.planImageUrl == null)
          const Card(child: Padding(padding: EdgeInsets.all(16), child: Text('Upload a floor plan before adding rooms.')))
        else
          SizedBox(height: 220, child: AppNetworkImage(url: widget.floor.planImageUrl)),
        const SizedBox(height: 12),
        FilledButton.icon(onPressed: busy ? null : _pickPlan, icon: const Icon(Icons.upload_file), label: Text(busy ? 'Uploading...' : 'Upload / Replace Floor Plan')),
        const SizedBox(height: 20),
        const Text('Rooms'),
        const SizedBox(height: 8),
        AsyncValueView<List<Room>>(
          value: rooms,
          emptyMessage: 'No rooms yet',
          isEmpty: (items) => items.isEmpty,
          onRetry: () => ref.invalidate(roomsProvider(RoomQuery(buildingId: widget.floor.buildingId, floorNumber: widget.floor.number))),
          builder: (context, items) => Column(children: items.map((room) => ListTile(
                title: Text(room.name),
                subtitle: Text(room.code),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/admin/manage/buildings/${widget.floor.buildingId}/floors/${widget.floor.id}/rooms/${room.id}/edit'),
              )).toList()),
        ),
        const SizedBox(height: 20),
        OutlinedButton.icon(onPressed: widget.onDelete, icon: const Icon(Icons.delete_outline), label: const Text('Delete Floor')),
      ]),
    );
  }

  Future<void> _pickPlan() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked == null) return;
    setState(() => busy = true);
    try {
      final bytes = await File(picked.path).readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final imageWidth = frame.image.width.toDouble();
      final imageHeight = frame.image.height.toDouble();
      final url = await imageUploadService.uploadImage(File(picked.path), 'buildings/${widget.floor.buildingId}/floors/${widget.floor.id}');
      await ref.read(floorRepositoryProvider).save(widget.floor.copyWith(planImageUrl: url, imageWidth: imageWidth, imageHeight: imageHeight));
      frame.image.dispose();
      codec.dispose();
      ref.invalidate(floorsProvider(widget.floor.buildingId));
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

}
