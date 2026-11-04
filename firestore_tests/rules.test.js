// Run from the project root:
//   cd firestore_tests && npm install
//   cd .. && firebase emulators:exec --only firestore "npm test --prefix firestore_tests"
const fs = require('fs');
const path = require('path');
const test = require('node:test');
const {
  initializeTestEnvironment,
  assertFails,
  assertSucceeds,
} = require('@firebase/rules-unit-testing');
const {
  doc, getDoc, setDoc, updateDoc, deleteDoc, writeBatch, increment, Timestamp,
} = require('firebase/firestore');

let env;

const slip = (o = {}) => ({
  items: [{ materialId: 'iron', materialName: 'Iron', weightGrams: 12500, amount: 500 }],
  totalAmount: 500,
  totalWeightGrams: 12500,
  sellerName: '',
  dayKey: '2026-11-04',
  createdAt: Timestamp.now(),
  createdBy: 'alice',
  isVoided: false,
  ...o,
});

test.before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'tarazu-rules-test',
    firestore: {
      rules: fs.readFileSync(path.join(__dirname, '..', 'firestore.rules'), 'utf8'),
    },
  });
});

test.after(async () => env.cleanup());

test.beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await setDoc(doc(db, 'shops/s1'), { ownerUid: 'alice', name: 'Ali Kabari', createdAt: Timestamp.now() });
    await setDoc(doc(db, 'users/alice'), {
      uid: 'alice', ownerName: 'Ali', shopName: 'Ali Kabari', email: 'a@b.com',
      role: 'owner', shopId: 's1', isActive: true, createdAt: Timestamp.now(),
    });
    await setDoc(doc(db, 'shops/s1/purchases/p1'), slip());
    await setDoc(doc(db, 'shops/s1/daily/2026-11-04'), { totalAmount: 500, totalWeightGrams: 12500, entryCount: 1 });
    await setDoc(doc(db, 'shops/s1/stock/iron'), { materialName: 'Iron', weightGrams: 12500 });
  });
});

const alice = () => env.authenticatedContext('alice').firestore();
const bob = () => env.authenticatedContext('bob').firestore();

// ---------------- access ----------------

test('owner can read the shop data, another user cannot', async () => {
  await assertSucceeds(getDoc(doc(alice(), 'shops/s1/purchases/p1')));
  await assertFails(getDoc(doc(bob(), 'shops/s1/purchases/p1')));
  await assertFails(getDoc(doc(env.unauthenticatedContext().firestore(), 'shops/s1')));
});

// ---------------- users ----------------

test('user can change phone but not role, isActive or shopId', async () => {
  await assertSucceeds(updateDoc(doc(alice(), 'users/alice'), { phone: '0300-1234567' }));
  await assertFails(updateDoc(doc(alice(), 'users/alice'), { role: 'admin' }));
  await assertFails(updateDoc(doc(alice(), 'users/alice'), { isActive: false }));
  await assertFails(updateDoc(doc(alice(), 'users/alice'), { shopId: 's2' }));
});

test('user cannot edit someone else\'s profile', async () => {
  await assertFails(updateDoc(doc(bob(), 'users/alice'), { phone: '1' }));
});

// ---------------- purchases ----------------

test('owner can create a valid slip', async () => {
  await assertSucceeds(setDoc(doc(alice(), 'shops/s1/purchases/p2'), slip()));
});

test('slip with an extra field, wrong creator, or already voided is rejected', async () => {
  await assertFails(setDoc(doc(alice(), 'shops/s1/purchases/p2'), slip({ extra: 1 })));
  await assertFails(setDoc(doc(alice(), 'shops/s1/purchases/p2'), slip({ createdBy: 'bob' })));
  await assertFails(setDoc(doc(alice(), 'shops/s1/purchases/p2'), slip({ isVoided: true })));
  await assertFails(setDoc(doc(alice(), 'shops/s1/purchases/p2'), slip({ totalWeightGrams: 0 })));
});

test('a slip can be voided once, but never edited or un-voided', async () => {
  await assertFails(updateDoc(doc(alice(), 'shops/s1/purchases/p1'), { totalAmount: 1 }));
  await assertSucceeds(updateDoc(doc(alice(), 'shops/s1/purchases/p1'), {
    isVoided: true, voidedAt: Timestamp.now(),
  }));
  await assertFails(updateDoc(doc(alice(), 'shops/s1/purchases/p1'), { isVoided: false }));
});

test('slips can never be deleted', async () => {
  await assertFails(deleteDoc(doc(alice(), 'shops/s1/purchases/p1')));
});

// ---------------- the real batches the app sends ----------------

