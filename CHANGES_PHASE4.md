# Phase 4: Profit page + Expenses page

## Kyun
Report page khud kehta tha "not profit". Ab asli profit (sales - kharid ki lagat - nuqsan - kharcha),
total aur har material ka alag. Expenses ka alag page.

## Lagana
1. Zip project ROOT mein extract (sirf naye files, koi purani file overwrite nahi hoti).
2. Manual edits: snippets/app_router.patch.txt, snippets/home_screen.patch.txt
3. Firestore rules: snippets/firestore.rules.insert.txt ko firestore.rules mein paste karo
   (`match /shops/{shopId}` ke andar), phir deploy: firebase deploy --only firestore:rules
   (DEPLOY ZAROORI HAI, warna expenses save nahi honge aur "could not be saved" aayega.)
4. Koi nayi package nahi.
5. flutter analyze && flutter test
   Rules test: cd firestore_tests && npm install, phir
   firebase emulators:exec --only firestore "npm test --prefix firestore_tests"

## Profit kaise nikalta hai
Har material ke liye purchases, sales aur stock adjustments ko waqt ke hisab se replay karta hai:
* purchase: stock ka wazan aur lagat barhti hai
* sale: sold maal ki lagat = wazan x us waqt ki average lagat (moving average)
* minus adjustment: "stock loss" (average lagat par)
* plus adjustment: average lagat par add (free profit nahi banta)
* cancelled (voided) slips shamil nahi
Net profit = sales - cost of sold stock - stock loss - expenses

## Phone test
* Ek purchase (Iron 20 kg Rs 800), ek sale (15 kg Rs 825): Profit page = 225.
* Expense Rs 100 dalo: Net profit 125.
* Sale cancel karo: profit wapas 0 ho jaye.
* Airplane mode mein expense dalo: list mein dikhe, cloud_off icon, net par aane par sync.

## Limits (sach)
* Purani history ke liye: jis maal ka purchase slip nahi (opening stock), uski lagat 0 ginti hai aur
  profit zyada dikhta hai. Screen par laal warning aati hai. Opening stock ko purchase slip ke taur par daalo.
* Average cost ka matlab FIFO nahi. Mehnga purana maal aur sasta naya maal mix ho jata hai.
* Purchase void karne par history dobara replay hoti hai, to purane mahine ka profit badal sakta hai.
* Wazan ka nuqsan (nami, mitti) khud ba khud nahi pakda jata, sirf tab jab stock adjustment (loss) karo.
* Profit page poori history Firestore se parhta hai (purchases + sales + adjustments), kyunke average
  lagat ke liye poori tareekh chahiye. 5-20 shops aur pehle saal ke liye theek hai. Barhne par agla
  qadam: har sale ke waqt lagat ek baar save karna (rules badalne parenge).
* expenses mein void ka option hai, edit nahi (audit trail).
