// Phase 5 rules tests: owner vs munshi.
// Run with the emulator:
//   firebase emulators:exec --only firestore "node --test firestore_tests/rules_phase5.test.js"
// Needs: npm i -D @firebase/rules-unit-testing firebase   (in firestore_tests/ or root)
const { test, before, after, beforeEach } = require('node:test');
const fs = require('node:fs');
const {
  initializeTestEnvironment,
  assertSucceeds,
  assertFails,
} = require('@firebase/rules-unit-testing');
const { doc, setDoc, getDoc, updateDoc, serverTimestamp } = require('firebase/firestore');

let env;
const SHOP = 'shop1';

before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'tarazu-rules-test',
    firestore: { rules: fs.readFileSync('firestore.rules', 'utf8') },
  });
});
after(async () => env.cleanup());

beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await setDoc(doc(db, 'shops', SHOP), { ownerUid: 'owner', name: 'S', createdAt: new Date() });
    await setDoc(doc(db, 'users', 'owner'), {
      uid: 'owner', ownerName: 'O', shopName: 'S', email: 'o@x.com',
      role: 'owner', shopId: SHOP, isActive: true, createdAt: new Date(),
    });
    await setDoc(doc(db, 'users', 'munshi'), {
      uid: 'munshi', ownerName: 'M', shopName: 'S', email: 'm@x.com',
      role: 'staff', shopId: SHOP, isActive: true, createdAt: new Date(),
    });
    await setDoc(doc(db, 'shops', SHOP, 'materials', 'iron'), {
      name: 'Iron', rate: 100, rateKg: 100, ratePakaSeer: 4000, priceUnit: 'kg',
      isActive: true, createdAt: new Date(),
    });
    await setDoc(doc(db, 'shops', SHOP, 'expenses', 'e1'), {
      amount: 10, category: 'rent', note: '', dayKey: '2026-01-01',
      createdAt: new Date(), createdBy: 'owner', isVoided: false,
    });
  });
});

const as = (uid) => env.authenticatedContext(uid).firestore();

const slip = (uid) => ({
  items: [{ materialId: 'iron', grams: 1000 }],
  totalAmount: 100, totalWeightGrams: 1000, sellerName: 'X', dayKey: '2026-01-01',
  createdAt: new Date(), createdBy: uid, isVoided: false,
});

test('munshi can create a purchase', async () => {
  await assertSucceeds(setDoc(doc(as('munshi'), 'shops', SHOP, 'purchases', 'p1'), slip('munshi')));
});

test('munshi cannot void a purchase', async () => {
  await env.withSecurityRulesDisabled((c) =>
    setDoc(doc(c.firestore(), 'shops', SHOP, 'purchases', 'p1'), slip('munshi')));
  await assertFails(updateDoc(doc(as('munshi'), 'shops', SHOP, 'purchases', 'p1'), {
    isVoided: true, voidedAt: new Date(),
  }));
  await assertSucceeds(updateDoc(doc(as('owner'), 'shops', SHOP, 'purchases', 'p1'), {
    isVoided: true, voidedAt: new Date(),
  }));
});

test('munshi reads materials but cannot change rates', async () => {
  await assertSucceeds(getDoc(doc(as('munshi'), 'shops', SHOP, 'materials', 'iron')));
  await assertFails(updateDoc(doc(as('munshi'), 'shops', SHOP, 'materials', 'iron'), { rate: 1 }));
});

test('munshi cannot read expenses', async () => {
  await assertFails(getDoc(doc(as('munshi'), 'shops', SHOP, 'expenses', 'e1')));
  await assertSucceeds(getDoc(doc(as('owner'), 'shops', SHOP, 'expenses', 'e1')));
});

test('disabled munshi loses access at once', async () => {
  await env.withSecurityRulesDisabled((c) =>
    updateDoc(doc(c.firestore(), 'users', 'munshi'), { isActive: false }));
  await assertFails(getDoc(doc(as('munshi'), 'shops', SHOP, 'materials', 'iron')));
});

test('owner can create a munshi profile, munshi cannot create one', async () => {
  const prof = (uid, shop) => ({
    uid, ownerName: 'New', shopName: 'S', phone: '', email: 'n@x.com',
    role: 'staff', shopId: shop, isActive: true, createdAt: serverTimestamp(),
  });
  await assertSucceeds(setDoc(doc(as('owner'), 'users', 'new1'), prof('new1', SHOP)));
  await assertFails(setDoc(doc(as('munshi'), 'users', 'new2'), prof('new2', SHOP)));
  // owner of ANOTHER shop cannot attach a munshi to this shop
  await env.withSecurityRulesDisabled((c) =>
    setDoc(doc(c.firestore(), 'shops', 'shop2'), { ownerUid: 'owner2', name: 'T', createdAt: new Date() }));
  await assertFails(setDoc(doc(as('owner2'), 'users', 'new3'), prof('new3', SHOP)));
});

test('owner toggles isActive only; munshi cannot promote self', async () => {
  await assertSucceeds(updateDoc(doc(as('owner'), 'users', 'munshi'), { isActive: false }));
  await assertFails(updateDoc(doc(as('owner'), 'users', 'munshi'), { role: 'owner' }));
  await assertFails(updateDoc(doc(as('munshi'), 'users', 'munshi'), { role: 'owner' }));
  await assertFails(updateDoc(doc(as('munshi'), 'users', 'munshi'), { isActive: true, shopId: 'x' }));
});
