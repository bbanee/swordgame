const admin = require('firebase-admin');

// Usage:
// node scripts/trim_battle_records.js --limit=30
// node scripts/trim_battle_records.js --limit=30 --dry-run

const args = new Set(process.argv.slice(2));
const getArgValue = (name, fallback) => {
  const prefix = `${name}=`;
  for (const a of args) {
    if (a.startsWith(prefix)) return a.slice(prefix.length);
  }
  return fallback;
};

const limit = parseInt(getArgValue('--limit', '30'), 10);
const dryRun = args.has('--dry-run');

if (!Number.isFinite(limit) || limit <= 0) {
  console.error(`Invalid --limit value: ${limit}`);
  process.exit(1);
}

const serviceAccountPath = 'C:\\dev\\sword_game\\sword-enhance-game-firebase-adminsdk-fbsvc-2ea7f1c924.json';
const projectId = 'sword-enhance-game';

admin.initializeApp({
  credential: admin.credential.cert(require(serviceAccountPath)),
  projectId,
});

const db = admin.firestore();
const users = db.collection('users');

function parseTimestamp(value) {
  if (!value) return 0;
  if (value instanceof admin.firestore.Timestamp) return value.toMillis();
  if (value instanceof Date) return value.getTime();
  if (typeof value === 'string') {
    const t = Date.parse(value);
    return Number.isFinite(t) ? t : 0;
  }
  return 0;
}

function normalizeRecords(records) {
  if (!Array.isArray(records)) return [];
  // Sort by timestamp desc; if missing, keep original order at end.
  return records
    .map((r, idx) => ({ r, idx, ts: parseTimestamp(r && r.timestamp) }))
    .sort((a, b) => {
      if (a.ts === b.ts) return a.idx - b.idx;
      return b.ts - a.ts;
    })
    .map((x) => x.r);
}

async function run() {
  const pageSize = 400; // keep below 500 writes per batch
  let lastDoc = null;
  let scanned = 0;
  let updated = 0;

  while (true) {
    let query = users.orderBy(admin.firestore.FieldPath.documentId()).limit(pageSize);
    if (lastDoc) query = query.startAfter(lastDoc);

    const snap = await query.get();
    if (snap.empty) break;

    const batch = db.batch();
    let writeCount = 0;

    for (const doc of snap.docs) {
      scanned++;
      const data = doc.data() || {};
      const records = normalizeRecords(data.battleRecords);

      if (records.length > limit) {
        const trimmed = records.slice(0, limit);
        if (!dryRun) {
          batch.update(doc.ref, { battleRecords: trimmed });
          writeCount++;
        }
        updated++;
      }
    }

    if (!dryRun && writeCount > 0) {
      await batch.commit();
    }

    lastDoc = snap.docs[snap.docs.length - 1];
    console.log(`Scanned ${scanned}, updated ${updated}${dryRun ? ' (dry-run)' : ''}...`);
  }

  console.log(`Done. Scanned ${scanned}, updated ${updated}${dryRun ? ' (dry-run)' : ''}.`);
}

run().catch((err) => {
  console.error(err);
  process.exit(1);
});
