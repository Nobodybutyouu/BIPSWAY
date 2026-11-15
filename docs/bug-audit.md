# Bipsway bug audit

Audit date: 2026-11-14

Scope: `bipsway/lib/`, `firestore.rules`, `firestore.indexes.json`, `pubspec.yaml`, and `bipsway/test/`. The Functional Specification remains the source of truth.

## Confirmed findings

| ID | Severity | Location | Status | Finding and root cause | Proposed fix |
|---|---|---|---|---|---|
| NAV-001 | Blocker | `bipsway/lib/features/admin/buildings/building_detail_screens.dart:282`, `bipsway/lib/app/router.dart:46-49` | CONFIRMED | Existing-room navigation passes a `Room` as `state.extra`, while the edit route casts it to `Map<String, Object?>`. This causes `type 'Room' is not a subtype of type 'Map<String, Object?>'`. | Stop depending on `extra`; load the room by route ID, or pass a checked map as a short-term fix. |
| NAV-002 | High | `bipsway/lib/app/router.dart:40-46` | CONFIRMED | Buildings, floors, rooms, and pick-location routes are top-level routes rather than children of the Admin Manage branch. They do not retain the Admin shell tabs/drawer. | Nest all Buildings & Rooms routes under the Admin StatefulShellRoute Manage branch. |
| NAV-003 | High | `bipsway/lib/features/admin/buildings/manage_screens.dart:31,198,262,389`, `bipsway/lib/features/admin/buildings/building_detail_screens.dart:65,229`, `bipsway/lib/features/admin/buildings/room_form_screen.dart:136,150` | CONFIRMED | Several child flows use `context.go()`, which replaces the navigation stack. This removes automatic back arrows and can leave the user on a top-level detail route. | Use `push` to open children and `pop` to return when the parent remains on the stack; otherwise navigate to an explicit parent route. |
| NAV-004 | High | `bipsway/lib/app/router.dart:16-21` | CONFIRMED | The global redirect only checks whether a Firebase session exists. A Navigator session can reach `/admin/*` if it navigates there directly. | Add an Admin role guard for `/admin/*`, including a disabled-account check. |
| NAV-005 | High | `bipsway/lib/app/router.dart:38,42-46` | CONFIRMED | Several routes require `state.extra` and use unchecked casts. Direct URLs, hot restart, and deep links can provide no extra and crash or lose the selected object. | Use route IDs and per-document providers; treat extra only as optional initial data. |
| DATA-001 | High | `bipsway/lib/features/admin/buildings/building_detail_screens.dart:38-52,202-218` | CONFIRMED | Detail screens derive a document from a collection stream and an optional initial object. Deletion changes the stream before navigation can finish, allowing a deleted detail screen to render “not found”. | Add per-document providers and an explicit deleting state that renders a loader until navigation completes. |
| DATA-002 | Medium | `bipsway/lib/services/floor_repository.dart:22-38` | CONFIRMED | Floor deletion commits all room deletes and the floor delete in one batch without chunking. Firestore batches have a 500-operation limit. | Chunk floor deletion operations using the same safe strategy as building deletion. |
| DATA-003 | Medium | `bipsway/lib/services/building_repository.dart`, `bipsway/lib/services/floor_repository.dart`, `bipsway/lib/services/room_repository.dart` | CONFIRMED | There are collection/list providers but no per-document building, floor, or room providers. Detail screens are therefore coupled to list-stream timing. | Add `buildingProvider(id)`, `floorProvider(buildingId, floorId)`, and `roomProvider(roomId)` or equivalent document streams. |
| DATA-004 | Medium | `bipsway/lib/features/admin/buildings/building_detail_screens.dart:121-131`, `bipsway/lib/features/admin/buildings/room_form_screen.dart:120-153` | CONFIRMED | Some save/delete operations do not consistently guard double taps or show a success result after returning. | Disable action controls during async operations and show parent-screen success messages. |
| DATA-005 | Medium | `bipsway/lib/features/admin/buildings/building_detail_screens.dart:291-307` | CONFIRMED | Image codec/frame cleanup is only reached on the success path. An exception before cleanup can retain resources. | Move codec/frame cleanup into a `finally` block or use a helper that guarantees disposal. |
| UI-001 | Medium | `bipsway/lib/features/admin/buildings/manage_screens.dart:253` | CONFIRMED | The building row contains an encoding artifact: `Â·` instead of a normal separator. | Replace it with a plain bullet or separator. |
| IMG-001 | Medium | `bipsway/lib/services/image_upload_service.dart:1-20` | CONFIRMED | Shared upload code imports `dart:io` and accepts `File`, so Web builds cannot use the same upload path safely. | Keep the mobile/desktop path and add a web-compatible byte/XFile implementation if Web is required. |
| RULE-001 | High | `bipsway/lib/app/router.dart:12-22`, `firestore.rules` | CONFIRMED | Firestore rules restrict Admin writes, but the client router does not enforce the Admin role before displaying Admin screens. | Add client-side role routing; retain Firestore rules as the authoritative enforcement. |

## Not confirmed / deferred

