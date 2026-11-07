#!/usr/bin/env node

const path = require('node:path');
const admin = require('firebase-admin');

const [announcementId, keyPath] = process.argv.slice(2);
if (!announcementId) {
  console.error('Usage: node scripts/send_announcement_push.js <announcement-id> <service-account-key.json>');
  process.exit(1);
}

const resolvedKeyPath = path.resolve(keyPath || 'scripts/service-account-key.json');
let serviceAccount;
try {
  serviceAccount = require(resolvedKeyPath);
} catch (error) {
  console.error(`Could not read service account key: ${resolvedKeyPath}`);
  console.error(error.message);
  process.exit(1);
}

admin.initializeApp({credential: admin.credential.cert(serviceAccount)});

async function main() {
  const snapshot = await admin.firestore().collection('announcements').doc(announcementId).get();
  if (!snapshot.exists) throw new Error(`Announcement ${announcementId} was not found.`);
  const announcement = snapshot.data();
  const topic = announcement.type === 'map_update' ? 'map_updates' : 'campus_announcements';
  await admin.messaging().send({
    topic,
    notification: {title: announcement.title, body: announcement.message},
    data: {announcementId, type: announcement.type},
  });
  console.log(`Announcement ${announcementId} sent to ${topic}.`);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
