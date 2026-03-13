const admin = require('firebase-admin');
const path = require('path');

// Usage:
// node scripts/backfill_users_public.js
// node scripts/backfill_users_public.js --dry-run
// node scripts/backfill_users_public.js --limit=100
// node scripts/backfill_users_public.js --service-account=/abs/path/key.json

const args = new Set(process.argv.slice(2));
const getArgValue = (name, fallback) => {
  const prefix = `${name}=`;
  for (const arg of args) {
    if (arg.startsWith(prefix)) return arg.slice(prefix.length);
  }
  return fallback;
};

const dryRun = args.has('--dry-run');
const limitArg = getArgValue('--limit', '');
const limit = limitArg ? parseInt(limitArg, 10) : null;
const serviceAccountPath = getArgValue(
  '--service-account',
  path.resolve(__dirname, '..', 'sword-enhance-game-firebase-adminsdk-fbsvc-2ea7f1c924.json'),
);
const projectId = 'sword-enhance-game';

if (limitArg && (!Number.isFinite(limit) || limit <= 0)) {
  console.error(`Invalid --limit value: ${limitArg}`);
  process.exit(1);
}

admin.initializeApp({
  credential: admin.credential.cert(require(serviceAccountPath)),
  projectId,
});

const db = admin.firestore();

function normalizeString(value, fallback = '') {
  return typeof value === 'string' && value.trim() ? value.trim() : fallback;
}

function normalizeLevel(value, fallback = 1) {
  if (typeof value === 'number' && Number.isFinite(value)) return Math.max(0, Math.floor(value));
  if (typeof value === 'string' && value.trim()) {
    const parsed = parseInt(value, 10);
    if (Number.isFinite(parsed)) return Math.max(0, parsed);
  }
  return fallback;
}

function resolveEquippedSword(data) {
  const inventory = Array.isArray(data.inventory) ? data.inventory : [];
  const equippedUid = normalizeString(data.equippedSwordUid, '');

  if (equippedUid) {
    const equipped = inventory.find((item) => item && item.uid === equippedUid);
    if (equipped) {
      return {
        equippedSwordId: normalizeString(equipped.dataId, 'sword_001'),
        equippedSwordLevel: normalizeLevel(equipped.level, 1),
        source: 'inventory',
      };
    }
  }

  return {
    equippedSwordId: normalizeString(data.equippedSwordId, 'sword_001'),
    equippedSwordLevel: normalizeLevel(data.equippedSwordLevel, 1),
    source: 'legacy-fields',
  };
}

function resolveTitleId(data) {
  return normalizeString(data.equippedTitle, normalizeString(data.titleId, 't_01'));
}

function resolveUpdatedAt(data) {
  return data.lastSaved || data.updatedAt || admin.firestore.FieldValue.serverTimestamp();
}

async function backfill() {
  const source = db.collection('users');
  const target = db.collection('users_public');
  const pageSize = 400;

  let lastDoc = null;
  let scanned = 0;
  let changed = 0;

  while (true) {
    let query = source.orderBy(admin.firestore.FieldPath.documentId()).limit(pageSize);
    if (lastDoc) query = query.startAfter(lastDoc);

    const snap = await query.get();
    if (snap.empty) break;

    const batch = db.batch();
    let writeCount = 0;

    for (const doc of snap.docs) {
      scanned++;
      if (limit && scanned > limit) break;

      const data = doc.data() || {};
      const sword = resolveEquippedSword(data);
      const payload = {
        nickname: normalizeString(data.nickname, 'Unknown'),
        equippedSwordId: sword.equippedSwordId,
        equippedSwordLevel: sword.equippedSwordLevel,
        titleId: resolveTitleId(data),
        totalBattle: normalizeLevel(data.totalBattle, 0),
        totalBattleWin: normalizeLevel(data.totalBattleWin, 0),
        updatedAt: resolveUpdatedAt(data),
      };

      if (dryRun) {
        console.log(`[dry-run] ${doc.id}`, { ...payload, _source: sword.source });
      } else {
        batch.set(target.doc(doc.id), payload, { merge: true });
        writeCount++;
      }
      changed++;
    }

    if (!dryRun && writeCount > 0) {
      await batch.commit();
    }

    lastDoc = snap.docs[snap.docs.length - 1];
    console.log(
      `Scanned ${scanned}, prepared ${changed}${dryRun ? ' (dry-run)' : ''}...`,
    );

    if (limit && scanned >= limit) break;
  }

  console.log(
    `Done. Scanned ${scanned}, prepared ${changed}${dryRun ? ' (dry-run)' : ''}.`,
  );
}

backfill().catch((err) => {
  console.error(err);
  process.exit(1);
});
