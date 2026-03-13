const functions = require("firebase-functions");
const admin = require("firebase-admin");

admin.initializeApp();

const REGION = "asia-northeast3";
const regional = functions.region(REGION);
const TIME_ZONE = "Asia/Seoul";

exports.logPurchase = regional.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError("unauthenticated", "Login required.");
  }

  const uid = context.auth.uid;
  const payload = {
    userId: uid,
    productId: typeof data?.productId === "string" ? data.productId : "",
    success: data?.success === true,
    isPremiumPass: data?.isPremiumPass === true,
    diamonds: Number.isFinite(Number(data?.diamonds)) ? Number(data.diamonds) : 0,
    gold: Number.isFinite(Number(data?.gold)) ? Number(data.gold) : 0,
    stones: Number.isFinite(Number(data?.stones)) ? Number(data.stones) : 0,
    source: typeof data?.source === "string" ? data.source : "client",
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  };

  await admin.firestore().collection("purchase_logs").add(payload);
  return { ok: true };
});

exports.logSnapshot = regional.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError("unauthenticated", "Login required.");
  }

  const uid = context.auth.uid;
  const payload = {
    userId: uid,
    event: typeof data?.event === "string" ? data.event : "snapshot",
    state: data?.state && typeof data.state === "object" ? data.state : {},
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  };

  await admin.firestore().collection("snapshots").add(payload);
  return { ok: true };
});

const WATCHED_USER_FIELDS = [
  "gold",
  "diamond",
  "enhanceStone",
  "inventory",
  "equippedSwordUid",
  "equippedSwordId",
  "equippedSwordLevel",
  "maxInventory",
  "unlockedAchievements",
  "claimedAchievements",
  "dailyQuests",
  "seasonPassLevel",
  "hasPremiumPass",
];

const DETECT_LIMITS = {
  goldJump: 5000000,
  diamondJump: 1000,
  stoneJump: 500,
  maxEventsPerMinute: 15,
};

function safeNumber(v, fallback = 0) {
  return typeof v === "number" && Number.isFinite(v) ? v : fallback;
}

function changed(a, b) {
  return JSON.stringify(a ?? null) !== JSON.stringify(b ?? null);
}

function extractSwordGrade(item) {
  if (!item || typeof item !== "object") return null;
  if (typeof item.grade === "string") return item.grade.toLowerCase();
  if (item.data && typeof item.data.grade === "string") {
    return item.data.grade.toLowerCase();
  }
  return null;
}

function extractSwordUid(item) {
  if (!item || typeof item !== "object") return null;
  return typeof item.uid === "string" ? item.uid : null;
}

