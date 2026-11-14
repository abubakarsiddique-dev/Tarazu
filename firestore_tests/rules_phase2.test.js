// Same way to run as rules.test.js (see CHANGES.md). Uses its own project id so
// it can run beside rules.test.js without clearing the other file's data.
const fs = require('fs');
const path = require('path');
const test = require('node:test');
const {
  initializeTestEnvironment, assertFails, assertSucceeds,
} = require('@firebase/rules-unit-testing');
const {
  doc, setDoc, updateDoc, deleteDoc, writeBatch, increment, Timestamp,
} = require('firebase/firestore');

let env;

const sale = (o = {}) => ({
  items: [{ materialId: 'iron', materialName: 'Iron', weightGrams: 15000, ratePerKg: 55, amount: 825 }],
  totalAmount: 825,
  totalWeightGrams: 15000,
  buyerName: 'Khan Traders',
  dayKey: '2026-11-04',
  createdAt: Timestamp.now(),
  createdBy: 'alice',
  isVoided: false,
  ...o,
});

const adjustment = (o = {}) => ({
  materialId: 'iron', materialName: 'Iron', deltaGrams: -2000, reason: 'loss',
  note: 'rusted', dayKey: '2026-11-04', createdAt: Timestamp.now(), createdBy: 'alice',
  ...o,
});

test.before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'tarazu-rules-test-phase2',
    firestore: { rules: fs.readFileSync(path.join(__dirname, '..', 'firestore.rules'), 'utf8') },
  });
});
test.after(async () => env.cleanup());

test.beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await setDoc(doc(db, 'shops/s1'), { ownerUid: 'alice', name: 'Ali Kabari', createdAt: Timestamp.now() });
    await setDoc(doc(db, 'shops/s1/stock/iron'), { materialName: 'Iron', weightGrams: 20000 });
    await setDoc(doc(db, 'shops/s1/sales/sale1'), sale());
    await setDoc(doc(db, 'shops/s1/salesDaily/2026-11-04'), { totalAmount: 825, totalWeightGrams: 15000, entryCount: 1 });
  });
});

const alice = () => env.authenticatedContext('alice').firestore();
const bob = () => env.authenticatedContext('bob').firestore();

// ---------------- sales ----------------

test('owner can create a valid sale; another user cannot', async () => {
  await assertSucceeds(setDoc(doc(alice(), 'shops/s1/sales/sale2'), sale()));
  await assertFails(setDoc(doc(bob(), 'shops/s1/sales/sale3'), sale({ createdBy: 'bob' })));
});

test('bad sales are rejected', async () => {
  const col = (o) => setDoc(doc(alice(), 'shops/s1/sales/x'), sale(o));
  await assertFails(col({ extra: 1 }));
  await assertFails(col({ createdBy: 'bob' }));
  await assertFails(col({ isVoided: true }));
  await assertFails(col({ totalWeightGrams: 0 }));
  await assertFails(col({ totalAmount: -1 }));
  await assertFails(col({ buyerName: 'A'.repeat(61) }));
  await assertFails(col({ items: [] }));
});

test('a sale can be voided once, never edited or un-voided or deleted', async () => {
  await assertFails(updateDoc(doc(alice(), 'shops/s1/sales/sale1'), { totalAmount: 1 }));
  await assertSucceeds(updateDoc(doc(alice(), 'shops/s1/sales/sale1'), { isVoided: true, voidedAt: Timestamp.now() }));
  await assertFails(updateDoc(doc(alice(), 'shops/s1/sales/sale1'), { isVoided: false }));
  await assertFails(deleteDoc(doc(alice(), 'shops/s1/sales/sale1')));
});

// ---------------- the real batches the app sends ----------------

test('addSale batch (sale + salesDaily + stock decrement) is accepted', async () => {
  const db = alice();
  const b = writeBatch(db);
  b.set(doc(db, 'shops/s1/sales/sale2'), sale());
  b.set(doc(db, 'shops/s1/salesDaily/2026-11-04'),
    { totalAmount: increment(825), totalWeightGrams: increment(15000), entryCount: increment(1) }, { merge: true });
  b.set(doc(db, 'shops/s1/stock/iron'), { materialName: 'Iron', weightGrams: increment(-15000) }, { merge: true });
  await assertSucceeds(b.commit());
});

test('voidSale batch (stock goes back up) is accepted', async () => {
  const db = alice();
  const b = writeBatch(db);
  b.update(doc(db, 'shops/s1/sales/sale1'), { isVoided: true, voidedAt: Timestamp.now() });
  b.set(doc(db, 'shops/s1/salesDaily/2026-11-04'),
    { totalAmount: increment(-825), totalWeightGrams: increment(-15000), entryCount: increment(-1) }, { merge: true });
  b.set(doc(db, 'shops/s1/stock/iron'), { materialName: 'Iron', weightGrams: increment(15000) }, { merge: true });
  await assertSucceeds(b.commit());
});

