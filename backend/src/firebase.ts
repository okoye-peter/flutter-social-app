import { readFileSync } from 'node:fs';
import { cert, initializeApp } from 'firebase-admin/app';
import { getMessaging } from 'firebase-admin/messaging';

const serviceAccount = JSON.parse(
  readFileSync(process.env.FIREBASE_SERVICE_ACCOUNT_PATH ?? './serviceAccountKey.json', 'utf-8')
);

initializeApp({
  credential: cert(serviceAccount),
});

export const messaging = getMessaging();
