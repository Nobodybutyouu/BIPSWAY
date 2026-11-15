import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/constants/map_config.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../../core/widgets/campus_map.dart';
import '../../../core/widgets/app_network_image.dart';
import '../../../models/building.dart';
import '../../../services/building_repository.dart';
import '../../../services/image_upload_service.dart';
import '../../../services/room_repository.dart';
import '../../../services/event_repository.dart';
import '../../../services/person_repository.dart';

class ManageHubScreen extends StatelessWidget {
  const ManageHubScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Manage')),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _ManageRow(
              title: 'Buildings & Rooms',
              icon: Icons.location_city_outlined,
              onTap: () => context.push('/admin/manage/buildings'),
            ),
            _ManageRow(
              title: 'Announcements & Map Updates',
              icon: Icons.campaign_outlined,
              onTap: () => context.push('/admin/coming-soon/announcements'),
            ),
            _ManageRow(
              title: 'Events',
              icon: Icons.event_outlined,
              onTap: () => context.push('/admin/manage/events'),
            ),
            _ManageRow(
              title: 'STCS Org Chart',
              icon: Icons.account_tree_outlined,
              onTap: () => context.push('/admin/manage/org-chart'),
            ),
            _ManageRow(
              title: 'University Personnel',
              icon: Icons.people_outline,
              onTap: () => context.push('/admin/manage/personnel'),
            ),
          ],
        ),
      );
}

class _ManageRow extends StatelessWidget {
  const _ManageRow({required this.title, required this.icon, required this.onTap});

  final String title;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
        child: ListTile(
          leading: Icon(icon),
          title: Text(title),
          trailing: const Icon(Icons.chevron_right),
          onTap: onTap,
        ),
      );
}

class ComingSoonScreen extends StatelessWidget {
  const ComingSoonScreen({required this.title, super.key});
  final String title;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(title)),
        body: const Center(child: Text('Coming soon')),
      );
}

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final buildings = ref.watch(buildingCountProvider);
    final rooms = ref.watch(roomCountProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Dashboard')),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(buildingCountProvider);
          ref.invalidate(roomCountProvider);
          await Future<void>.delayed(Duration.zero);
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('Welcome, Admin', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(child: _CountCard(title: 'Buildings', value: buildings)),
              const SizedBox(width: 12),
              Expanded(child: _CountCard(title: 'Rooms', value: rooms)),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: _CountCard(title: 'Events', value: ref.watch(eventCountProvider))),
              const SizedBox(width: 12),
              Expanded(child: _CountCard(title: 'Personnel', value: ref.watch(personnelCountProvider))),
            ]),
            const SizedBox(height: 12),
            const Row(children: [
              Expanded(child: _StaticCountCard(title: 'Unread Reports', value: '-')),
              SizedBox(width: 12),
              Expanded(child: _StaticCountCard(title: 'Delete Requests', value: '-')),
            ]),
          ],
        ),
      ),
    );
  }
}

class _CountCard extends StatelessWidget {
  const _CountCard({required this.title, required this.value});
  final String title;
  final AsyncValue<int> value;

  @override
  Widget build(BuildContext context) => value.when(
        loading: () => const _StaticCountCard(title: 'Loading', value: '...'),
        error: (error, stackTrace) => _StaticCountCard(title: title, value: '-'),
        data: (number) => _StaticCountCard(title: title, value: '$number'),
      );
}

class _StaticCountCard extends StatelessWidget {
  const _StaticCountCard({required this.title, required this.value});
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title),
            const SizedBox(height: 8),
            Text(value, style: Theme.of(context).textTheme.headlineMedium),
          ]),
        ),
      );
}

class BuildingsListScreen extends ConsumerStatefulWidget {
  const BuildingsListScreen({this.message, super.key});

  final String? message;

  @override
  ConsumerState<BuildingsListScreen> createState() => _BuildingsListScreenState();
}

