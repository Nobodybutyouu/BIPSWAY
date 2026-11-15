# Buildings and Rooms code map

## Routes

All Buildings & Rooms routes are children of the Admin StatefulShellRoute Manage branch. This keeps the Admin bottom tabs and drawer visible while a child page is open.

- `/admin/manage` — Manage hub
- `/admin/manage/buildings` — Buildings list
- `/admin/manage/buildings/new` — Add Building
- `/admin/manage/buildings/:buildingId` — Building Detail
- `/admin/manage/buildings/:buildingId/edit` — Edit Building
- `/admin/manage/buildings/:buildingId/floors/:floorId` — Floor Detail
- `/admin/manage/buildings/:buildingId/floors/:floorId/rooms/new` — Add Room
- `/admin/manage/buildings/:buildingId/floors/:floorId/rooms/:roomId/edit` — Edit Room
- `/admin/manage/pick-location` — Pick Location

## Data loading

- `buildingProvider(buildingId)` loads one building document.
- `floorProvider(FloorQuery(buildingId, floorId))` loads one floor document.
- `roomProvider(roomId)` loads one room document.
- List providers remain available for Buildings, Floors, and Rooms lists.
- Route screens receive IDs from the URL. `state.extra` is not required for Buildings, Floors, or Rooms.

## Navigation rules

- Manage opens Buildings with `push`.
- Buildings opens Building Detail with `push`.
- Building Detail opens Edit Building and Floor Detail with `push`.
- Floor Detail opens Room Add/Edit with `push`.
- Save/delete returns to the appropriate parent route after the async operation succeeds.
- Each Buildings & Rooms screen has an explicit fallback back button for direct/deep-linked entry.

## Delete behavior

- Building delete shows a loader before deleting and returns to the Buildings list.
- Floor delete deletes rooms and the floor in chunks of 400 operations and returns to Building Detail.
- Room delete shows a loader and returns to Floor Detail.
- A deleted document is not allowed to render a transient “not found” state during its intentional delete flow.
