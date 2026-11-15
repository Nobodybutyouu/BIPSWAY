import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../../core/utils/date_utils.dart' as app_dates;
import '../../../core/utils/org_chart_utils.dart';
import '../../../core/widgets/app_network_image.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../../core/widgets/confirm_delete_dialog.dart';
import '../../../models/event.dart';
import '../../../models/org_position.dart';
import '../../../models/person.dart';
import '../../../services/building_repository.dart';
import '../../../services/event_repository.dart';
import '../../../services/image_upload_service.dart';
import '../../../services/org_position_repository.dart';
import '../../../services/person_repository.dart';
import '../../../services/room_repository.dart';

class EventDraft {
  const EventDraft({required this.event, required this.isNew, this.dirty = false});
  final Event event;
  final bool isNew;
  final bool dirty;
  EventDraft copyWith({Event? event, bool? dirty}) => EventDraft(event: event ?? this.event, isNew: isNew, dirty: dirty ?? true);
}

Event _newEventDraft() {
  final now = app_dates.nowInManila();
  final start = tz.TZDateTime(app_dates.manilaLocation, now.year, now.month, now.day, now.hour + 1);
  return Event(
    id: '',
    title: '',
    coverImageUrl: null,
    startAt: start,
    endAt: start.add(const Duration(hours: 1)),
    buildingId: '',
    roomId: null,
    locationLabel: '',
    speakers: const [],
    createdAt: null,
    updatedAt: null,
  );
}

class EventDraftNotifier extends Notifier<EventDraft?> {
  @override
  EventDraft? build() => null;

  void begin({Event? event}) {
    state = EventDraft(
      event: event ?? _newEventDraft(),
      isNew: event == null,
    );
  }

  void update(Event event) {
    final current = state;
    if (current != null) state = current.copyWith(event: event);
  }

  void markDirty() {
    final current = state;
    if (current != null && !current.dirty) state = current.copyWith(dirty: true);
  }

  void clear() => state = null;
}

final eventDraftProvider = NotifierProvider<EventDraftNotifier, EventDraft?>(EventDraftNotifier.new);

class EventsListScreen extends ConsumerStatefulWidget {
  const EventsListScreen({super.key});
  @override
  ConsumerState<EventsListScreen> createState() => _EventsListScreenState();
}

class _EventsListScreenState extends ConsumerState<EventsListScreen> {
  String filter = 'All';
  @override
  Widget build(BuildContext context) {
    final events = ref.watch(eventsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Events')),
      floatingActionButton: FloatingActionButton.extended(onPressed: () => context.push('/admin/manage/events/new'), icon: const Icon(Icons.add), label: const Text('Add Event')),
      body: AsyncValueView<List<Event>>(
        value: events,
        emptyMessage: 'No events yet',
        isEmpty: (items) => items.isEmpty,
        onRetry: () => ref.invalidate(eventsProvider),
        builder: (context, items) {
          final now = app_dates.nowInManila();
          final filtered = items.where((event) => filter == 'All' || (filter == 'Upcoming' ? !event.endAt.isBefore(now) : event.endAt.isBefore(now))).toList();
          return Column(children: [
            Padding(padding: const EdgeInsets.all(12), child: Wrap(spacing: 8, children: ['All', 'Upcoming', 'Past'].map((item) => ChoiceChip(label: Text(item), selected: filter == item, onSelected: (_) => setState(() => filter = item))).toList())),
            Expanded(child: filtered.isEmpty ? const Center(child: Text('No events yet')) : ListView.builder(padding: const EdgeInsets.fromLTRB(16, 0, 16, 96), itemCount: filtered.length, itemBuilder: (context, index) {
              final event = filtered[index];
              return Card(child: ListTile(title: Text(event.title), subtitle: Text('${event.locationLabel}\n${_dateRange(event.startAt, event.endAt)}'), isThreeLine: true, onTap: () => context.push('/admin/manage/events/${event.id}/edit')));
            })),
          ]);
        },
      ),
    );
  }
}

class EventFormRouteScreen extends ConsumerWidget {
  const EventFormRouteScreen({this.eventId, super.key});
  final String? eventId;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (eventId == null) return const EventFormScreen();
    return ref.watch(eventProvider(eventId!)).when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, stack) => Scaffold(body: Center(child: Text(error.toString()))),
      data: (event) => event == null ? const _NotFoundPage(title: 'Event not found') : EventFormScreen(initial: event),
    );
  }
}

