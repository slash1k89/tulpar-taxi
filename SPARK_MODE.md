# Spark mode

By default the application uses the `taxi-esil` Firebase project directly and
does not call Cloud Functions. Orders are created, accepted, cancelled and
advanced using Firestore transactions protected by `firestore.rules`.

Run the Android application normally:

```powershell
flutter run
```

The local Emulator Suite remains available when it is explicitly requested:

```powershell
firebase emulators:start
flutter run --dart-define=USE_FIREBASE_EMULATORS=true --dart-define=FIREBASE_EMULATOR_HOST=10.0.2.2
```

Push notifications are intentionally disabled in the default Spark mode.
The existing callable Functions and FCM code are retained for a future Blaze
deployment and can only be selected explicitly:

```powershell
flutter run --dart-define=USE_CLOUD_FUNCTIONS=true
```

Do not use that last command until the Functions have been deployed to a
Blaze-enabled project.

To deploy only the security rules (without Cloud Functions), after separate
approval run:

```powershell
npx -y firebase-tools@latest deploy --project taxi-esil --only firestore:rules,database
```
