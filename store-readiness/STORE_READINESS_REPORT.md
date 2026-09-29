# MEKEN Store Production Readiness

Audit updated: 2026-09-24. This document describes the local source tree. It does
not assert that external store accounts, public web pages, or iOS credentials
exist.

## Executive status

| Requirement | Android | iOS | Status | Action |
|---|---|---|---|---|
| SDK and toolchain | compile 37, target 36, min 24 | deployment target 13.0 | READY / WARNING | Recheck with the final store artifacts; validate iOS on Xcode 26. |
| App identity | `kz.tulpar.taxi` | changed locally to `kz.tulpar.taxi` | ANDROID READY / IOS BLOCKER | Register the matching iOS Firebase app and supply `GoogleService-Info.plist`. |
| Version | `1.0.0+1` | `1.0.0+1` | READY if never uploaded | If build code 1 has already reached a store, choose the next unused code. |
| Release signing | dedicated release keystore exists and is selected | automatic signing placeholder | ANDROID READY / IOS BLOCKER | Enrol in Play App Signing without replacing the upload key. Select Apple team/profile on Mac. |
| Runtime permissions | location + notifications only | location string prepared | READY / IOS BLOCKER | iOS must be validated after Firebase/APNs setup. |
| Background location | not declared and no native foreground location service | not declared | WARNING | Current tracking is an in-app Dart stream and is not guaranteed while minimized/locked. Do not claim background tracking. |
| Account deletion | password-confirmed in-app flow and anonymization exist | shared Flutter UI | CODE READY / PUBLIC URL ACTION | Publish and verify the deletion URL. |
| UGC safety | report/block/moderation API and UI exist | same | CODE READY / OPERATIONS ACTION | Assign a real moderation operator only after approval. |
| Terms acceptance | passenger Terms 1.0 and driver agreement are versioned | same | CODE READY | Publish the matching full Terms text. |
| Support/legal links | localized About/legal screen exists | same | PARTIAL | Support email fixed as `support@tulpartaxi.kz`; stable HTTPS legal pages still require publication. |
| Reviewer access | safe provisioning tooling and instructions exist | same | USER ACTION | Supply non-personal credentials and run the trusted script. |
| Driver payment gate | approved drivers have free access; no payment/shift UI | same | CODE READY | Reviewer is an ordinary approved driver with no exemption or admin rights. |
| OSM attribution | accessible link added to shared map layer | same shared layer | READY | Verify placement on physical devices. |
| Advertising | no ads SDK found | no ads SDK found | READY | Declare “contains ads: no”. |
| Analytics/crash SDK | no Analytics or Crashlytics dependency found | same | READY | Do not declare collection by SDKs that are absent. |
| Branding | MEKEN launcher mipmaps and launch logo are prepared | MEKEN AppIcon and LaunchImage sets are prepared | READY / DEVICE VALIDATION | Validate final masks and launch presentation on physical Android and iOS devices. |
| AAB | deliberately not built | n/a | BLOCKED | Build only after technical/policy blockers are resolved. |

## Toolchain facts

- Flutter 3.41.5 stable; Dart 3.11.3.
- Android Gradle Plugin 8.11.1; Gradle 8.14; Kotlin 2.2.20.
- `compileSdk = 37`; release manifest reports `targetSdk = 36`, `minSdk = 24`.
- Java/Kotlin bytecode target 17.
- Android namespace and application ID: `kz.tulpar.taxi`.
- The Android Firebase file contains a matching `kz.tulpar.taxi` client (and a
  legacy client entry). The selected build package is the matching one.
- Version name/code: `1.0.0` / `1`.
- Release signing reads ignored `android/key.properties`; its keystore exists;
  release is not wired to debug signing. No passwords or key material were
  inspected or copied into this report.

## Android permissions