class EventFormScreen extends ConsumerStatefulWidget {
  const EventFormScreen({this.initial, super.key});
  final Event? initial;
  @override
  ConsumerState<EventFormScreen> createState() => _EventFormScreenState();
}

class _EventFormScreenState extends ConsumerState<EventFormScreen> {
  final key = GlobalKey<FormState>();
  late final TextEditingController title;
  late DateTime date;
  late TimeOfDay start;
  late TimeOfDay end;
  String? buildingId;
  String? roomId;
  String? coverUrl;
  bool busy = false;

  @override
  void initState() {
    super.initState();
    final event = widget.initial;
    final draft = event ?? _newEventDraft();
    title = TextEditingController(text: draft.title);
    date = draft.startAt;
    start = TimeOfDay.fromDateTime(draft.startAt);
    end = TimeOfDay.fromDateTime(draft.endAt);
    buildingId = draft.buildingId.isEmpty ? null : draft.buildingId;
    roomId = draft.roomId;
    coverUrl = draft.coverImageUrl;
    title.addListener(_markDraftDirty);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(eventDraftProvider.notifier).begin(event: event);
    });
  } 

  @override
  void dispose() { title.removeListener(_markDraftDirty); title.dispose(); super.dispose(); }

  void _markDraftDirty() => ref.read(eventDraftProvider.notifier).markDirty();

  @override
  Widget build(BuildContext context) {
    final buildings = ref.watch(buildingsProvider);
    return Scaffold(
      appBar: AppBar(title: Text(widget.initial == null ? 'Add Event' : 'Edit Event'), leading: BackButton(onPressed: _back)),
      body: busy ? const Center(child: CircularProgressIndicator()) : Form(key: key, child: ListView(padding: const EdgeInsets.all(16), children: [
        if (coverUrl != null) SizedBox(height: 140, child: AppNetworkImage(url: coverUrl)),
        OutlinedButton.icon(onPressed: _pickCover, icon: const Icon(Icons.image_outlined), label: const Text('Cover Image (optional)')),
        TextFormField(controller: title, decoration: const InputDecoration(labelText: 'Event Title'), validator: (value) => value == null || value.trim().isEmpty ? 'Required' : null),
        const SizedBox(height: 12),
        ListTile(title: const Text('Date'), subtitle: Text(_date(date)), trailing: const Icon(Icons.calendar_today), onTap: _pickDate),
        Row(children: [Expanded(child: ListTile(title: const Text('Start time'), subtitle: Text(start.format(context)), onTap: () => _pickTime(true))), Expanded(child: ListTile(title: const Text('End time'), subtitle: Text(end.format(context)), onTap: () => _pickTime(false)))]),
        buildings.when(data: (items) => DropdownButtonFormField<String>(value: buildingId, isExpanded: true, decoration: const InputDecoration(labelText: 'Location - Building'), items: items.map((b) => DropdownMenuItem(value: b.id, child: Text(b.name, overflow: TextOverflow.ellipsis))).toList(), onChanged: (value) { ref.read(eventDraftProvider.notifier).markDirty(); setState(() { buildingId = value; roomId = null; }); }, validator: (value) => value == null ? 'Required' : null), loading: () => const LinearProgressIndicator(), error: (e, s) => Text(e.toString())),
        if (buildingId != null) ref.watch(buildingRoomsProvider(buildingId!)).when(data: (items) => DropdownButtonFormField<String>(value: roomId, isExpanded: true, decoration: const InputDecoration(labelText: 'Location - Room (optional)'), items: items.map((room) => DropdownMenuItem<String>(value: room.id, child: Text(room.name, overflow: TextOverflow.ellipsis))).toList(), onChanged: (value) { ref.read(eventDraftProvider.notifier).markDirty(); setState(() => roomId = value); }), loading: () => const SizedBox.shrink(), error: (e, s) => Text(e.toString())),
        const SizedBox(height: 12),
        ListTile(title: Text('Speakers (${ref.watch(eventDraftProvider)?.event.speakers.length ?? 0})'), trailing: const Icon(Icons.chevron_right), onTap: () => context.push(widget.initial == null ? '/admin/manage/events/speakers' : '/admin/manage/events/${widget.initial!.id}/speakers')),
        const SizedBox(height: 12),
        FilledButton(onPressed: _save, child: const Text('Save Event')),
        if (widget.initial != null) OutlinedButton(onPressed: busy ? null : _delete, child: const Text('Delete Event')),
      ])),
    );
  }

  Future<void> _back() async { if (ref.read(eventDraftProvider)?.dirty == true && !await _confirmDiscard()) return; ref.read(eventDraftProvider.notifier).clear(); if (mounted) context.pop(); }
  Future<bool> _confirmDiscard() async => await showDialog<bool>(context: context, builder: (context) => AlertDialog(title: const Text('Discard changes?'), content: const Text('Unsaved event changes will be lost.'), actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Discard'))])) ?? false;
  Future<void> _pickDate() async { final value = await showDatePicker(context: context, firstDate: DateTime(2020), lastDate: DateTime(2100), initialDate: date); if (value != null) { ref.read(eventDraftProvider.notifier).markDirty(); setState(() => date = value); } }
  Future<void> _pickTime(bool isStart) async { final value = await showTimePicker(context: context, initialTime: isStart ? start : end); if (value != null) { ref.read(eventDraftProvider.notifier).markDirty(); setState(() { if (isStart) start = value; else end = value; }); } }
  Future<void> _pickCover() async { final picked = await ImagePicker().pickImage(source: ImageSource.gallery); if (picked == null) return; setState(() => busy = true); try { coverUrl = await imageUploadService.uploadImage(File(picked.path), 'events/draft/cover'); } catch (error) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString()))); } finally { if (mounted) setState(() => busy = false); } }
  Future<void> _save() async {
    if (!key.currentState!.validate() || buildingId == null) return;
    final startDate = tz.TZDateTime(app_dates.manilaLocation, date.year, date.month, date.day, start.hour, start.minute);
    final endDate = tz.TZDateTime(app_dates.manilaLocation, date.year, date.month, date.day, end.hour, end.minute);
    if (!endDate.isAfter(startDate)) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('End time must be after start time.'))); return; }
    final building = await ref.read(buildingRepositoryProvider).watchBuilding(buildingId!).first;
    final room = roomId == null ? null : await ref.read(roomRepositoryProvider).watchRoom(roomId!).first;
    final current = ref.read(eventDraftProvider)?.event;
    if (current == null) return;
    setState(() => busy = true);
    try {
      final updated = current.copyWith(title: title.text, coverImageUrl: coverUrl, startAt: startDate, endAt: endDate, buildingId: buildingId, roomId: roomId, locationLabel: '${building?.name ?? 'Building'}${room == null ? '' : ' · ${room.name}'}');
      await ref.read(eventRepositoryProvider).save(updated);
      ref.read(eventDraftProvider.notifier).clear();
      if (mounted) { context.pop(); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Event saved successfully.'))); }
    } catch (error) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString()))); } finally { if (mounted) setState(() => busy = false); }
  }
  Future<void> _delete() async { if (!await ConfirmDeleteDialog.show(context, message: 'Delete this event?') || !mounted) return; setState(() => busy = true); try { await ref.read(eventRepositoryProvider).delete(widget.initial!.id); if (mounted) { context.pop(); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Event deleted successfully.'))); } } catch (error) { if (mounted) { setState(() => busy = false); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString()))); } } }
}

class EventSpeakersRouteScreen extends ConsumerWidget {
  const EventSpeakersRouteScreen({this.eventId, super.key});
  final String? eventId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (eventId == null) return const EventSpeakersScreen();
    return ref.watch(eventProvider(eventId!)).when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, stack) => Scaffold(body: Center(child: Text('$error'))),
      data: (event) => event == null
          ? const _NotFoundPage(title: 'Event not found')
          : _EventDraftScope(initial: event, child: const EventSpeakersScreen()),
    );
  }
}

