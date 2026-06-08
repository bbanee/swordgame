const admin = require('firebase-admin');
const path = require('path');

// Usage:
// timeout 20s node scripts/grant_hidden_sword.js --nickname=은우 --dry-run
// timeout 20s node scripts/grant_hidden_sword.js --nickname=은우
// timeout 20s node scripts/grant_hidden_sword.js --nickname=은우 --sword-id=hidden_0 --level=34
// timeout 20s node scripts/grant_hidden_sword.js --nickname=은우 --sword-id=immortal_0 --level=0
// timeout 20s node scripts/grant_hidden_sword.js --nickname=은우 --sword-id=hidden_0 --level=34 --update-existing

const args = new Set(process.argv.slice(2));
const getArgValue = (name, fallback) => {
  const prefix = `${name}=`;
  for (const arg of args) {
    if (arg.startsWith(prefix)) return arg.slice(prefix.length);
  }
  return fallback;
};

const nickname = getArgValue('--nickname', '').trim();
const swordId = getArgValue('--sword-id', 'hidden_0').trim();
const levelArg = getArgValue('--level', '34').trim();
const level = Number.parseInt(levelArg, 10);
const dryRun = args.has('--dry-run');
const updateExisting = args.has('--update-existing');
const serviceAccountPath = getArgValue(
  '--service-account',
  path.resolve(
    __dirname,
    '..',
    'sword-enhance-game-firebase-adminsdk-fbsvc-2ea7f1c924.json',
  ),
);
const projectId = 'sword-enhance-game';
const maxInventoryLimit = 20;
const maxBreakthroughLevel = 3;

if (!nickname) {
  console.error('Missing --nickname value.');
  process.exit(1);
}

if (!/^(hidden|immortal)_\d+$/.test(swordId)) {
  console.error(`Invalid sword id: ${swordId}`);
  process.exit(1);
}

if (!Number.isFinite(level) || level < 0) {
  console.error(`Invalid --level value: ${levelArg}`);
  process.exit(1);
}

admin.initializeApp({
  credential: admin.credential.cert(require(serviceAccountPath)),
  projectId,
});

const db = admin.firestore();

function normalizeInventory(value) {
  return Array.isArray(value) ? value.filter((item) => item && typeof item === 'object') : [];
}

function normalizeInt(value, fallback) {
  if (typeof value === 'number' && Number.isFinite(value)) return Math.floor(value);
  if (typeof value === 'string' && value.trim()) {
    const parsed = Number.parseInt(value, 10);
    if (Number.isFinite(parsed)) return parsed;
  }
  return fallback;
}

function makeUid() {
  const rand = Math.random().toString(36).slice(2, 10);
  return `grant_${Date.now()}_${rand}`;
}

function getBreakthroughLevelForEnhanceLevel(levelValue) {
  if (levelValue <= 30) return 0;
  return Math.min(Math.ceil((levelValue - 30) / 5), maxBreakthroughLevel);
}

async function run() {
  const snap = await db
    .collection('users')
    .where('nickname', '==', nickname)
    .get();

  if (snap.empty) {
    console.error(`No user found for nickname: ${nickname}`);
    process.exit(2);
  }

  if (snap.size > 1) {
    console.error(`Multiple users found for nickname: ${nickname}`);
    for (const doc of snap.docs) {
      console.error(`- ${doc.id}`);
    }
    process.exit(3);
  }

  const doc = snap.docs[0];
  const data = doc.data() || {};
  const inventory = normalizeInventory(data.inventory);
  const maxInventory = normalizeInt(data.maxInventory, 10);
  const breakthroughLevel = getBreakthroughLevelForEnhanceLevel(level);

  const matchingIndexes = inventory
    .map((item, index) => ({ item, index }))
    .filter(({ item }) => item.dataId === swordId && normalizeInt(item.level, -1) === level);

  let nextInventory = inventory;
  let grantedSword = null;
  let operation = 'grant';

  if (updateExisting) {
    if (matchingIndexes.length === 0) {
      console.error(
        `No existing sword found for uid=${doc.id}, swordId=${swordId}, level=${level}.`,
      );
      process.exit(5);
    }

    if (matchingIndexes.length > 1) {
      console.error(
        `Multiple existing swords found for uid=${doc.id}, swordId=${swordId}, level=${level}.`,
      );
      for (const match of matchingIndexes) {
        console.error(`- inventory[${match.index}] uid=${match.item.uid}`);
      }
      process.exit(6);
    }

    const matchIndex = matchingIndexes[0].index;
    grantedSword = {
      ...inventory[matchIndex],
      breakthroughLevel,
    };
    nextInventory = [...inventory];
    nextInventory[matchIndex] = grantedSword;
    operation = 'update-existing';
  } else {
    if (inventory.length >= maxInventory && maxInventory >= maxInventoryLimit) {
      console.error(
        `Inventory is full for uid=${doc.id} (${inventory.length}/${maxInventory}).`,
      );
      process.exit(4);
    }

    grantedSword = {
      uid: makeUid(),
      dataId: swordId,
      level,
      breakthroughLevel,
    };
    nextInventory = [...inventory, grantedSword];
  }

  const nextMaxInventory =
    inventory.length >= maxInventory && !updateExisting
      ? Math.min(maxInventory + 1, maxInventoryLimit)
      : maxInventory;

  console.log(
    JSON.stringify(
      {
        operation,
        dryRun,
        uid: doc.id,
        nickname,
        sword: grantedSword,
        inventoryBefore: inventory.length,
        inventoryAfter: nextInventory.length,
        maxInventoryBefore: maxInventory,
        maxInventoryAfter: nextMaxInventory,
      },
      null,
      2,
    ),
  );

  if (dryRun) return;

  await doc.ref.set(
    {
      inventory: nextInventory,
      maxInventory: nextMaxInventory,
      lastUpdated: admin.firestore.FieldValue.serverTimestamp(),
    },
    { merge: true },
  );

  console.log(
    `${operation === 'update-existing' ? 'Updated' : 'Granted'} ${swordId} +${level} ` +
      `(${grantedSword.breakthroughLevel} breakthrough) for ${nickname} (${doc.id}).`,
  );
}

run().catch((err) => {
  console.error(err);
  process.exit(1);
});