test('cancelling the same sale twice is rejected as a whole', async () => {
  await env.withSecurityRulesDisabled(async (ctx) => {
    await updateDoc(doc(ctx.firestore(), 'shops/s1/sales/sale1'), { isVoided: true, voidedAt: Timestamp.now() });
  });
  const db = alice();
  const b = writeBatch(db);
  b.update(doc(db, 'shops/s1/sales/sale1'), { isVoided: true, voidedAt: Timestamp.now() });
  b.set(doc(db, 'shops/s1/salesDaily/2026-11-04'),
    { totalAmount: increment(-825), totalWeightGrams: increment(-15000), entryCount: increment(-1) }, { merge: true });
  await assertFails(b.commit());
});

// ---------------- salesDaily ----------------

test('salesDaily can never go negative or take unknown fields', async () => {
  await assertFails(updateDoc(doc(alice(), 'shops/s1/salesDaily/2026-11-04'), { entryCount: increment(-5) }));
  await assertFails(updateDoc(doc(alice(), 'shops/s1/salesDaily/2026-11-04'), { totalAmount: increment(-826) }));
  await assertFails(updateDoc(doc(alice(), 'shops/s1/salesDaily/2026-11-04'), { sneaky: 1 }));
  await assertFails(deleteDoc(doc(alice(), 'shops/s1/salesDaily/2026-11-04')));
  await assertFails(updateDoc(doc(bob(), 'shops/s1/salesDaily/2026-11-04'), { entryCount: increment(1) }));
});

// ---------------- adjustments ----------------

test('adjustStock batch (record + stock change) is accepted', async () => {
  const db = alice();
  const b = writeBatch(db);
  b.set(doc(db, 'shops/s1/adjustments/a1'), adjustment());
  b.set(doc(db, 'shops/s1/stock/iron'), { materialName: 'Iron', weightGrams: increment(-2000) }, { merge: true });
  await assertSucceeds(b.commit());
});

test('adjusting a material with no stock doc yet (adding weight) is accepted', async () => {
  const db = alice();
  const b = writeBatch(db);
  b.set(doc(db, 'shops/s1/adjustments/a1'), adjustment({ materialId: 'copper', materialName: 'Copper', deltaGrams: 4000, reason: 'correction' }));
  b.set(doc(db, 'shops/s1/stock/copper'), { materialName: 'Copper', weightGrams: increment(4000) }, { merge: true });
  await assertSucceeds(b.commit());
});

test('adjustStock with reason garbage is accepted for the owner', async () => {
  const db = alice();
  const b = writeBatch(db);
  b.set(doc(db, 'shops/s1/adjustments/a_garbage'), adjustment({ reason: 'garbage', deltaGrams: -1500, note: 'dirt' }));
  b.set(doc(db, 'shops/s1/stock/iron'), { materialName: 'Iron', weightGrams: increment(-1500) }, { merge: true });
  await assertSucceeds(b.commit());
});

test('bad adjustments are rejected', async () => {
  const add = (o) => setDoc(doc(alice(), 'shops/s1/adjustments/x'), adjustment(o));
  await assertFails(add({ deltaGrams: 0 }));
  await assertFails(add({ deltaGrams: 1.5 }));
  await assertFails(add({ deltaGrams: 200000000 }));
  await assertFails(add({ reason: 'gift' }));
  await assertFails(add({ reason: 'invalid_reason' }));
  await assertFails(add({ note: 'x'.repeat(201) }));
  await assertFails(add({ createdBy: 'bob' }));
  await assertFails(add({ extra: 1 }));
  await assertFails(setDoc(doc(bob(), 'shops/s1/adjustments/y'), adjustment({ createdBy: 'bob' })));
});

test('adjustment records can never be edited or deleted', async () => {
  await env.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'shops/s1/adjustments/a1'), adjustment());
  });
  await assertFails(updateDoc(doc(alice(), 'shops/s1/adjustments/a1'), { note: 'changed' }));
  await assertFails(deleteDoc(doc(alice(), 'shops/s1/adjustments/a1')));
});

// ---------------- Phase 1 behaviour must still hold ----------------

test('purchases flow from Phase 1 is unchanged (void batch)', async () => {
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await setDoc(doc(db, 'shops/s1/purchases/p1'), {
      items: [{ materialId: 'iron' }], totalAmount: 500, totalWeightGrams: 12500, sellerName: '',
      dayKey: '2026-11-04', createdAt: Timestamp.now(), createdBy: 'alice', isVoided: false,
    });
    await setDoc(doc(db, 'shops/s1/daily/2026-11-04'), { totalAmount: 500, totalWeightGrams: 12500, entryCount: 1 });
  });
  const db = alice();
  const b = writeBatch(db);
  b.update(doc(db, 'shops/s1/purchases/p1'), { isVoided: true, voidedAt: Timestamp.now() });
  b.set(doc(db, 'shops/s1/daily/2026-11-04'),
    { totalAmount: increment(-500), totalWeightGrams: increment(-12500), entryCount: increment(-1) }, { merge: true });
  b.set(doc(db, 'shops/s1/stock/iron'), { weightGrams: increment(-12500) }, { merge: true });
  await assertSucceeds(b.commit());
});