class _EventDraftScope extends ConsumerStatefulWidget {
  const _EventDraftScope({required this.initial, required this.child});
  final Event initial;
  final Widget child;
  @override
  ConsumerState<_EventDraftScope> createState() => _EventDraftScopeState();
}

class _EventDraftScopeState extends ConsumerState<_EventDraftScope> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(eventDraftProvider.notifier).begin(event: widget.initial);
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class EventSpeakersScreen extends ConsumerWidget {
  const EventSpeakersScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final draft = ref.watch(eventDraftProvider);
    if (draft == null) return const _NotFoundPage(title: 'Event draft not found');
    final speakers = draft.event.speakers;
    return Scaffold(appBar: AppBar(title: const Text('Speakers'), leading: BackButton(onPressed: () => context.pop())), floatingActionButton: FloatingActionButton.extended(onPressed: () => context.push('/admin/manage/events/speakers/new'), icon: const Icon(Icons.add), label: const Text('Add Speaker')), body: ListView(padding: const EdgeInsets.all(16), children: [if (speakers.isEmpty) const Padding(padding: EdgeInsets.all(24), child: Center(child: Text('No speakers yet'))), ...speakers.asMap().entries.map((entry) => Card(child: ListTile(leading: CircleAvatar(backgroundImage: entry.value.photoUrl == null ? null : NetworkImage(entry.value.photoUrl!)), title: Text(entry.value.name), subtitle: Text('${_dateRange(entry.value.arrivalAt, entry.value.arrivalAt)} · ${entry.value.locationFrom}'), onTap: () => context.push('/admin/manage/events/speakers/${entry.key}/edit')))), const SizedBox(height: 16), OutlinedButton(onPressed: () => context.pop(), child: const Text('Done'))]));
  }
}