test('addSlip batch (slip + daily + stock increments) is accepted', async () => {
  const db = alice();
  const b = writeBatch(db);
  b.set(doc(db, 'shops/s1/purchases/p2'), slip());
  b.set(doc(db, 'shops/s1/daily/2026-11-04'),
    { totalAmount: increment(500), totalWeightGrams: increment(12500), entryCount: increment(1) },
    { merge: true });
  b.set(doc(db, 'shops/s1/stock/iron'),
    { materialName: 'Iron', weightGrams: increment(12500) }, { merge: true });
  await assertSucceeds(b.commit());
});

test('addSlip on a brand-new day and material is accepted', async () => {
  const db = alice();
  const b = writeBatch(db);
  b.set(doc(db, 'shops/s1/purchases/p2'), slip({ dayKey: '2026-11-05' }));
  b.set(doc(db, 'shops/s1/daily/2026-11-05'),
    { totalAmount: increment(500), totalWeightGrams: increment(12500), entryCount: increment(1) },
    { merge: true });
  b.set(doc(db, 'shops/s1/stock/copper'),
    { materialName: 'Copper', weightGrams: increment(12500) }, { merge: true });
  await assertSucceeds(b.commit());
});

test('voidPurchase batch is accepted', async () => {
  const db = alice();
  const b = writeBatch(db);
  b.update(doc(db, 'shops/s1/purchases/p1'), { isVoided: true, voidedAt: Timestamp.now() });
  b.set(doc(db, 'shops/s1/daily/2026-11-04'),
    { totalAmount: increment(-500), totalWeightGrams: increment(-12500), entryCount: increment(-1) },
    { merge: true });
  b.set(doc(db, 'shops/s1/stock/iron'), { weightGrams: increment(-12500) }, { merge: true });
  await assertSucceeds(b.commit());
});

test('voiding twice is rejected (second device, same slip)', async () => {
  await env.withSecurityRulesDisabled(async (ctx) => {
    await updateDoc(doc(ctx.firestore(), 'shops/s1/purchases/p1'), { isVoided: true, voidedAt: Timestamp.now() });
  });
  const db = alice();
  const b = writeBatch(db);
  b.update(doc(db, 'shops/s1/purchases/p1'), { isVoided: true, voidedAt: Timestamp.now() });
  b.set(doc(db, 'shops/s1/daily/2026-11-04'),
    { totalAmount: increment(-500), totalWeightGrams: increment(-12500), entryCount: increment(-1) },
    { merge: true });
  await assertFails(b.commit()); // whole batch fails, so totals are not double-reduced
});

// ---------------- daily ----------------

test('daily totals can never go negative', async () => {
  await assertFails(updateDoc(doc(alice(), 'shops/s1/daily/2026-11-04'), { entryCount: increment(-5) }));
  await assertFails(updateDoc(doc(alice(), 'shops/s1/daily/2026-11-04'), { totalAmount: increment(-501) }));
});

test('daily rejects wrong types and unknown fields', async () => {
  await assertFails(updateDoc(doc(alice(), 'shops/s1/daily/2026-11-04'), { totalAmount: '500' }));
  await assertFails(updateDoc(doc(alice(), 'shops/s1/daily/2026-11-04'), { sneaky: 1 }));
  await assertFails(setDoc(doc(alice(), 'shops/s1/daily/2026-11-06'),
    { totalAmount: 1, totalWeightGrams: 1, entryCount: 1, sneaky: 1 }));
});

test('daily cannot be touched by another user or deleted', async () => {
  await assertFails(updateDoc(doc(bob(), 'shops/s1/daily/2026-11-04'), { entryCount: increment(1) }));
  await assertFails(deleteDoc(doc(alice(), 'shops/s1/daily/2026-11-04')));
});

// ---------------- stock ----------------

test('stock rejects wrong types, unknown fields, empty or huge names', async () => {
  await assertFails(updateDoc(doc(alice(), 'shops/s1/stock/iron'), { weightGrams: '1' }));
  await assertFails(updateDoc(doc(alice(), 'shops/s1/stock/iron'), { weightGrams: 1.5 }));
  await assertFails(updateDoc(doc(alice(), 'shops/s1/stock/iron'), { sneaky: 1 }));
  await assertFails(setDoc(doc(alice(), 'shops/s1/stock/x'), { materialName: '', weightGrams: 1 }));
  await assertFails(setDoc(doc(alice(), 'shops/s1/stock/x'), { materialName: 'A'.repeat(61), weightGrams: 1 }));
});

test('stock without a name cannot be created (void on a missing stock doc)', async () => {
  await assertFails(setDoc(doc(alice(), 'shops/s1/stock/ghost'), { weightGrams: increment(-100) }, { merge: true }));
});
