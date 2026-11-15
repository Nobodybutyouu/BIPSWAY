# Events, Org Chart and Personnel code map

All new Admin routes are inside the Admin StatefulShellRoute `Manage` branch.
They receive IDs from route parameters; they do not require `state.extra`.

| Screen | File/class | Route | Providers |
| --- | --- | --- | --- |
| A-11 Events list | `lib/features/admin/content/admin_content_screens.dart` / `EventsListScreen` | `/admin/manage/events` | `eventsProvider` |
| A-12 Add/Edit Event | same / `EventFormRouteScreen`, `EventFormScreen` | `/admin/manage/events/new`, `/admin/manage/events/:eventId/edit` | `eventProvider`, `buildingsProvider`, `buildingRoomsProvider`, `eventDraftProvider` |
| A-13 Speakers | same / `EventSpeakersScreen` | `/admin/manage/events/speakers`, `/admin/manage/events/:eventId/speakers` | `eventDraftProvider` |
| A-14 Add/Edit Speaker | same / `SpeakerFormScreen` | speaker child routes | `eventDraftProvider` |
| A-15 Org chart | same / `OrgChartScreen` | `/admin/manage/org-chart` | `orgPositionsProvider('STCS')` |
| A-16 Add/Edit Position | same / `PositionFormRouteScreen`, `PositionFormScreen` | `/admin/manage/org-chart/new`, `/admin/manage/org-chart/:positionId/edit` | `positionProvider`, `orgPositionsProvider('STCS')` |
| A-17 Personnel | same / `PersonnelListScreen` | `/admin/manage/personnel` | `personnelProvider` |
| A-18 Add/Edit Personnel | same / `PersonFormRouteScreen`, `PersonFormScreen` | `/admin/manage/personnel/new`, `/admin/manage/personnel/:personId/edit` | `personProvider`, `personRepositoryProvider` |

Event drafts remain in Riverpod memory until Save Event. Speaker edits update the
draft array; no event document is created for an unsaved event.
