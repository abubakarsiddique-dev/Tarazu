# Phase 5 patches (chhoti edits, apni files mein lagao)

Maine aapki purani files workspace mein nahi dekhi (sirf paste ki hui thin), isliye in 5 files ke liye
poori file ke bajaye chhote patch diye hain. Har patch ke saath likha hai kahan lagana hai.

## 1. `lib/features/auth/application/auth_providers.dart`  (naya provider add karo)

```dart
/// True sirf owner ke liye. Munshi ke liye false. Profile load hone tak false.
final isOwnerProvider = Provider<bool>((ref) {
  final user = ref.watch(userProfileProvider).value;
  return user != null && user.role == UserRole.owner;
});
```
(`UserRole` ke liye `../domain/app_user.dart` import ho. Agar aapke profile provider ka naam
`userProfileProvider` nahi hai to wohi naam use karo jo `AppUser` deta hai.)

## 2. `lib/core/router/app_router.dart`

Route constant:
```dart
static const staff = '/staff';
```
Route list mein:
```dart
GoRoute(path: Routes.staff, builder: (_, _) => const StaffScreen()),
```
`redirectFor` mein, logged-in user ke liye, in raaston par munshi ko wapas home bhejo:
```dart
const ownerOnly = {Routes.staff, Routes.reports, Routes.expenses, Routes.adjustStock};
if (user.role == UserRole.staff && ownerOnly.contains(location)) return Routes.home;
```
Agar user `isActive == false` hai to usse sign out karke login par bhejo (ya "account band hai" screen).
Aapke code mein `Routes.reports/expenses/adjustStock` ke naam alag ho sakte hain, unke hisab se badlo.

## 3. `home_screen.dart`

Owner-only tiles ko `isOwnerProvider` se wrap karo:
```dart
final isOwner = ref.watch(isOwnerProvider);
...
if (isOwner) ...[
  // Profit / Reports / Expenses / Staff tiles yahan
  _HomeTile(icon: Icons.group, label: StaffStrings.title, onTap: () => context.push(Routes.staff)),
],
```
Munshi ko sirf: Purchase, Sale, Stock (dekhna), aaj ka total. Profit card munshi se chhupao.

## 4. `materials_screen.dart`

Rate edit / naya material / on-off sirf owner:
```dart
final isOwner = ref.watch(isOwnerProvider);
floatingActionButton: isOwner ? FloatingActionButton(...) : null,
// har tile par: onTap: isOwner ? () => _edit(m) : null, aur on/off Switch ko `if (isOwner)` mein
```

## 5. `stock_screen.dart` aur `sales_screen.dart`

- Stock screen: "Adjust" button/action sirf `if (isOwner)`.
- Sales / purchases list: "Cancel (void)" action sirf `if (isOwner)`.
  (Rules bhi munshi ko void karne nahi dete, UI sirf button chhupata hai.)

## 6. `firebase_options.dart`

Android `appId` ko is se badlo: `1:147408166498:android:768ad38ff232e853627b3b`

## 7. `android/app/build.gradle.kts`  (release signing)

```kotlin
import java.util.Properties
val keystoreProps = Properties().apply {
    val f = rootProject.file("key.properties")
    if (f.exists()) f.inputStream().use { load(it) }
}
android {
    signingConfigs {
        create("release") {
            keyAlias = keystoreProps["keyAlias"] as String?
            keyPassword = keystoreProps["keyPassword"] as String?
            storeFile = keystoreProps["storeFile"]?.let { file(it as String) }
            storePassword = keystoreProps["storePassword"] as String?
        }
    }
    buildTypes {
        release { signingConfig = signingConfigs.getByName("release") }
    }
}
```
`android/key.properties` ko `.gitignore` mein daalo (keystore kabhi commit na karo).

## 8. `pubspec.yaml`

`fake_cloud_firestore` ko `dependencies:` se hata kar `dev_dependencies:` mein daalo.

## 9. Safai (purani/fazool files)

```bash
rm -rf android/app/src/main/kotlin/com/example
rm -f CHANGES.md
rm -rf snippets/
```
(`com/example` sirf tab hatao jab aapka asli package us folder mein na ho. Pehle `ls` se dekh lo.)