class SpeakerFormScreen extends ConsumerStatefulWidget {
  const SpeakerFormScreen({this.index, super.key});
  final int? index;
  @override
  ConsumerState<SpeakerFormScreen> createState() => _SpeakerFormScreenState();
}

class _SpeakerFormScreenState extends ConsumerState<SpeakerFormScreen> {
  final key = GlobalKey<FormState>();
  late final TextEditingController name;
  late final TextEditingController from;
  late DateTime date;
  late TimeOfDay time;
  String? photoUrl;
  bool busy = false;
  @override
  void initState() { super.initState(); final existing = widget.index == null ? null : ref.read(eventDraftProvider)!.event.speakers[widget.index!]; final now = app_dates.nowInManila(); name = TextEditingController(text: existing?.name); from = TextEditingController(text: existing?.locationFrom); date = existing?.arrivalAt ?? now; time = TimeOfDay.fromDateTime(existing?.arrivalAt ?? now); photoUrl = existing?.photoUrl; }
  @override
  void dispose() { name.dispose(); from.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: Text(widget.index == null ? 'Add Speaker' : 'Edit Speaker')), body: busy ? const Center(child: CircularProgressIndicator()) : Form(key: key, child: ListView(padding: const EdgeInsets.all(16), children: [if (photoUrl != null) SizedBox(height: 120, child: AppNetworkImage(url: photoUrl)), OutlinedButton.icon(onPressed: _pickPhoto, icon: const Icon(Icons.image), label: const Text('Photo (optional)')), TextFormField(controller: name, decoration: const InputDecoration(labelText: 'Speaker Name'), validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null), ListTile(title: const Text('Arrival Date'), subtitle: Text(_date(date)), onTap: _pickDate), ListTile(title: const Text('Arrival Time'), subtitle: Text(time.format(context)), onTap: _pickTime), TextField(controller: from, decoration: const InputDecoration(labelText: 'Location From')), const SizedBox(height: 16), FilledButton(onPressed: _save, child: const Text('Save Speaker')), if (widget.index != null) OutlinedButton(onPressed: _delete, child: const Text('Delete Speaker'))])));
  Future<void> _pickPhoto() async { final picked = await ImagePicker().pickImage(source: ImageSource.gallery); if (picked == null) return; setState(() => busy = true); try { photoUrl = await imageUploadService.uploadImage(File(picked.path), 'events/draft/speakers'); } finally { if (mounted) setState(() => busy = false); } }
  Future<void> _pickDate() async { final value = await showDatePicker(context: context, firstDate: DateTime(2020), lastDate: DateTime(2100), initialDate: date); if (value != null) setState(() => date = value); }
  Future<void> _pickTime() async { final value = await showTimePicker(context: context, initialTime: time); if (value != null) setState(() => time = value); }
  void _save() { if (!key.currentState!.validate()) return; final arrival = tz.TZDateTime(app_dates.manilaLocation, date.year, date.month, date.day, time.hour, time.minute); final draft = ref.read(eventDraftProvider)!; final speaker = Speaker(name: name.text, photoUrl: photoUrl, arrivalAt: arrival, locationFrom: from.text); final speakers = [...draft.event.speakers]; if (widget.index == null) speakers.add(speaker); else speakers[widget.index!] = speaker; ref.read(eventDraftProvider.notifier).update(draft.event.copyWith(speakers: speakers)); context.pop(); }
  Future<void> _delete() async { if (!await ConfirmDeleteDialog.show(context, message: 'Delete this speaker?') || !mounted) return; final draft = ref.read(eventDraftProvider)!; final speakers = [...draft.event.speakers]..removeAt(widget.index!); ref.read(eventDraftProvider.notifier).update(draft.event.copyWith(speakers: speakers)); context.pop(); }
}