class _BuildingsListScreenState extends ConsumerState<BuildingsListScreen> {
  final searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.message != null && widget.message!.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(widget.message!)));
        }
      });
    }
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final buildings = ref.watch(buildingsProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Buildings'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Back to Manage',
          onPressed: () => Navigator.of(context).canPop()
              ? context.pop()
              : context.go('/admin/manage'),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/admin/manage/buildings/new'),
        icon: const Icon(Icons.add),
        label: const Text('Add Building'),
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: TextField(
            controller: searchController,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              labelText: 'Search buildings',
              prefixIcon: Icon(Icons.search),
            ),
          ),
        ),
        Expanded(
          child: AsyncValueView<List<Building>>(
            value: buildings,
            emptyMessage: 'No buildings yet',
            isEmpty: (items) => items.isEmpty,
            onRetry: () => ref.invalidate(buildingsProvider),
            builder: (context, items) {
              final query = searchController.text.trim().toLowerCase();
              final filtered = items.where((building) {
                return query.isEmpty ||
                    building.name.toLowerCase().contains(query) ||
                    building.code.toLowerCase().contains(query);
              }).toList();
              if (filtered.isEmpty) return const Center(child: Text('No buildings yet'));
              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                itemCount: filtered.length,
                itemBuilder: (context, index) => _BuildingTile(building: filtered[index]),
              );
            },
          ),
        ),
      ]),
    );
  }
}

class _BuildingTile extends ConsumerWidget {
  const _BuildingTile({required this.building});
  final Building building;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final counts = ref.watch(buildingCountsProvider(building.id));
    return Card(
      child: ListTile(
        title: Text(building.name),
        subtitle: counts.when(
          loading: () => Text(building.code),
          error: (error, stackTrace) => Text(building.code),
          data: (value) => Text('${building.code} · ${value.floors} floors · ${value.rooms} rooms'),
        ),
        trailing: Chip(
          label: Text(building.status == BuildingStatus.published ? 'Published' : 'Draft'),
          backgroundColor: building.status == BuildingStatus.published
              ? Colors.green.shade100
              : Colors.amber.shade100,
        ),
        onTap: () => context.push('/admin/manage/buildings/${building.id}'),
      ),
    );
  }
}

class BuildingFormScreen extends ConsumerStatefulWidget {
  const BuildingFormScreen({this.initial, super.key});
  final Building? initial;

  @override
  ConsumerState<BuildingFormScreen> createState() => _BuildingFormScreenState();
}

class _BuildingFormScreenState extends ConsumerState<BuildingFormScreen> {
  final formKey = GlobalKey<FormState>();
  late final TextEditingController nameController;
  late final TextEditingController codeController;
  late final TextEditingController descriptionController;
  late BuildingStatus status;
  GeoPoint? location;
  String? mapImageUrl;
  bool busy = false;

  @override
  void initState() {
    super.initState();
    final building = widget.initial;
    nameController = TextEditingController(text: building?.name);
    codeController = TextEditingController(text: building?.code);
    descriptionController = TextEditingController(text: building?.description);
    status = building?.status ?? BuildingStatus.draft;
    location = building?.location;
    mapImageUrl = building?.mapImageUrl;
  }

