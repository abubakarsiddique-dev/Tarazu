# Phase 2: Stock out (dispatch)  (copy-paste + 3 chhote manual edits)

## Kyun
Abhi Stock screen sirf "total kharida hua" dikhati hai, kyunki maal bahar jaane ka koi record nahi.
Pehle hafte mein hi owner poochega "mera stock sahi kyun nahi?". Ye minimal fix hai: sirf KG ghatao,
paisa/rate/udhaar abhi nahi (wo owners se poochne ke baad).

## Lagana
1. Zip project ROOT mein extract (overwrite): sirf write_failures.dart overwrite hogi (2 naye WriteKind).
2. Manual edits: snippets/app_router.patch.txt aur snippets/home_screen.patch.txt
3. firestore.rules: snippets/firestore.rules.insert.txt wala block `match /shops/{shopId}` ke andar paste,
   phir Firebase console > Rules > Publish. (BINA publish ke stock-out save reject hoga.)
4. flutter analyze && flutter test

## Files
NEW      lib/features/inventory/domain/dispatch.dart
NEW      lib/features/inventory/data/dispatch_repository.dart
NEW      lib/features/inventory/application/dispatch_providers.dart
NEW      lib/features/inventory/presentation/dispatch_screen.dart
CHANGED  lib/core/sync/write_failures.dart   (poori file, sirf 2 kinds + 2 messages add)
NEW      test/dispatch_test.dart
MANUAL   app_router.dart, home_screen.dart, firestore.rules

## Phone test
* Purchase 10 kg Iron > Stock out 4 kg > Stock screen 6 kg dikhaye.
* 7 kg stock hai aur 9 kg likho: "Only 7 kg in stock" aana chahiye.
* Airplane mode mein stock out: turant dikhe (cloud_off icon), online hone par sync.
* Entry cancel (undo icon): stock wapas.
* Rules publish kiye bina save karo: snackbar "could not be saved" aana chahiye (confirm karne ke liye).

## Limits (sach)
* Do phones se ek hi shop pe offline stock out ho to total stock se zyada nikal sakta hai; stock negative
  dikhega (rules negative allow karte hain, jaan boojh kar). Ek owner = ek phone ho to masla nahi.
* Purani purchase void karne se stock negative ho sakta hai agar wo maal pehle hi stock-out ho chuka ho.
* Dispatch History screen/reports mein abhi shamil nahi. Sirf aaj ki list is screen par.
* Naye text DispatchStrings mein hain, AppStrings mein nahi (copy-paste ke liye).
