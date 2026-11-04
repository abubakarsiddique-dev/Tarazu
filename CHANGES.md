# Phase 1: Harden  (copy-paste ready)

## Kaise lagana hai
1. Is zip ko apne project ke ROOT folder (jahan pubspec.yaml hai) mein extract karo, "overwrite" karke.
   Koi manual edit nahi chahiye.
2. Terminal:

       flutter pub add --dev fake_cloud_firestore
       flutter analyze
       flutter test

3. Rules tests (optional, Java + firebase-tools chahiye):

       cd firestore_tests
       npm install --save-dev @firebase/rules-unit-testing firebase
       cd ..
       firebase emulators:exec --only firestore "npm test --prefix firestore_tests"

4. Firebase console > Firestore > Rules > firestore.rules paste karo > Publish.

## Files
NEW      lib/core/sync/write_failures.dart
CHANGED  lib/app.dart                                        (snackbar jab server write reject kare)
CHANGED  lib/features/inventory/data/inventory_repository.dart
CHANGED  lib/features/inventory/application/inventory_providers.dart   (poori file)
CHANGED  firestore.rules                                     (poori file)
CHANGED  firebase.json                                       (sirf "firestore" key add hui)
NEW      test/write_failures_test.dart
NEW      test/inventory_repository_test.dart
NEW      firestore_tests/  (rules.test.js, package.json)

## Merge se pehle check
* `git diff` mein inventory_providers.dart aur inventory_repository.dart ke sirf chhote badlaav dikhne chahiye
  (import + onWriteError + _send). Agar aur kuch badla dikhe to mujhe batao.
* Phone par test: airplane mode mein slip save (turant dikhe, "Waiting for internet"), phir rule
  temporarily todo (e.g. totalAmount < 0), online slip save karo: slip gayab + snackbar aana chahiye.
  Rule wapas theek karna na bhoolna.

## Limits
* Agar app band ho aur reject hone wali write queue mein ho, to snackbar nahi aata (Firestore us purani
  run ka callback nahi deta).
* Purane daily docs jinmein entryCount nahi, wo reject ho sakte hain. Console mein purane din check karo.