| ID | Severity | Location | Status | Finding |
|---|---|---|---|---|
| IDX-001 | Low | `firestore.indexes.json` | SUSPECTED | Current rooms query has a matching composite index. Other current queries appear to use single-field ordering or aggregation and should not require extra indexes. Verify against Firebase console when new queries are added. |
| RULE-002 | Medium | `firestore.rules` | SUSPECTED | Existing rules appear to allow Admin building/floor/room operations and deny Navigator writes. Emulator rules tests are not present, so complete behavior should be checked with the Firebase Rules emulator or deployed project. |
| TEST-001 | Medium | `bipsway/test/` | CONFIRMED | Existing tests cover date utilities, room model normalization, pin normalization, and a foundation widget. There are no route, role-guard, delete-loading, or deep-link tests. | Add focused tests during Part B/C. |
| UI-002 | Low | Buildings & Rooms screens | CONFIRMED | Explicit parent back buttons are not consistently present because the routes are outside the Admin shell. | Route restructuring should restore automatic back arrows; retain explicit fallback buttons on detail screens. |
| IMG-002 | Low | Building/floor image screens | SUSPECTED | Upload progress is represented by a busy label, not byte-level progress. | Deferred until the navigation and data correctness fixes are complete. |

## Navigation inventory

- `context.push('/admin/buildings')`: opens Buildings from Manage, but the destination is top-level and therefore leaves the Admin shell.
- `context.push('/admin/buildings/new')`: opens the building form as a top-level route.
- `context.push('/admin/buildings/{id}', extra: building)`: opens Building Detail and depends on optional extra.
- `context.push('/admin/buildings/{id}/edit', extra: building)`: opens edit and depends on optional extra.
- `context.push('/admin/buildings/{id}/floors/{floorId}', extra: floor)`: opens Floor Detail and depends on optional extra.
- `context.push('/admin/.../rooms/new', extra: floor)`: unchecked floor cast; direct URL can fail.
- `context.push('/admin/.../rooms/{roomId}/edit', extra: room)`: confirmed Room-to-Map cast crash.
- `context.go('/admin/buildings?message=...')`: replaces the stack after building save/delete; Buildings list has no parent route in that stack.
- `context.go('/admin/buildings/{buildingId}')`: replaces the stack after floor deletion.
- `context.go('/admin/.../floors/{floorId}')`: replaces the stack after room save/delete.
- `context.pop(...)`: used correctly for Pick Location and confirmation/modal results.

## Part A severity order

1. NAV-001 / room edit crash.
2. NAV-002 / NAV-003 / missing Admin shell and broken back-stack behavior.
3. NAV-004 / RULE-001 / missing Admin client role guard.
4. NAV-005 / DATA-001 / detail screens depending on optional extras and live list streams.
5. DATA-002 / batch-safe floor deletion.
6. DATA-003 / DATA-004 / DATA-005 / state, double-submit, and resource cleanup.
7. UI-001 / encoding artifact.
8. IMG-001 / Web upload portability.

## Final status after Part B changes

| Finding | Final status |
|---|---|
| NAV-001 | Fixed: room edit uses `RoomFormRouteScreen` and ID-based providers; no Room-to-Map cast remains. |
| NAV-002 | Fixed: Buildings, Floors, Rooms, and Pick Location are nested under the Admin Manage shell. |
| NAV-003 | Fixed for Buildings & Rooms: child screens use push; parent-return destinations preserve the Admin shell, and explicit fallback back buttons were added. |
| NAV-004 / RULE-001 | Fixed in client routing: `/admin/*` now checks the Firestore profile role. Firestore rules remain the authoritative protection. |
| NAV-005 | Fixed for Buildings, Floors, and Rooms: route IDs are used; optional extras are no longer required. Pick Location keeps a checked optional LatLng extra. |
| DATA-001 | Fixed: Building and Floor detail screens use per-document providers and intentional delete loading states. |
| DATA-002 | Fixed: floor deletion batches in chunks of 400 operations. |
| DATA-003 | Fixed: per-document Building, Floor, and Room providers were added. |
| DATA-004 | Fixed for room/building/floor delete actions: controls are disabled or replaced by loading states during operations. |
| DATA-005 | Deferred: image codec cleanup should still be moved to a guaranteed `finally` path. |
| UI-001 | Fixed: building count separator was normalized to a plain bullet. |
| UI-002 | Fixed for Buildings & Rooms: Admin shell remains visible and explicit back fallbacks exist. |
| IMG-001 | Deferred: Web upload still needs a separate XFile/byte implementation. |
| IDX-001 | Deferred: current queries have been matched to existing indexes; verify new queries when added. |
| RULE-002 | Deferred: add Firebase Rules Emulator tests before expanding content features. |
| TEST-001 | Partially fixed: ID-only room edit coverage was added; role redirect and delete-loading tests remain to be added or verified with fakes. |
| IMG-002 | Deferred: byte-level upload progress is not yet implemented. |

## Verification status

- Targeted editor diagnostics: no errors found.
- Global Flutter verification must still be run once after dependency state is settled:
  `flutter pub get`, `flutter analyze`, and `flutter test`.