| Permission | Actual use | Need |
|---|---|---|
| `INTERNET` | API, Firebase, maps, routing | Required |
| `ACCESS_FINE_LOCATION` | pickup/map positioning and driver position during active trip | Required |
| `ACCESS_COARSE_LOCATION` | Android location permission fallback | Required |
| `POST_NOTIFICATIONS` | order/chat/system push on Android 13+ | Required but user may deny |
| `ACCESS_NETWORK_STATE` / `ACCESS_WIFI_STATE` | merged from networking/map/Firebase plugins for connectivity | Required by dependencies; normal permissions |
| `WAKE_LOCK` | active navigation wakelock and Firebase delivery | Required by current features; normal permission |
| `com.google.android.c2dm.permission.RECEIVE` / `com.google.android.providers.gsf.permission.READ_GSERVICES` | Firebase Cloud Messaging | Required by Firebase Messaging; normal/signature-scoped |
| `kz.tulpar.taxi.DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION` | AndroidX protection for non-exported dynamic receivers | Generated internal signature permission; retain |
| `ACCESS_BACKGROUND_LOCATION` | not declared; no implementation needing it | Do not add |
| `FOREGROUND_SERVICE` | no Android foreground service exists | Do not add until such a service exists |
| `FOREGROUND_SERVICE_LOCATION` | no Android foreground service exists | Do not add until such a service exists |
| Camera/storage/microphone/phone/SMS/contacts | no runtime use found | Not declared; keep absent |

Release does not enable cleartext traffic. The debug manifest alone permits
cleartext for local emulators. Package visibility is limited to Android’s
standard process-text intent.

## Location policy

Passengers use foreground location to center/select a pickup and route. Drivers
start a high-accuracy Geolocator stream only on an active-order navigation
screen and send positions to the authenticated API. The stream is stopped when
the screen/session is disposed. Wakelock can keep the active screen awake, but
it is not a native Android foreground location service.

Therefore the current build must not request `ACCESS_BACKGROUND_LOCATION` and
must not promise reliable tracking while the app is minimized, terminated, or
the OS suspends it. A prominent background-location disclosure is not required
for the current permission scope. If uninterrupted minimized/locked tracking is
later made a release requirement, implement a visible foreground location
service first, reassess permissions, and show a localized pre-permission
disclosure that explicitly says the driver’s precise location is sent during an
active trip.

## Google Play Data Safety draft

“Shared” below means disclosure to an independent third party. Firebase and the
MEKEN infrastructure is treated as a processor/service provider; verify this
classification against the final contracts and Play definitions.

| Data | Collected | Shared | Ephemeral | Required | Purpose |
|---|---:|---:|---:|---:|---|
| Phone number | Yes | No | No | Yes | authentication, account management, trip contact |
| Name/profile | Yes | No | No | Yes | account and trip functionality |
| Precise location | Yes | No | Active position is transient; trip points/history may persist | For map/trip features | pickup, routing, driver tracking, safety |
| Approximate location | Potentially derived/provided by OS | No | same scope as location | No | map positioning |
| User/account ID | Yes | No | No | Yes | authentication, security, linking records |
| Orders/trip history | Yes | No | No | Yes | trip functionality, disputes, abuse prevention |
| Chat messages | Yes | No | No | For chat | passenger-driver communication and safety history |
| Ratings/reviews | Yes | No | No | No | service quality and reputation |
| Vehicle information | Yes for drivers | No | No | Driver only | driver approval and passenger information |
| FCM registration token/device identifier | Yes | Firebase processor | No until invalid/logout cleanup | For push | notifications and account security |
| Authentication credentials | Password verifier/server session; raw password must not be retained | No | session tokens expire/rotate | Yes | authentication, fraud prevention |
| Photos/files | No current collection found | No | n/a | No | n/a |
| Advertising identifiers | No ads/tracking SDK found | No | n/a | No | n/a |
| Analytics | No Firebase Analytics dependency found | No | n/a | No | n/a |
| Crash diagnostics | No Crashlytics dependency found; normal server operational logs may contain technical errors | No | retention policy required | Operational | security and reliability |

Data is encrypted in transit by HTTPS. Secure storage is used for app session
material. The final privacy notice must describe retention periods or criteria,
law-enforcement/legal requests, processors, deletion/anonymization, and user
rights using the operator’s actual legal identity and contact.

## Apple App Privacy draft

