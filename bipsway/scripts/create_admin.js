#!/usr/bin/env node

const path = require('node:path');
const admin = require('firebase-admin');

const [uid, keyPath] = process.argv.slice(2);
if (!uid) {
  console.error('Usage: node scripts/create_admin.js <firebase-auth-uid> <service-account-key.json>');
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

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

async function main() {
  await admin.auth().setCustomUserClaims(uid, { role: 'admin' });
  await admin.firestore().collection('users').doc(uid).set(
    {
      role: 'admin',
      status: 'active',
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    { merge: true },
  );
  console.log(`Admin role and active status configured for ${uid}.`);
  console.log('The user must sign out and sign in again, or refresh their ID token.');
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