  @override
  void dispose() {
    nameController.dispose();
    codeController.dispose();
    descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selected = location == null
        ? MapConfig.campusCenter
        : LatLng(location!.latitude, location!.longitude);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.initial == null ? 'Add Building' : 'Edit Building'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Back to Buildings',
          onPressed: () => Navigator.of(context).canPop()
              ? context.pop()
              : context.go('/admin/manage/buildings'),
        ),
      ),
      body: Form(
        key: formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(controller: nameController, decoration: const InputDecoration(labelText: 'Building Name'), validator: _required),
            const SizedBox(height: 12),
            TextFormField(controller: codeController, decoration: const InputDecoration(labelText: 'Building Code'), validator: _required),
            const SizedBox(height: 12),
            TextFormField(controller: descriptionController, maxLines: 3, decoration: const InputDecoration(labelText: 'Description')),
            const SizedBox(height: 12),
            DropdownButtonFormField<BuildingStatus>(
              initialValue: status,
              decoration: const InputDecoration(labelText: 'Status'),
              items: const [
                DropdownMenuItem(value: BuildingStatus.published, child: Text('Published')),
                DropdownMenuItem(value: BuildingStatus.draft, child: Text('Draft')),
              ],
              onChanged: (value) => setState(() => status = value!),
            ),
            const SizedBox(height: 12),
            SizedBox(height: 180, child: CampusMap(center: selected, zoom: 16, interactive: false, markers: [campusMarker(selected)])),
            Text(MapConfig.campusCenterNote, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 8),
            OutlinedButton.icon(onPressed: _pickLocation, icon: const Icon(Icons.location_on_outlined), label: const Text('Pick Location on Map')),
            const SizedBox(height: 12),
            if (mapImageUrl != null) SizedBox(height: 160, child: AppNetworkImage(url: mapImageUrl)),
            OutlinedButton.icon(onPressed: busy ? null : _pickMapImage, icon: const Icon(Icons.image_outlined), label: const Text('Building Map Image (ground to 4th floor)')),
            const SizedBox(height: 16),
            FilledButton(onPressed: busy ? null : _save, child: Text(busy ? 'Saving...' : 'Save Building')),
          ],
        ),
      ),
    );
  }

  String? _required(String? value) => value == null || value.trim().isEmpty ? 'Required' : null;

  Future<void> _pickLocation() async {
    final initial = location == null ? MapConfig.campusCenter : LatLng(location!.latitude, location!.longitude);
    final selected = await context.push<LatLng>('/admin/manage/pick-location', extra: initial);
    if (selected != null) setState(() => location = GeoPoint(selected.latitude, selected.longitude));
  }

  Future<void> _pickMapImage() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked == null) return;
    setState(() => busy = true);
    try {
      mapImageUrl = await imageUploadService.uploadImage(
        File(picked.path),
        'buildings/${widget.initial?.id ?? 'draft'}',
      );
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _save() async {
    if (!formKey.currentState!.validate()) return;
    setState(() => busy = true);
    try {
      final building = Building(
        id: widget.initial?.id ?? '',
        code: codeController.text,
        name: nameController.text,
        description: descriptionController.text,
        location: location,
        mapImageUrl: mapImageUrl,
        status: status,
        updatedAt: null,
      );
      await ref.read(buildingRepositoryProvider).save(building);
      if (mounted) {
        context.go('/admin/manage/buildings?message=${Uri.encodeComponent('Building saved successfully.')}');
      }
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }
}

class PickLocationScreen extends StatefulWidget {
  const PickLocationScreen({this.initial, super.key});
  final LatLng? initial;

  @override
  State<PickLocationScreen> createState() => _PickLocationScreenState();
}

class BuildingEditRouteScreen extends ConsumerWidget {
  const BuildingEditRouteScreen({required this.buildingId, super.key});

  final String buildingId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final building = ref.watch(buildingProvider(buildingId));
    return building.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, stackTrace) => Scaffold(body: Center(child: Text(error.toString()))),
      data: (value) => value == null
          ? Scaffold(
              appBar: AppBar(title: const Text('Building not found')),
              body: Center(child: FilledButton(onPressed: () => context.pop(), child: const Text('Back'))),
            )
          : BuildingFormScreen(initial: value),
    );
  }
}

class _PickLocationScreenState extends State<PickLocationScreen> {
  late LatLng selected;

  @override
  void initState() {
    super.initState();
    selected = widget.initial ?? MapConfig.campusCenter;
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('Pick Location'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            tooltip: 'Back',
            onPressed: () => Navigator.of(context).canPop()
                ? context.pop()
                : context.go('/admin/manage/buildings'),
          ),
        ),
        body: Column(children: [
          Padding(padding: const EdgeInsets.all(12), child: Text('Tap the map to place or move the marker.')),
          Expanded(child: CampusMap(center: selected, markers: [campusMarker(selected)], onTap: (point) => setState(() => selected = point))),
          Padding(
            padding: const EdgeInsets.all(16),
            child: FilledButton(onPressed: () => context.pop(selected), child: const Text('Confirm Location')),
          ),
        ]),
      );
}