| Apple data type | Collected | Linked to identity | Tracking | Purpose |
|---|---:|---:|---:|---|
| Contact Info: phone/name | Yes | Yes | No | account management, app functionality |
| Precise Location | Yes | Yes during a trip | No | app functionality, safety |
| Other User Content: chat/reviews | Yes | Yes | No | app functionality, moderation/safety |
| User ID | Yes | Yes | No | authentication/security |
| Purchase information | Do not declare for the free first release unless payment is actually enabled | — | No | — |
| Product Interaction: order/trip history | Yes | Yes | No | app functionality, support, abuse prevention |
| Device ID: FCM/APNs token | Yes | Yes to account | No | app functionality (push) |
| Diagnostics | No dedicated crash/analytics SDK | No | No | n/a |

No evidence of cross-app/site tracking was found. Do not mark data as used for
tracking unless the final release adds such a practice.

## SDK/privacy inventory

- Firebase Core/Auth/Messaging: authentication and push; device token and
  authentication/account metadata are processed by Firebase.
- MapLibre + Flutter Map: map rendering; production map style is served from
  `https://maps.tulpartaxi.kz`.
- Geolocator: OS location only after runtime permission.
- Secure Storage: local protection for session tokens.
- TTS/audio/video/wakelock/url launcher/shared preferences: device-side app
  functionality; no advertising role found.
- No AdMob, Facebook SDK, AppsFlyer, Firebase Analytics, or Crashlytics package
  was found.

## Network and release flags

- Production API default: `https://api.tulpartaxi.kz`.
- Production map style: `https://maps.tulpartaxi.kz/styles/tulpar/style.json`.
- Firebase RTDB URLs are HTTPS.
- Emulator host `10.0.2.2` is gated by the compile-time
  `USE_FIREBASE_EMULATORS` flag and is not the release default.
- `debugShowCheckedModeBanner` is false.
- One unreferenced legacy Dart file still contains public cleartext OSRM code:
  `lib/services/driver/driver_map_screen.dart`. It is not imported by the app;
  the active driver screen uses the Tulpar route service. Remove the legacy
  duplicate in a later cleanup rather than changing navigation during store
  hardening.
- Several error-only `debugPrint` calls remain. No password, auth token, FCM
  token, private key, or phone-value logging was found in those statements, but
  release logging should be gated before final submission.
- No service-account JSON, `.env` secret, keystore, or `key.properties` is Git
  tracked. Firebase client configuration is present and is not a private server
  credential.

## Account deletion

The profile includes a localized two-stage warning and password prompt. The
backend deletion workflow checks active trips/bookings, removes session/push
credentials, deletes or detaches eligible operational records, and anonymizes
the user while retaining necessary transaction/history records. Chat/history is
not blindly erased.

Password-session deletion now verifies the current password without forcing a
Flash Call, and the targeted Store Readiness tests cover that path. The public
deletion page still must be reviewed, published, and verified at the configured
HTTPS URL.

## UGC and terms

Chat and reviews are user-generated content. Report and block actions,
moderation storage/routes, and explicit passenger Terms 1.0 acceptance are now
implemented. The repeatable moderation-admin CLI grants or revokes the role
only for an existing active user and does not expose phone data when listing.
A real moderation operator has deliberately not been assigned.

## Driver payment/free first release

The Flutter client exposes no paid-shift or Kaspi UI. Subscription fields remain
in the unused data architecture, while active-profile checks grant approved
drivers free access and the legacy subscription-creation route returns 410.
Trusted reviewer provisioning creates an ordinary approved driver and does not
grant `access_exempt`, moderation, or other administrative rights.

## iOS readiness

Prepared locally:

- Bundle ID set to `kz.tulpar.taxi` for Runner and corresponding test bundle.
- iOS deployment target remains 13.0.
- Localized RU/KK/EN `NSLocationWhenInUseUsageDescription` resources were added.
- No unnecessary Always location description/background location mode was added.
- A conventional CocoaPods `Podfile` was restored.

Still blocked:

- The current generated Firebase iOS options belong to
  `com.example.taxiEsil`, and `ios/Runner/GoogleService-Info.plist` is absent.
  Register/configure the real `kz.tulpar.taxi` iOS app in Firebase and replace
  generated options on a trusted workstation.
- Push Notifications/APNs entitlement, Apple team, signing certificate, and
  provisioning profile must be enabled/verified in Xcode. Do not fabricate an
  `aps-environment` entitlement on Windows.
- The approved MEKEN artwork is installed in the complete iOS AppIcon set.
- No iOS compilation was attempted or claimed on Windows.

