// Same way to run as the other rules tests (see rules.test.js).
const fs = require('fs');
const path = require('path');
const test = require('node:test');
const { initializeTestEnvironment, assertFails, assertSucceeds } = require('@firebase/rules-unit-testing');
const { doc, setDoc, updateDoc, deleteDoc, Timestamp } = require('firebase/firestore');

let env;

const expense = (o = {}) => ({
  amount: 500,
  category: 'labour',
  note: '',
  dayKey: '2026-11-05',
  createdAt: Timestamp.now(),
  createdBy: 'alice',
  isVoided: false,
  ...o,
});

test.before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'tarazu-rules-test-p4',
    firestore: { rules: fs.readFileSync(path.join(__dirname, '..', 'firestore.rules'), 'utf8') },
  });
});
test.after(async () => env.cleanup());
test.beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await setDoc(doc(db, 'shops/s1'), { ownerUid: 'alice', name: 'Ali Kabari', createdAt: Timestamp.now() });
    await setDoc(doc(db, 'shops/s1/expenses/e1'), expense());
  });
});

const alice = () => env.authenticatedContext('alice').firestore();
const bob = () => env.authenticatedContext('bob').firestore();

test('owner can add a valid expense, another user cannot', async () => {
  await assertSucceeds(setDoc(doc(alice(), 'shops/s1/expenses/e2'), expense()));
  await assertFails(setDoc(doc(bob(), 'shops/s1/expenses/e3'), expense({ createdBy: 'bob' })));
});

test('bad expenses are rejected', async () => {
  const add = (o) => setDoc(doc(alice(), 'shops/s1/expenses/x'), expense(o));
  await assertFails(add({ amount: 0 }));
  await assertFails(add({ amount: -5 }));
  await assertFails(add({ amount: 1.5 }));
  await assertFails(add({ amount: 100000001 }));
  await assertFails(add({ category: 'gift' }));
  await assertFails(add({ note: 'x'.repeat(201) }));
  await assertFails(add({ createdBy: 'bob' }));
  await assertFails(add({ isVoided: true }));
  await assertFails(add({ extra: 1 }));
});

test('an expense can be voided once, never edited, un-voided or deleted', async () => {
  await assertFails(updateDoc(doc(alice(), 'shops/s1/expenses/e1'), { amount: 1 }));
  await assertSucceeds(updateDoc(doc(alice(), 'shops/s1/expenses/e1'), { isVoided: true, voidedAt: Timestamp.now() }));
  await assertFails(updateDoc(doc(alice(), 'shops/s1/expenses/e1'), { isVoided: false }));
  await assertFails(deleteDoc(doc(alice(), 'shops/s1/expenses/e1')));
});
