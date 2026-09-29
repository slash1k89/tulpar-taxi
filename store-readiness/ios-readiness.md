# iOS readiness audit (Windows source review)

| Item | Source-tree result | Required external action |
|---|---|---|
| Bundle ID | `kz.tulpar.taxi` for Runner | Register the same App ID/Firebase app |
| Info.plist | Valid source file; foreground location text present | Recheck in final archive |
| Location strings | RU/KK/EN `InfoPlist.strings` present | Device-language verification |
| Background modes | No background-location mode declared | Keep absent unless a real native background feature is added |
| Push capability | No fabricated Windows entitlement | Enable Push Notifications/APNs in Xcode and provisioning |
| URL schemes | No custom callback scheme is currently required by the implemented auth flow | Reassess if a future SDK requires one |
| Podfile | iOS 13.0 CocoaPods configuration present | Run `pod install` on macOS |
| Firebase iOS | `GoogleService-Info.plist` is absent; existing generated iOS options are not the production bundle | Supply real plist and regenerate options |
| AppIcon | Asset set exists but uses placeholder Flutter art | Supply approved artwork |
| Launch screen | Storyboard exists | Visually verify with final branding on devices |
| Signing | Cannot be validated on Windows | Select Apple team/profile and validate archive on macOS |

This file is an audit, not proof of an iOS build. No plist, entitlement,
certificate, provisioning profile, or successful Xcode archive is fabricated.
