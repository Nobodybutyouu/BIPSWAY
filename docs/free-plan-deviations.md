# Bipsway free-plan deviations

The project uses the Firebase Spark plan. Cloud Functions are intentionally not
used, and no `functions/` folder should be created.

## Account administration

- The admin bootstrap is performed locally with `scripts/create_admin.js`.
- Account disable/enable updates `users/{uid}.status` from the Admin client.
- Firebase Authentication itself is not disabled by this client-only flow. A
  disabled profile is rejected by Firestore rules and the app signs the user
  out with the message `Your account has been disabled.`
- The Firebase Auth record remains enabled until an administrator disables or
  deletes it manually in the Firebase Console.

## Account deletion

- Admin approval is performed by the client: search-history documents are
  deleted, the user profile is deleted, the user's reports are anonymised, and
  the deletion request is marked approved.
- Firebase Auth user deletion is a separate local script/manual Console step:
  `scripts/delete_auth_user.js` must be run after approval.
- Declining a request only changes its status to `declined`.

## Notifications

- Publishing an announcement only creates the Firestore document.
- Push delivery is performed manually from Firebase Console > Messaging to the
  matching topic, or with the optional local topic-send script when configured.
- The app still subscribes/unsubscribes devices to `map_updates` and
  `campus_announcements` and handles received messages client-side.

## Image storage

- Firebase Storage is not used. Images are uploaded to Cloudinary using the
  configured unsigned upload preset, after client-side compression.
- Image URLs, not base64 image data, are stored in Firestore.

## Deployment commands

Do not run deployment automatically. After reviewing the rules and indexes,
deploy them with:

```powershell
firebase deploy --only firestore:rules,firestore:indexes
```

Install the local script dependency and configure an admin with:

```powershell
cd C:\Users\mark\BIPSWAY\bipsway\scripts
npm install
cd ..
node scripts/create_admin.js YOUR_FIREBASE_AUTH_UID scripts/service-account-key.json
```

After an approved deletion, remove the Firebase Auth record with:

```powershell
node scripts/delete_auth_user.js USER_UID scripts/service-account-key.json
```
