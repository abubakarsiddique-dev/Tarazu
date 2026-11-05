# Phase 5: Munshi (staff) accounts

## Kya naya hai
- `firestore.rules`: munshi ke liye access. Owner + active munshi purchases/sales/daily/stock mein likh sakte hain.
  Sirf owner: rates, void, adjustments, expenses, munshi on/off. Expenses block ab main file mein hai.
- `lib/features/staff/`: Munshi accounts screen (list, naya munshi, on/off switch).
  Login banane ke liye alag `FirebaseApp('staffCreator')` use hota hai, taake owner logout na ho.
- `firestore_tests/rules_phase5.test.js`: owner vs munshi ke rules tests.
- `PATCHES.md`: baqi files ke chhote edits (router, home, materials, stock, sales, signing, pubspec, safai).

## Install
1. Zip project root mein extract karo (`lib/` aur `firestore_tests/` merge ho jayenge, `firestore.rules` replace hoga).
2. `PATCHES.md` ke edits lagao.
3. `flutter analyze && flutter test`
4. Rules test: `firebase emulators:exec --only firestore "node --test firestore_tests/rules_phase5.test.js"`
5. Deploy: `firebase deploy --only firestore:rules`

## Phone par test
1. Owner login, Munshi accounts, naya munshi banao. Owner logout NAHI hona chahiye.
2. Munshi ke email/password se doosre phone par login. Purchase aur sale banao, stock dekho.
3. Munshi ko profit, reports, expenses, rate edit, stock adjust, void nazar nahi aana chahiye.
4. Owner switch off kare. Munshi ka agla write/read fail hona chahiye aur munshi wapas login par jaye.
5. Munshi ka purchase owner ki list mein aaye, aur stock sahi barhe.

## Haqeeqat (limits)
- Munshi purchases/sales padh sakta hai, is liye technically profit nikal sakta hai. UI sirf chhupata hai.
- Rules increment aur overwrite mein farq nahi kar sakte, is liye munshi seedha Firestore likh kar stock/daily galat kar sakta hai (app se nahi).
- Munshi banane ke liye internet chahiye. Password bhool jaye to "Forgot password".
- Munshi ka `ownerName` field uska apna naam hai (purane schema ko na tordne ke liye).
- Yeh sab mere paas Flutter/emulator na hone ki wajah se CHALAYA NAHI GAYA. `analyze`, `test` aur rules tests aap chalao.
