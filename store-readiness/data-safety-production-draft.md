# MEKEN Google Play Data Safety — production evidence draft

Audit date: 2026-09-29
Status: draft for Play Console completion; not a legal policy.

This draft is based only on current repository code and schema. "Shared" below
describes technical disclosure to another participant or external processor.
Whether a Google Play service-provider or user-initiated-transfer exception
applies must be confirmed when answering the Console questionnaire.

## Transport-security evidence

- Flutter production API default: `https://api.tulpartaxi.kz`.
- Map style: `https://maps.tulpartaxi.kz/...`.
- Nominatim, Mobizon, AutoCall, Firebase SDK/CDN endpoints use HTTPS in code.
- Backend routing allows `OSRM_BASE_URL` to be either HTTP or HTTPS; its live
  value is not stored in the repository.
- Compose exposes backend only on localhost, but reverse-proxy TLS config and
  the live certificate are outside this repository.

Therefore the draft answer is: **encrypted in transit for evidenced public app
and provider paths, but VERIFY OUTSIDE REPOSITORY for live reverse proxy,
OSRM_BASE_URL, provider configuration, certificate policy, and any host-level
connections.**

## Data-type matrix

| Google Play / technical data type | Collected | Shared | Purpose | Required / optional | Temporary / persistent | Encrypted in transit | Deletion behavior | Verification needed |
|---|---|---|---|---|---|---|---|---|
| Name | Yes | Shown to matched trip/chat participants; Firebase Auth path may also process profile identity | Account profile, participant identification, safety | DB nullable; actual UI requirement must be confirmed | Persistent | Public API default HTTPS | Cleared from `users`; delivery names cleared for deleted passenger | Confirm Firebase profile fields and Play user-initiated-sharing exception |
| Phone number | Yes | Sent to configured SMS/flash-call provider; Firebase Auth path may process it; delivery sender/recipient phones are available to fulfil delivery | Authentication, recovery, delivery coordination | Required for account; delivery contact fields conditional | Persistent, including auth history | Mobizon/AutoCall and API endpoints use HTTPS in code | Cleared from main user/identity and delivery details, but remains in OTP/password-verification history | Verify production verification provider, provider retention, and cleanup gap |
| Internal user ID / Firebase UID | Yes | Firebase UID is processed by Firebase; internal IDs are sent in operational API payloads where required | Authentication, relational integrity, deletion idempotency | Required | Persistent | API/Firebase transport evidenced as HTTPS/SDK | Local Firebase UID cleared; Firebase user deletion retried; internal UUID and UID hash remain | Verify provider deletion completion and job monitoring |
| Precise location | Yes | Shared with trip counterpart; sent to Nominatim/OSRM for geocoding/routing | Pickup, destination, route, driver tracking and safety | Required when using route/trip features | Both temporary and persistent | API/Nominatim HTTPS; live OSRM must be verified | Primary passenger fields and driver live location cleared; intermediate stops and driver intercity coordinates remain | Verify live OSRM scheme/provider retention; fix deletion gaps before claiming full deletion |
| Approximate location / city | Yes | Matched participants and routing/geocoding providers as applicable | City selection, dispatch and intercity search | Required for relevant service | Persistent in order/intercity history | Same as precise location | City/route history remains after deletion | Confirm Play category selection and approved retention |
| Addresses | Yes | Matched driver/passenger; Nominatim for address lookup | Pickup/dropoff/delivery fulfilment | Required per order | Persistent | API and Nominatim HTTPS in code | Top-level order and intercity pickup addresses cleared; `order_stops` remains | Cleanup blocker; verify provider retention |
| City/intercity chat messages | Yes | Shared with the other participant and potentially transmitted via Firebase notification payload | In-trip communication and safety | Optional | Persistent | API/FCM channels use HTTPS/SDK | Deleted sender's text replaced; other text remains | Confirm whether notification contains body text and Play exception classification |
| Ratings/reviews | Yes | Displayed to relevant users/public driver profile; reports may expose them to moderators | Reputation, quality and safety | Optional | Persistent | API HTTPS default | Deleted author's comment cleared; score/link remains; other-authored comments remain | Approve TTL and assess free-text PII |
| User reports | Yes | Internal moderators; referenced content may be operationally accessible | Safety, abuse prevention and moderation | Optional | Persistent | API HTTPS default | Retained unchanged after deletion | Approve retention and pseudonymization policy |
| Block list | Yes | No external disclosure evidenced | Safety and future matching | Optional | Persistent while account active | API HTTPS default | Physically deleted when either side's account deletion invokes current code | Confirm no provider copy |
| Terms acceptance | Yes | No external disclosure evidenced | Legal/UGC consent gate | Required before UGC actions | Persistent while account exists | API HTTPS default | Physically deleted on account deletion | Decide whether legal evidence must instead be retained |
| Vehicle model/color/plate | Yes for drivers | Shared with passengers and intercity riders | Driver qualification and vehicle identification | Required for driver role only | Persistent | API HTTPS default | Driver-profile row physically deleted | Confirm no manual/off-repository copies |
| Driver agreement version/time | Yes for drivers | No external disclosure evidenced | Driver onboarding and evidence of agreement | Required for driver role | Persistent | API HTTPS default | Deleted with driver profile | Decide approved evidence retention |
| Order/trip history | Yes | Shared with trip participants; routing/notification processors receive subsets | Core service, history, disputes and safety | Required when ordering/driving | Persistent | API HTTPS default; OSRM caveat | Historical rows remain; selected PII is redacted | Approve minimized retention period |
| Delivery contact/access details | Conditional | Shared with assigned driver | Delivery fulfilment | Required only for selected handoff needs | Persistent | API HTTPS default | Names/phones/access notes cleared for deleted passenger; handoff type/timestamps remain | Confirm UI optionality and TTL |
| Order prices and payment/subscription history | Yes | No payment processor integration is proven; participants see agreed order price | Fare agreement and driver-access legacy flow | Order price required; paid driver access conditional/legacy | Persistent | API HTTPS default | Orders remain; active subscriptions cancelled but amount/status/reference remain | Verify whether production accepts payments and whether any processor exists outside repo |
| Payment card/bank account data | No repository evidence | No | Not implemented in reviewed repo | Not applicable | Not applicable | Not applicable | Not applicable | **VERIFY OUTSIDE REPOSITORY** and provider/store configuration |
| FCM registration token | Yes | Firebase Cloud Messaging | Push notifications | Optional; app should function with reduced notifications if unavailable | Persistent | Firebase SDK | Application DB token rows deleted | Verify Firebase provider retention and console settings |
| Device ID/name | Yes during password auth/OTP when supplied | Auth verification provider may receive correlation data; host logs/providers unknown | Session security and abuse prevention | Automatically collected/conditional | Persistent in auth tables | API/provider HTTPS in code | Session copy deleted; OTP copy remains | Cleanup blocker and **VERIFY OUTSIDE REPOSITORY** |
| IP address | Yes during password auth/OTP | Hosting/network provider and auth provider may process it | Security and abuse prevention | Automatically collected | Persistent in auth/session records and infrastructure logs | Network transport itself does not remove collection | Session copy deleted; OTP copy remains; host log behavior unknown | Cleanup blocker; verify proxy/provider/host logs |
| User agent | Yes for password sessions | Hosting stack may process it | Session security | Automatically collected | Persistent | API HTTPS default | Deleted with session | Verify reverse-proxy access logs |
| OTP/provider request identifiers | Yes | SMS/flash-call provider | Authentication and fraud control | Required for that auth method | Persistent after short validity window | Provider endpoints HTTPS | Not deleted by account deletion | Cleanup blocker; provider retention **VERIFY OUTSIDE REPOSITORY** |
| App interactions (offers, status changes, cancellations) | Yes | Matched participant receives relevant status/offer | Core service, dispatch, safety and dispute history | Required when feature used | Persistent | API HTTPS default | Rows/audit fields remain after account deletion | Approve retention and free-text cancellation handling |
| Crash/performance diagnostics | No client Crashlytics/analytics dependency found | Server/container operators may receive operational errors | Reliability/security | Not established | Unknown | Unknown outside repo | Not covered by account deletion | Host/monitoring stack: **VERIFY OUTSIDE REPOSITORY** |
| Server/application logs | Yes operationally | Hosting/container operator; any aggregator is unknown | Reliability and security | Automatically generated | Persistent duration unknown | Host path unknown | Not affected by account deletion | Rotation, aggregation, backup and access: **VERIFY OUTSIDE REPOSITORY** |
| Photos/videos | No user upload path found; bundled splash video is not user data | No repository evidence | Not collected | Not applicable | Not applicable | Not applicable | Not applicable | **VERIFY OUTSIDE REPOSITORY** for manual/provider processes |
| Audio/voice recordings | No recording/upload path found; TTS and bundled audio are output assets | No repository evidence | Not collected | Not applicable | Not applicable | Not applicable | Not applicable | **VERIFY OUTSIDE REPOSITORY** |
| Files/documents | No upload/storage path found | No repository evidence | Not collected | Not applicable | Not applicable | Not applicable | Not applicable | **VERIFY OUTSIDE REPOSITORY** for driver verification performed manually |