class OrgChartScreen extends ConsumerWidget {
  const OrgChartScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final positions = ref.watch(orgPositionsProvider('STCS'));
    return Scaffold(
      appBar: AppBar(title: const Text('STCS Organization Chart')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/admin/manage/org-chart/new'),
        icon: const Icon(Icons.add),
        label: const Text('Add Position'),
      ),
      body: positions.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: TextButton(
            onPressed: () => ref.invalidate(orgPositionsProvider('STCS')),
            child: Text('Retry: $error'),
          ),
        ),
        data: (items) {
          final levels = buildOrgLevels(items);
          if (items.isEmpty) return const Center(child: Text('No positions yet'));
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              for (var depth = 0; depth < levels.length; depth++)
                for (final position in levels[depth])
                  Card(
                    margin: EdgeInsets.only(left: 16.0 * depth),
                    child: ListTile(
                      title: Text(position.positionTitle),
                      subtitle: Text(position.fullName),
                      onTap: () => context.push('/admin/manage/org-chart/${position.id}/edit'),
                    ),
                  ),
            ],
          );
        },
      ),
    );
  }
}

class PositionFormRouteScreen extends ConsumerWidget {
  const PositionFormRouteScreen({this.positionId, super.key});
  final String? positionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (positionId == null) return const PositionFormScreen();
    return ref.watch(positionProvider(positionId!)).when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, stack) => Scaffold(body: Center(child: Text('$error'))),
      data: (position) => position == null
          ? const _NotFoundPage(title: 'Position not found')
          : PositionFormScreen(initial: position),
    );
  }
}

class PositionFormScreen extends ConsumerStatefulWidget {
  const PositionFormScreen({this.initial, super.key}); final OrgPosition? initial;
  @override ConsumerState<PositionFormScreen> createState() => _PositionFormScreenState();
}
class _PositionFormScreenState extends ConsumerState<PositionFormScreen> {
  final key = GlobalKey<FormState>();
  late final TextEditingController name;
  late final TextEditingController photo;
  String title = 'Others';
  String? reportsTo;
  bool busy = false;

  @override
  void initState() {
    super.initState();
    name = TextEditingController(text: widget.initial?.fullName);
    photo = TextEditingController(text: widget.initial?.photoUrl);
    title = widget.initial?.positionTitle ?? 'Others';
    reportsTo = widget.initial?.reportsTo;
  }

