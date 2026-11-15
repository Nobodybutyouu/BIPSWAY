import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/room_pin_utils.dart';
import '../../../core/widgets/confirm_delete_dialog.dart';
import '../../../models/floor.dart';
import '../../../models/room.dart';
import '../../../services/floor_repository.dart';
import '../../../services/room_repository.dart';

class RoomFormRouteScreen extends ConsumerWidget {
  const RoomFormRouteScreen({required this.buildingId, required this.floorId, this.roomId, super.key});

  final String buildingId;
  final String floorId;
  final String? roomId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final floor = ref.watch(floorProvider(FloorQuery(buildingId: buildingId, floorId: floorId)));
    return floor.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, stackTrace) => Scaffold(body: Center(child: Text(error.toString()))),
      data: (value) {
        if (value == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Floor not found')),
            body: Center(child: FilledButton(onPressed: () => context.pop(), child: const Text('Back'))),
          );
        }
        if (roomId == null) return RoomFormScreen(floor: value);
        final room = ref.watch(roomProvider(roomId!));
        return room.when(
          loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
          error: (error, stackTrace) => Scaffold(body: Center(child: Text(error.toString()))),
          data: (roomValue) => roomValue == null
              ? Scaffold(
                  appBar: AppBar(title: const Text('Room not found')),
                  body: Center(child: FilledButton(onPressed: () => context.pop(), child: const Text('Back'))),
                )
              : RoomFormScreen(floor: value, initial: roomValue),
        );
      },
    );
  }
}

class RoomFormScreen extends ConsumerStatefulWidget {
  const RoomFormScreen({required this.floor, this.initial, super.key});

  final Floor floor;
  final Room? initial;

  @override
  ConsumerState<RoomFormScreen> createState() => _RoomFormScreenState();
}

class _RoomFormScreenState extends ConsumerState<RoomFormScreen> {
  final formKey = GlobalKey<FormState>();
  final imageKey = GlobalKey();
  late final TextEditingController nameController;
  late final TextEditingController codeController;
  late final TextEditingController infoController;
  late RoomPin pin;
  bool busy = false;

  @override
  void initState() {
    super.initState();
    nameController = TextEditingController(text: widget.initial?.name);
    codeController = TextEditingController(text: widget.initial?.code);
    infoController = TextEditingController(text: widget.initial?.info);
    pin = widget.initial?.pin ?? const RoomPin(x: 0.5, y: 0.5);
  }

  @override
  void dispose() {
    nameController.dispose();
    codeController.dispose();
    infoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (busy) {
      return Scaffold(
        appBar: AppBar(title: const Text('Room Pin Placement')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    final width = widget.floor.imageWidth ?? 1000;
    final height = widget.floor.imageHeight ?? 700;
    if (widget.floor.planImageUrl == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Add / Edit Room')),
        body: const Center(child: Text('Upload a floor plan first on the Floor Detail page.')),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Room Pin Placement'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Back to Floor',
          onPressed: () => Navigator.of(context).canPop()
              ? context.pop()
              : context.go('/admin/manage/buildings/${widget.floor.buildingId}/floors/${widget.floor.id}'),
        ),
      ),
      body: Form(
        key: formKey,
        child: ListView(padding: const EdgeInsets.all(16), children: [
          SizedBox(
            height: 320,
            child: InteractiveViewer(
              boundaryMargin: const EdgeInsets.all(120),
              minScale: 0.5,
              maxScale: 4,
              child: SizedBox(
                key: imageKey,
                width: width,
                height: height,
                child: GestureDetector(
                  onTapDown: (details) => _setPin(details.localPosition, Size(width, height)),
                  child: Stack(fit: StackFit.expand, children: [
                    Image.network(widget.floor.planImageUrl!, fit: BoxFit.fill),
                    Positioned(
                      left: pin.x * width - 18,
                      top: pin.y * height - 36,
                      child: GestureDetector(
                        onPanUpdate: (details) => _setPinFromGlobal(details.globalPosition, Size(width, height)),
                        child: const Icon(Icons.location_pin, color: Colors.red, size: 40),
                      ),
                    ),
                  ]),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Text('Tap the floor plan or drag the pin. Zooming and panning preserve normalized coordinates.'),
          const SizedBox(height: 16),
          TextFormField(controller: nameController, decoration: const InputDecoration(labelText: 'Room Name'), validator: _required),
          const SizedBox(height: 12),
          TextFormField(controller: codeController, decoration: const InputDecoration(labelText: 'Room Code'), validator: _required),
          const SizedBox(height: 12),
          TextFormField(controller: infoController, maxLines: 3, decoration: const InputDecoration(labelText: 'Room Info')),
          const SizedBox(height: 16),
          FilledButton(onPressed: busy ? null : _save, child: Text(busy ? 'Saving...' : 'Save Room')),
          if (widget.initial != null) ...[
            const SizedBox(height: 8),
            OutlinedButton.icon(onPressed: busy ? null : _delete, icon: const Icon(Icons.delete_outline), label: const Text('Delete Room')),
          ],
        ]),
      ),
    );
  }

  String? _required(String? value) => value == null || value.trim().isEmpty ? 'Required' : null;

  void _setPin(Offset offset, Size size) {
    setState(() => pin = normalizedPinFromOffset(offset, size));
  }

  void _setPinFromGlobal(Offset global, Size size) {
    final renderObject = imageKey.currentContext?.findRenderObject();
    if (renderObject is! RenderBox) return;
    _setPin(renderObject.globalToLocal(global), size);
  }

  Future<void> _save() async {
    if (!formKey.currentState!.validate()) return;
    setState(() => busy = true);
    try {
      final room = Room(
        id: widget.initial?.id ?? '',
        buildingId: widget.floor.buildingId,
        floorNumber: widget.floor.number.toString(),
        name: nameController.text,
        code: codeController.text,
        info: infoController.text,
        pin: pin,
        nameLower: nameController.text.trim().toLowerCase(),
        codeLower: codeController.text.trim().toLowerCase(),
      );
      await ref.read(roomRepositoryProvider).save(room);
      if (mounted) context.go('/admin/manage/buildings/${widget.floor.buildingId}/floors/${widget.floor.id}');
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _delete() async {
    final confirmed = await ConfirmDeleteDialog.show(context);
    if (!confirmed) return;
    setState(() => busy = true);
    try {
      await ref.read(roomRepositoryProvider).delete(widget.initial!);
      if (mounted) context.go('/admin/manage/buildings/${widget.floor.buildingId}/floors/${widget.floor.id}');
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }
}