## External processors and recipients evidenced by code

- Firebase Authentication/Admin: authentication identity and remote deletion.
- Firebase Cloud Messaging: device token and notification payload.
- Mobizon, when `TULPAR_SMS_PROVIDER=mobizon`: phone number and OTP SMS.
- AutoCall, when configured: phone number and flash-call verification metadata.
- OpenStreetMap Nominatim: address queries and/or coordinates for geocoding.
- OSRM selected by `OSRM_BASE_URL`: route coordinates.
- Matched passengers/drivers: names, trip details, live location, vehicle data,
  messages and applicable delivery contact details.

Actual production provider selection, contracts, geographic processing,
provider retention, Play service-provider exceptions, and any infrastructure
processor are **VERIFY OUTSIDE REPOSITORY**.

## Play Console answers supported by repository evidence

- Account creation collects phone number and account identifiers.
- The app collects precise location for route/trip functions.
- The app stores orders, prices, messages, reviews, reports, vehicle data and
  notification tokens.
- Data is used for app functionality, account management, communication,
  safety/fraud prevention and notifications.
- Users can initiate account deletion in the app; code clears or redacts many
  direct identifiers but retains historical/pseudonymous records.
- No advertising SDK, analytics SDK, Crashlytics dependency, user media upload,
  payment-card field, or bank-account field was found.
- Public production API and map URLs default to HTTPS.

## Answers requiring external verification

1. Live reverse-proxy TLS/certificate configuration and live `OSRM_BASE_URL`.
2. Production authentication/SMS/flash-call provider selection and retention.
3. Firebase Auth/FCM console retention and deletion completion monitoring.
4. PostgreSQL encryption at rest, disk encryption, backups, backup retention,
   deletion propagation and disaster-recovery copies.
5. Docker stdout/stderr rotation, reverse-proxy access logs, centralized logs,
   monitoring and host-provider retention.
6. Whether paid driver access/payment processing is enabled in production or
   exists outside this repository.
7. Whether manual driver review stores photos/documents outside the application.
8. Google Play's final required/optional and sharing-exception classification
   for user-initiated disclosures and service providers.

## Blocking statement

Do not submit the final Data Safety form from this draft without resolving or
accepting the gaps listed in `data-retention-audit.md`, especially auth-history
PII, intermediate-stop coordinates, intercity driver coordinates, moderation
records, logs/backups, and the absence of explicit retention cleanup.
