# Kabariapp: auth starter setup

1. Add packages (this pulls the CURRENT versions; do not hand-type old ones):

    flutter pub add flutter_riverpod go_router firebase_core firebase_auth cloud_firestore shared_preferences

2. Connect your existing Firebase project (generates lib/firebase_options.dart):

    dart pub global activate flutterfire_cli
    flutterfire configure

3. Firebase console:
   - Authentication > Sign-in method > enable Email/Password
   - Firestore > Rules > paste firestore.rules > Publish

4. Copy lib/ and test/ into your project (keep your own firebase_options.dart), then:

    flutter analyze
    flutter test
    flutter run

Manual test checklist: register, logout, login, wrong password, forgot password,
airplane mode while logged in then relaunch (must open home), airplane mode
login attempt (must show the internet message), set isActive=false in console
(must show disabled screen).