exports.auditUserStateChange = regional.firestore
  .document("users/{uid}")
  .onWrite(async (change, context) => {
    const uid = context.params.uid;
    const before = change.before.exists ? change.before.data() || {} : {};
    const after = change.after.exists ? change.after.data() || {} : {};
    if (!change.after.exists) return null;

    const changedKeys = WATCHED_USER_FIELDS.filter((key) => changed(before[key], after[key]));
    if (changedKeys.length === 0) return null;

    const beforeGold = safeNumber(before.gold, 0);
    const afterGold = safeNumber(after.gold, 0);
    const beforeDiamond = safeNumber(before.diamond, 0);
    const afterDiamond = safeNumber(after.diamond, 0);
    const beforeStone = safeNumber(before.enhanceStone, 0);
    const afterStone = safeNumber(after.enhanceStone, 0);

    const deltaGold = afterGold - beforeGold;
    const deltaDiamond = afterDiamond - beforeDiamond;
    const deltaStone = afterStone - beforeStone;

    const inv = Array.isArray(after.inventory) ? after.inventory : [];
    const maxInventory = safeNumber(after.maxInventory, 10);
    const totalGacha = safeNumber(after.totalGacha, 0);
    const equippedSwordUid =
      typeof after.equippedSwordUid === "string" ? after.equippedSwordUid : null;

    const flags = [];
    let riskDelta = 0;

    if (deltaGold > DETECT_LIMITS.goldJump) {
      flags.push("gold_jump");
      riskDelta += 40;
    }
    if (deltaDiamond > DETECT_LIMITS.diamondJump) {
      flags.push("diamond_jump");
      riskDelta += 40;
    }
    if (deltaStone > DETECT_LIMITS.stoneJump) {
      flags.push("stone_jump");
      riskDelta += 30;
    }
    if (inv.length > maxInventory) {
      flags.push("inventory_overflow");
      riskDelta += 60;
    }

    const uidSet = new Set();
    let duplicateUid = false;
    let rareCount = 0;
    for (const item of inv) {
      const swordUid = extractSwordUid(item);
      if (swordUid) {
        if (uidSet.has(swordUid)) duplicateUid = true;
        uidSet.add(swordUid);
      }
      const grade = extractSwordGrade(item);
      if (grade === "legend" || grade === "hidden" || grade === "immortal") {
        rareCount += 1;
      }
    }
    if (duplicateUid) {
      flags.push("duplicate_sword_uid");
      riskDelta += 45;
    }
    if (rareCount >= 3 && totalGacha < 30) {
      flags.push("rare_sword_outlier");
      riskDelta += 35;
    }
    if (equippedSwordUid && !uidSet.has(equippedSwordUid)) {
      flags.push("equipped_uid_not_in_inventory");
      riskDelta += 25;
    }

    const now = Date.now();
    const minuteBucket = Math.floor(now / 60000);
    const db = admin.firestore();
    const riskRef = db.collection("risk_users").doc(uid);
    const auditRef = db.collection("audit_events").doc();

    await db.runTransaction(async (tx) => {
      const riskSnap = await tx.get(riskRef);
      const prev = riskSnap.exists ? riskSnap.data() || {} : {};
      const prevBucket = safeNumber(prev.minuteBucket, -1);
      const prevMinuteCount = safeNumber(prev.minuteEventCount, 0);
      const minuteEventCount = prevBucket === minuteBucket ? prevMinuteCount + 1 : 1;

      let finalRiskDelta = riskDelta;
      const finalFlags = [...flags];
      if (minuteEventCount > DETECT_LIMITS.maxEventsPerMinute) {
        finalFlags.push("too_many_changes_per_minute");
        finalRiskDelta += 20;
      }

      tx.set(
        auditRef,
        {
          uid,
          ts: admin.firestore.FieldValue.serverTimestamp(),
          changedKeys,
          delta: {
            gold: deltaGold,
            diamond: deltaDiamond,
            enhanceStone: deltaStone,
          },
          before: {
            gold: beforeGold,
            diamond: beforeDiamond,
            enhanceStone: beforeStone,
            inventoryLength: Array.isArray(before.inventory) ? before.inventory.length : 0,
            maxInventory: safeNumber(before.maxInventory, 10),
          },
          after: {
            gold: afterGold,
            diamond: afterDiamond,
            enhanceStone: afterStone,
            inventoryLength: inv.length,
            maxInventory,
            seasonPassLevel: safeNumber(after.seasonPassLevel, 1),
            hasPremiumPass: after.hasPremiumPass === true,
          },
          flags: finalFlags,
          riskDelta: finalRiskDelta,
          source: "user_doc_on_write",
        },
        { merge: false }
      );

      tx.set(
        riskRef,
        {
          uid,
          minuteBucket,
          minuteEventCount,
          riskScore: admin.firestore.FieldValue.increment(finalRiskDelta),
          suspiciousEventCount: admin.firestore.FieldValue.increment(finalRiskDelta > 0 ? 1 : 0),
          lastFlags: finalFlags,
          lastChangedKeys: changedKeys,
          lastDelta: {
            gold: deltaGold,
            diamond: deltaDiamond,
            enhanceStone: deltaStone,
          },
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true }
      );
    });

    return null;
  });