  @override
  void dispose() { name.dispose(); photo.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final positions = ref.watch(orgPositionsProvider('STCS'));
    return Scaffold(
      appBar: AppBar(title: Text(widget.initial == null ? 'Add Position' : 'Edit Position')),
      body: positions.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Text('$error'),
        data: (items) => Form(
          key: key,
          child: ListView(padding: const EdgeInsets.all(16), children: [
            DropdownButtonFormField<String>(value: title, decoration: const InputDecoration(labelText: 'Position Title'), items: const ['Dean', 'Chairperson', 'Program Head', 'Others'].map((value) => DropdownMenuItem(value: value, child: Text(value))).toList(), onChanged: (value) => setState(() => title = value!)),
            TextFormField(controller: name, decoration: const InputDecoration(labelText: 'Full Name'), validator: (value) => value == null || value.trim().isEmpty ? 'Required' : null),
            const ListTile(title: Text('Department'), subtitle: Text('STCS')),
            DropdownButtonFormField<String>(value: reportsTo, decoration: const InputDecoration(labelText: 'Reports To'), items: [const DropdownMenuItem<String>(value: null, child: Text('None')), ...items.where((position) => position.id != widget.initial?.id).map((position) => DropdownMenuItem(value: position.id, child: Text('${position.positionTitle} - ${position.fullName}')))], onChanged: (value) => setState(() => reportsTo = value)),
            if (photo.text.isNotEmpty) SizedBox(height: 100, child: AppNetworkImage(url: photo.text)),
            OutlinedButton.icon(onPressed: busy ? null : _pickPhoto, icon: const Icon(Icons.image_outlined), label: const Text('Photo (optional)')),
            TextField(controller: photo, decoration: const InputDecoration(labelText: 'Photo URL (optional)')),
            const SizedBox(height: 16),
            FilledButton(onPressed: busy ? null : () => _save(items), child: const Text('Save')),
            if (widget.initial != null) OutlinedButton(onPressed: busy ? null : () => _delete(items), child: const Text('Delete')),
          ]),
        ),
      ),
    );
  }
  Future<void> _save(List<OrgPosition> items) async { if (!key.currentState!.validate()) return; if (wouldCreateOrgCycle(positionId: widget.initial?.id ?? '', reportsTo: reportsTo, positions: items)) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('That Reports To selection would create an organisation cycle.'))); return; } setState(() => busy = true); try { await ref.read(orgPositionRepositoryProvider).save(OrgPosition(id: widget.initial?.id ?? '', department: 'STCS', positionTitle: title, fullName: name.text, reportsTo: reportsTo, photoUrl: photo.text)); if (mounted) { context.pop(); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Position saved successfully.'))); } } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'))); } finally { if (mounted) setState(() => busy = false); } }
  Future<void> _pickPhoto() async { final picked = await ImagePicker().pickImage(source: ImageSource.gallery); if (picked == null) return; setState(() => busy = true); try { photo.text = await imageUploadService.uploadImage(File(picked.path), 'orgChart/${widget.initial?.id ?? 'draft'}/photo'); } catch (error) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$error'))); } finally { if (mounted) setState(() => busy = false); } }
  Future<void> _delete(List<OrgPosition> items) async { if (orgPositionHasChildren(widget.initial!.id, items)) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Reassign or delete child positions first.'))); return; } if (!await ConfirmDeleteDialog.show(context, message: 'Delete this position?') || !mounted) return; setState(() => busy = true); try { await ref.read(orgPositionRepositoryProvider).delete(widget.initial!.id); if (mounted) context.pop(); } catch (e) { if (mounted) { setState(() => busy = false); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'))); } } }
}

class PersonnelListScreen extends ConsumerStatefulWidget {
  const PersonnelListScreen({super.key});
  @override
  ConsumerState<PersonnelListScreen> createState() => _PersonnelListScreenState();
}

class _PersonnelListScreenState extends ConsumerState<PersonnelListScreen> {
  String query = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('University Personnel')),
      floatingActionButton: FloatingActionButton.extended(onPressed: () => context.push('/admin/manage/personnel/new'), icon: const Icon(Icons.add), label: const Text('Add Personnel')),
      body: Column(children: [
        Padding(padding: const EdgeInsets.all(16), child: TextField(decoration: const InputDecoration(labelText: 'Search name or position', prefixIcon: Icon(Icons.search)), onChanged: (value) => setState(() => query = value.toLowerCase()))),
        Expanded(
          child: AsyncValueView<List<Person>>(
            value: ref.watch(personnelProvider),
            emptyMessage: 'No personnel yet',
            isEmpty: (items) => items.isEmpty,
            onRetry: () => ref.invalidate(personnelProvider),
            builder: (context, items) {
              final filtered = items.where((person) => query.isEmpty || person.fullName.toLowerCase().contains(query) || person.position.toLowerCase().contains(query)).toList();
              if (filtered.isEmpty) return const Center(child: Text('No personnel yet'));
              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
                children: [for (final person in filtered) Card(child: ListTile(title: Text(person.fullName), subtitle: Text('${person.position}, ${person.department}'), onTap: () => context.push('/admin/manage/personnel/${person.id}/edit')))],
              );
            },
          ),
        ),
      ]),
    );
  }
}

