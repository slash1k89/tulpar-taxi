# User action required before store release

The source deliberately does not invent or commit the values below.

## Legal and support data

- Confirmed operator wording: `Оператор сервиса MEKEN — ИП "Оспанов", индивидуальный предприниматель Махамбетов Нурлан Муратович, Республика Казахстан.`
- IIN/BIN: `<IIN_OR_BIN>`.
- Legal/postal address: `<LEGAL_ADDRESS>`.
- Registration details: `<REGISTRATION_DETAILS>`.
- Registration authority: `<REGISTRATION_AUTHORITY>`.
- Support email is fixed as `support@tulpartaxi.kz`. Keep `TULPAR_SUPPORT_EMAIL` as the technical build-time override and verify that the monitored mailbox is operational before release.
- Terms of Use version 1.0 effective date: `<TERMS_EFFECTIVE_DATE>`.
- Privacy Policy effective date: `<PRIVACY_EFFECTIVE_DATE>`.
- Legally approved retention periods or objective retention criteria for trip, chat, report, safety, audit, and deleted-account records: `<RETENTION_POLICY>`.
- Legal approval of the RU/KK/EN texts and permission to publish the three pages at `/privacy`, `/terms`, and `/account-deletion`.

## Store reviewer data

- Two new, non-personal Kazakhstan phone numbers for `<REVIEW_PASSENGER_PHONE>` and `<REVIEW_DRIVER_PHONE>`.
- Strong unique values for `<REVIEW_PASSENGER_PASSWORD>` and `<REVIEW_DRIVER_PASSWORD>`, entered only at runtime and in the private store consoles.
- Approved review work-city slug and fictional vehicle model, colour, and registration number.

## iOS and branding actions

- Register the Firebase iOS app with bundle ID `kz.tulpar.taxi`, download its real `GoogleService-Info.plist`, and regenerate/verify FlutterFire iOS options.
- Select the Apple Developer team and distribution signing profile on macOS; enable Push Notifications/APNs and verify the production entitlement in the signed archive.
- Supply approved square/adaptive launcher artwork to replace the stock Flutter AppIcon/launcher icons, and approve the final display name/branding.
- Run CocoaPods, build, archive, and validate on the supported macOS/Xcode environment. No iOS build or signing was attempted on Windows.

## Publication actions

- Publish the reviewed static legal pages over HTTPS at the exact URLs used by the app and verify they remain reachable without authentication.
- Create reviewer accounts with the trusted provisioning script, test them, then place credentials only in Google Play Console and App Store Connect.