async function ensurePublicDoc(tx, uid, db) {
  const publicRef = db.collection("users_public").doc(uid);
  const publicSnap = await tx.get(publicRef);
  if (publicSnap.exists) return;

  const userRef = db.collection("users").doc(uid);
  const userSnap = await tx.get(userRef);
  if (!userSnap.exists) return;

  const data = userSnap.data() || {};
  tx.set(
    publicRef,
    {
      nickname: typeof data.nickname === "string" ? data.nickname : "Unknown",
      equippedSwordId: typeof data.equippedSwordId === "string" ? data.equippedSwordId : "sword_001",
      equippedSwordLevel:
        typeof data.equippedSwordLevel === "number" && Number.isFinite(data.equippedSwordLevel)
          ? data.equippedSwordLevel
          : 1,
      titleId: typeof data.titleId === "string" ? data.titleId : "t_01",
      totalBattle: typeof data.totalBattle === "number" ? data.totalBattle : 0,
      totalBattleWin: typeof data.totalBattleWin === "number" ? data.totalBattleWin : 0,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    { merge: true }
  );
}

exports.onBattleNotificationCreate = regional.firestore
  .document("battle_notifications/{docId}")
  .onCreate(async (snap) => {
    const data = snap.data() || {};
    const attackerId = typeof data.fromUserId === "string" ? data.fromUserId : "";
    const defenderId = typeof data.toUserId === "string" ? data.toUserId : "";
    if (!attackerId || !defenderId || attackerId === defenderId) return null;

    const defenderWon = data.toWon === true;
    const attackerWon = !defenderWon;

    const db = admin.firestore();
    const usersRef = db.collection("users");
    const publicRef = db.collection("users_public");

    await db.runTransaction(async (tx) => {
      await ensurePublicDoc(tx, attackerId, db);
      await ensurePublicDoc(tx, defenderId, db);

      tx.set(
        usersRef.doc(attackerId),
        {
          totalBattle: admin.firestore.FieldValue.increment(1),
          totalBattleWin: admin.firestore.FieldValue.increment(attackerWon ? 1 : 0),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true }
      );
      tx.set(
        usersRef.doc(defenderId),
        {
          totalBattle: admin.firestore.FieldValue.increment(1),
          totalBattleWin: admin.firestore.FieldValue.increment(defenderWon ? 1 : 0),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true }
      );

      tx.set(
        publicRef.doc(attackerId),
        {
          totalBattle: admin.firestore.FieldValue.increment(1),
          totalBattleWin: admin.firestore.FieldValue.increment(attackerWon ? 1 : 0),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true }
      );
      tx.set(
        publicRef.doc(defenderId),
        {
          totalBattle: admin.firestore.FieldValue.increment(1),
          totalBattleWin: admin.firestore.FieldValue.increment(defenderWon ? 1 : 0),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true }
      );
    });

    return null;
  });

function parseRecordTimestamp(value) {
  if (!value) return 0;
  if (value instanceof admin.firestore.Timestamp) return value.toMillis();
  if (value instanceof Date) return value.getTime();
  if (typeof value === "string") {
    const t = Date.parse(value);
    return Number.isFinite(t) ? t : 0;
  }
  return 0;
}

function normalizeBattleRecords(records) {
  if (!Array.isArray(records)) return [];
  return records
    .map((r, idx) => ({ r, idx, ts: parseRecordTimestamp(r && r.timestamp) }))
    .sort((a, b) => {
      if (a.ts === b.ts) return a.idx - b.idx;
      return b.ts - a.ts;
    })
    .map((x) => x.r);
}

exports.trimBattleRecordsDaily = regional.pubsub
  .schedule("0 12 * * *")
  .timeZone(TIME_ZONE)
  .onRun(async () => {
    const limit = 20;
    const db = admin.firestore();
    const users = db.collection("users");
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
        scanned += 1;
        const data = doc.data() || {};
        const records = normalizeBattleRecords(data.battleRecords);
        if (records.length > limit) {
          const trimmed = records.slice(0, limit);
          batch.update(doc.ref, { battleRecords: trimmed });
          writeCount += 1;
          updated += 1;
        }
      }

      if (writeCount > 0) {
        await batch.commit();
      }

      lastDoc = snap.docs[snap.docs.length - 1];
    }

    console.log(`trimBattleRecordsDaily done. scanned=${scanned}, updated=${updated}`);
    return null;
  });