class PersonFormRouteScreen extends ConsumerWidget { const PersonFormRouteScreen({this.personId, super.key}); final String? personId; @override Widget build(BuildContext context, WidgetRef ref) { if (personId == null) return const PersonFormScreen(); return ref.watch(personProvider(personId!)).when(loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())), error: (e, s) => Scaffold(body: Center(child: Text('$e'))), data: (person) => person == null ? const _NotFoundPage(title: 'Personnel not found') : PersonFormScreen(initial: person)); } }
class PersonFormScreen extends ConsumerStatefulWidget { const PersonFormScreen({this.initial, super.key}); final Person? initial; @override ConsumerState<PersonFormScreen> createState() => _PersonFormScreenState(); }
class _PersonFormScreenState extends ConsumerState<PersonFormScreen> {
  final key = GlobalKey<FormState>();
  late final TextEditingController name;
  late final TextEditingController department;
  late final TextEditingController details;
  late final TextEditingController photo;
  String position = 'Others';
  bool busy = false;

  @override
  void initState() { super.initState(); name = TextEditingController(text: widget.initial?.fullName); department = TextEditingController(text: widget.initial?.department); details = TextEditingController(text: widget.initial?.details); photo = TextEditingController(text: widget.initial?.photoUrl); position = widget.initial?.position ?? 'Others'; }
  @override
  void dispose() { name.dispose(); department.dispose(); details.dispose(); photo.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(widget.initial == null ? 'Add Personnel' : 'Edit Personnel')),
        body: busy ? const Center(child: CircularProgressIndicator()) : Form(
          key: key,
          child: ListView(padding: const EdgeInsets.all(16), children: [
            TextFormField(controller: name, decoration: const InputDecoration(labelText: 'Full Name'), validator: (value) => value == null || value.trim().isEmpty ? 'Required' : null),
            DropdownButtonFormField<String>(value: position, decoration: const InputDecoration(labelText: 'Position'), items: const ['President', 'Professor', 'Instructor', 'Staff', 'Others'].map((value) => DropdownMenuItem(value: value, child: Text(value))).toList(), onChanged: (value) => setState(() => position = value!)),
            TextFormField(controller: department, decoration: const InputDecoration(labelText: 'Department / Office'), validator: (value) => value == null || value.trim().isEmpty ? 'Required' : null),
            TextField(controller: details, decoration: const InputDecoration(labelText: 'Program / Details (optional)')),
            if (photo.text.isNotEmpty) SizedBox(height: 100, child: AppNetworkImage(url: photo.text)),
            OutlinedButton.icon(onPressed: busy ? null : _pickPhoto, icon: const Icon(Icons.image_outlined), label: const Text('Photo (optional)')),
            TextField(controller: photo, decoration: const InputDecoration(labelText: 'Photo URL (optional)')),
            const SizedBox(height: 16),
            FilledButton(onPressed: _save, child: const Text('Save')),
            if (widget.initial != null) OutlinedButton(onPressed: _delete, child: const Text('Delete')),
          ],
        ),
      ),
    );

  Future<void> _save() async { if (!key.currentState!.validate()) return; setState(() => busy = true); try { await ref.read(personRepositoryProvider).save(Person(id: widget.initial?.id ?? '', fullName: name.text, nameLower: name.text.trim().toLowerCase(), position: position, department: department.text, details: details.text, photoUrl: photo.text)); if (mounted) { context.pop(); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Personnel saved successfully.'))); } } catch (error) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$error'))); } finally { if (mounted) setState(() => busy = false); } }
  Future<void> _pickPhoto() async { final picked = await ImagePicker().pickImage(source: ImageSource.gallery); if (picked == null) return; setState(() => busy = true); try { photo.text = await imageUploadService.uploadImage(File(picked.path), 'personnel/${widget.initial?.id ?? 'draft'}/photo'); } catch (error) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$error'))); } finally { if (mounted) setState(() => busy = false); } }
  Future<void> _delete() async { if (!await ConfirmDeleteDialog.show(context, message: 'Delete this personnel record?') || !mounted) return; setState(() => busy = true); try { await ref.read(personRepositoryProvider).delete(widget.initial!.id); if (mounted) context.pop(); } catch (error) { if (mounted) { setState(() => busy = false); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$error'))); } } }
}

class _NotFoundPage extends StatelessWidget { const _NotFoundPage({required this.title}); final String title; @override Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: Text(title)), body: Center(child: FilledButton(onPressed: () => context.pop(), child: const Text('Back')))); }

String _date(DateTime value) => DateFormat('MMM d, yyyy').format(value);
String _dateRange(DateTime start, DateTime end) => '${DateFormat('MMM d, yyyy h:mm a').format(start)}–${DateFormat('h:mm a').format(end)}';
