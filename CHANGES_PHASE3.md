# Phase 3: Report (purchases + sales, share on WhatsApp)

## Kyun
History sirf purchases dikhati hai. Sales ka mahine ka hisaab kahin nahi. Owner ko mahine ke end mein
"kitna kharida, kitna becha" ek jagah chahiye, aur WhatsApp par bhejna bhi.

## Lagana
1. Zip project ROOT mein extract. Koi purani file overwrite nahi hoti, sirf naye files.
2. 2 manual edits: snippets/app_router.patch.txt, snippets/home_screen.patch.txt
3. Koi nayi package nahi (share_plus pehle se hai). Firestore rules mein bhi kuch nahi badalna.
4. flutter analyze && flutter test

## Files
NEW  lib/features/inventory/domain/report.dart
NEW  lib/features/inventory/application/report_providers.dart
NEW  lib/features/inventory/presentation/report_screen.dart
NEW  test/report_test.dart
MANUAL  app_router.dart, home_screen.dart

## Phone test
* Report kholo (Month): purchases aur sales ke totals, History/Sales screen se match karein.
* Week/Day badal kar dekho, aur peeche ja kar purane mahine.
* Share dabao: WhatsApp text mein totals aur "not profit" note aaye.
* Sale cancel karo: report mein total kam ho jaye.

## Limits (sach)
* "Sales minus purchases" profit NAHI hai. Bika hua maal ka asli kharcha nahi nikalta (cost basis nahi hai).
  Asli profit ke liye har sale par average cost chahiye, wo alag phase hai.
* Adjustments (loss/waste) report mein nahi hain.
* Query 'sales' collection par dayKey range hai (single field), index nahi chahiye.
* Repo mein purani root CHANGES.md aur snippets/ folder (meri Phase 2 wali) pade hain. Dono delete kar do,
  ab ye kisi kaam ke nahi.