Mac/Xcode 26 validation commands after installing the real Firebase file and
selecting the Apple team:

```sh
flutter pub get
cd ios
pod install --repo-update
cd ..
flutter analyze --no-pub
flutter build ipa --release --build-name 1.0.0 --build-number 1
```

Open `ios/Runner.xcworkspace` in Xcode, enable Push Notifications, confirm the
Release provisioning profile and archive/validate before upload.

## Branding

Android launcher mipmaps and the entire iOS AppIcon set use the approved MEKEN
artwork. The external white canvas was cropped deterministically while preserving
the approved composition. No Android adaptive launcher icon resources existed,
so the project continues to use its current legacy mipmap mechanism. Flutter,
Android, iOS, and web launch branding use working copies; the master files in
`store-readiness/branding/` remain unchanged.

## First-run, reliability, and accessibility checklist

Required manual device matrix before submission:

1. Fresh install; RU/KK/EN; passenger and driver accounts.
2. Location denied once, denied forever, GPS disabled, and permission restored.
3. Notifications denied and later enabled in system settings.
4. Offline/API timeout/expired session; no permanent spinner or false local
   success state.
5. No drivers/no orders/unsupported city empty states.
6. Active trip while foregrounded, screen lock/minimize limitations documented.
7. Small Android device and iPhone SE-size viewport, keyboard open, text scale
   1.3 and 1.5, light/dark themes.
8. City, multi-stop, delivery, intercity, chat unread/read, cancellation,
   navigation, and account deletion step-up.
9. TalkBack/VoiceOver labels, focus order, touch target size, and contrast.

## Blockers before Google Play

1. Publish and verify the privacy, Terms, and deletion URLs.
2. Verify that `support@tulpartaxi.kz` is monitored for the release build.
3. Approve a moderation operator and provision the two reviewer accounts.
4. Complete manual accessibility/first-run/background-behaviour verification,
   including launcher masks and splash presentation on physical devices.

## Blockers before App Store

All Google policy/product blockers, plus:

1. Register Firebase iOS app for `kz.tulpar.taxi`; add the real plist/options.
2. Configure Apple Developer signing and APNs capabilities on Mac.
3. Validate the prepared AppIcon and launch assets on iOS hardware.
4. Build, test, archive, and validate using Xcode 26 on macOS.

## Ready items

- Android package identity, target SDK 36, compile SDK 37, minimum SDK 24.
- Dedicated Android release signing and Play App Signing-compatible upload key.
- Minimal Android permissions; no background/camera/storage/mic/SMS/contact
  permissions.
- HTTPS production API/map/Firebase endpoints and release cleartext disabled.
- No ads, tracking, Analytics, or Crashlytics SDK detected.
- Shared OSM attribution link present on passenger/driver/navigation/intercity
  maps using the common map layer.
- Localized application UI baseline and localized iOS foreground-location text.
- Draft legal copy, data declarations, store metadata, screenshot plan, and
  reviewer instructions are in this directory.

## AAB decision

`MEKEN-1.0.0-production.aab` was not built. The task explicitly permits the
production AAB only after technical blockers are closed. Placeholder store icons
and the unresolved store-critical flows mean that producing an artifact named
“production” would be misleading. No upload was performed.

## Verification performed

- Previous targeted Flutter release-critical tests: **67 passed, 0 failed**. The set
  covered OSM attribution/camera, account-deletion UI/controller, push lifecycle
  and denied-notification paths, launch/profile behavior, GPS/manual map point
  behavior including denial/timeouts, city selection, and auth sessions.
- Current Flutter rerun is blocked by stale absolute SDK/cache paths in
  `.dart_tool/package_config.json` (`C:/src/flutter` and `C:/Android/pub-cache`);
  no successful current Flutter test/analyze result is claimed.
- `git diff --check`: exit code **0** (line-ending notices only).
- `Info.plist` parses as XML on Windows. iOS Xcode/CocoaPods compilation remains
  a Mac-only required check.
- One pre-existing account-deletion widget test depended on the host locale; its
  harness now explicitly selects Russian, matching its Russian expectations.
- Current targeted backend Store Readiness/admin tests: **40 passed, 0 failed**.
- Current targeted free-driver-access/intercity tests: **47 passed, 0 failed**.
