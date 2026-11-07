#!/usr/bin/env node

const path = require('node:path');
const admin = require('firebase-admin');

const [uid, keyPath] = process.argv.slice(2);
if (!uid) {
  console.error('Usage: node scripts/delete_auth_user.js <firebase-auth-uid> <service-account-key.json>');
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

admin.auth().deleteUser(uid)
  .then(() => console.log(`Firebase Auth user ${uid} deleted.`))
  .catch((error) => {
    console.error(error);
    process.exitCode = 1;
  });
