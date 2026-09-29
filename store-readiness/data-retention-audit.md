# MEKEN data retention audit

Audit date: 2026-09-29
Scope: current repository implementation plus the verified production rollout
of migration `20260929_025_account_deletion_privacy_cleanup.sql` and the matching
account-deletion backend on 2026-09-29. Provider consoles, production log
rotation, and backup lifecycle policy remain outside repository evidence.

## Evidence and interpretation

The account-deletion transaction is implemented in
`backend/src/account-deletion.js`, especially `anonymizeUser`. Its schema basis
is `tulpar-schema.sql` plus migrations `004`, `007`-`010`, `015`-`024`.
Integration evidence is in
`backend/integration-test/account-deletion.postgres.test.js`.

The implementation creates a retained `users` tombstone. It does not delete the
user row or historical orders. Therefore "deleted" below means a physical row
delete, while "anonymized" means selected fields are cleared or replaced and
the remaining row can still be linked through the internal user UUID.

Unless a row below states a concrete technical TTL, the current retention is:

**NO EXPLICIT RETENTION PERIOD IN CURRENT IMPLEMENTATION**

An `expires_at` value that only prevents later use is not a physical-retention
policy when no cleanup job deletes the row.

## Executive findings

- Physical deletion occurs for push tokens, phone-identity mappings, sessions,
  Terms acceptances, blocks, and the driver profile.
- Core user PII (`firebase_uid`, `phone`, `name`, `password_hash`) is cleared;
  the user UUID, account timestamps, locale, deletion status, and tombstone
  remain.
- Orders, offers, ratings, intercity rides/bookings/requests, subscription
  records, reports, and deletion jobs remain.
- Passenger pickup/destination fields on `orders` and pickup fields on
  intercity bookings/requests are cleared. Driver live coordinates are cleared.
- `order_stops` rows are preserved, but exact addresses and coordinates are
  cleared for orders where the deleted user was passenger or driver.
- Intercity ride origin/destination cities and history remain, while exact
  coordinates and the driver comment are cleared for a deleted driver.
- Auth OTP/password-verification rows matching the deleted account phone are
  physically deleted. A bounded background cleanup removes consumed/expired
  password verifications, OTP challenges after both expiry and resend windows,
  and expired sessions without adding an arbitrary retention grace period.
- Message text authored by the deleted user is replaced, not physically
  deleted. Other participants' text remains unchanged.
- No repository-level cleanup schedule exists for historical business rows,
  reports, moderation records, subscriptions, completed deletion jobs, or
  Docker application logs. Expired/consumed auth history is cleaned every five
  minutes by the production backend.

## CURRENT PRODUCTION IMPLEMENTATION

Migration `20260929_025_account_deletion_privacy_cleanup.sql` and the matching
account-deletion backend were applied to production on 2026-09-29. The
production schema allows the three stop-location fields to be `NULL` together
and enforces this with `order_stops_location_complete`.

| Data class | Collected | Purpose | Stored where | Account-deletion behavior | Retained after deletion | Current technical retention |
|---|---|---|---|---|---|---|
| User account/profile | Yes | Account, authentication, role and trip linkage | PostgreSQL `users` | `firebase_uid`, `phone`, `name`, and `password_hash` become `NULL`; rating aggregate resets; status becomes `deleted` | Yes: UUID, locale, `created_at`, `updated_at`, `deleted_at`, and tombstone status remain | **NO EXPLICIT RETENTION PERIOD IN CURRENT IMPLEMENTATION** |
| Phone number in active identity | Yes | Authentication and account recovery | `users.phone`, `auth_phone_identities.phone_normalized` | User phone is cleared and phone-identity row is physically deleted | No in these two locations | Deleted during account deletion |
| Phone number in auth history | Yes | OTP/password setup and reset | `auth_otp_challenges.phone_normalized`, `auth_password_verifications.phone_normalized` | Matching password-verification rows are deleted by user ID/phone, then matching OTP rows are deleted by phone | No matching rows after successful account-deletion transaction | OTP validity defaults to 300 seconds (configurable 60-1800); password verification validity is 10 minutes; background cleanup removes rows once no longer usable |
| Password hash | Yes | Password authentication | `users.password_hash` | Set to `NULL` | No | Deleted during account deletion |
| Sessions and refresh-token hashes | Yes | Authentication and session security | `auth_sessions` | Rows physically deleted | No | Default refresh validity is 30 days, configurable up to 365 days; expired rows are removed by the background auth-history cleanup |
| Session device/IP metadata | Yes | Authentication security | `auth_sessions.device_id`, `device_name`, `ip_created`, `user_agent` | Physically deleted with session rows | No in `auth_sessions` | Same as sessions |
| OTP request device/IP metadata | Yes | OTP abuse prevention and provider correlation | `auth_otp_challenges.request_ip`, `device_id`, `provider`, `provider_request_id` | Matching rows are physically deleted with the account | No matching rows after successful deletion | Background cleanup removes an OTP row only after both challenge expiry and resend cooldown, and after any linked password-verification context is gone |
| FCM tokens | Yes | Push notifications | `user_push_tokens` and Firebase Cloud Messaging | PostgreSQL token rows physically deleted | No in application DB; provider-side deletion/retention is not proven by this repository | Deleted during account deletion; Firebase-side state: **VERIFY OUTSIDE REPOSITORY** |
| Firebase Auth identity | Conditional | Firebase authentication path | Firebase Auth and `users.firebase_uid` | Local UID cleared. A durable job retries `Firebase Admin deleteUser` every five minutes. Completed jobs clear raw UID; pending/failed jobs retain it | Hash always remains; raw UID remains while pending and indefinitely on terminal failure until operator action | Job retry limit 20; job/hash cleanup has **NO EXPLICIT RETENTION PERIOD IN CURRENT IMPLEMENTATION** |
| Driver profile and vehicle data | Yes for drivers | Driver eligibility and passenger identification | `driver_profiles`: status, car model/color/plate, agreement and work city | Entire driver-profile row physically deleted | No in driver profile; historical orders/intercity rides still link the driver UUID | Deleted during account deletion |
| CITY order history | Yes | Dispatch, trip execution, disputes and history | `orders`, `order_offers`, `order_stops`, messages, ratings | Order row remains. Passenger top-level pickup/destination fields, exact stop fields for either participant, and driver live location are cleared. Pending offers are withdrawn | Yes: order UUID/type/status, prices, distance, timestamps, participant UUIDs, cancellation fields, stop sequence/type/timestamps and offer history | **NO EXPLICIT RETENTION PERIOD IN CURRENT IMPLEMENTATION** |
| DELIVERY order history | Yes | Delivery dispatch and fulfilment | `orders`, `delivery_details` | Same order behavior. For orders owned by deleted passenger, names, phones, door/apartment/floor/intercom/comments are cleared and item description becomes `[удалено]`; handoff types and timestamps remain | Yes: order history, prices, participant UUIDs, redacted delivery row | **NO EXPLICIT RETENTION PERIOD IN CURRENT IMPLEMENTATION** |
| Legacy INTERCITY order history | Yes | Legacy intercity order fulfilment | `orders`, `intercity_details` | Passenger order addresses/coordinates cleared; `intercity_details.comment` cleared | Yes: order/timing/passenger count/luggage/prices/participant UUIDs | **NO EXPLICIT RETENTION PERIOD IN CURRENT IMPLEMENTATION** |
| Intercity driver rides | Yes | Publish and operate a scheduled intercity ride | `intercity_rides` | Driver-authored comment and exact origin/destination coordinates are cleared | Yes: driver UUID, origin/destination city identifiers/names, date, seats, price, luggage, status and timestamps | **NO EXPLICIT RETENTION PERIOD IN CURRENT IMPLEMENTATION** |
| Intercity bookings | Yes | Seat reservation, pickup and trip history | `intercity_ride_bookings` | Passenger pickup address/coordinates and comment cleared | Yes: passenger UUID, ride link, seats, prices, status, client request ID, pickup-reached and timestamps | **NO EXPLICIT RETENTION PERIOD IN CURRENT IMPLEMENTATION** |
| Intercity ride requests | Yes | Match passengers with intercity rides | `intercity_ride_requests` | Pickup address/coordinates and passenger comment cleared | Yes: passenger UUID, cities, travel date, seats, status and timestamps | **NO EXPLICIT RETENTION PERIOD IN CURRENT IMPLEMENTATION** |
| Primary pickup/dropoff address and coordinates | Yes | Routing and fulfilment | `orders` | Cleared when deleted user is the passenger | No in those top-level fields for that passenger | Cleared during account deletion |
| Intermediate stop address and coordinates | Yes | Multi-stop route fulfilment | `order_stops` | Address/latitude/longitude are set to `NULL` when either order participant deletes the account | No exact stop location; stop UUID, sequence, type, reached time and order link remain | Exact location deleted with account; minimized stop history has **NO EXPLICIT RETENTION PERIOD IN CURRENT IMPLEMENTATION** |
| Driver live coordinates | Yes | Active-trip tracking and approaching notification | `orders.driver_lat/lng` | Cleared on all orders where deleted user is driver | No in order driver-location fields | Cleared during account deletion |
| Geocoding/routing queries | Yes when feature used | Address lookup, reverse geocoding and routes | Sent through backend; Nominatim receives search/reverse data; configured OSRM receives route coordinates | No DB persistence was found in these route handlers; provider-side logs are outside repository | Possibly at providers | Application-side persistent TTL not applicable; provider retention: **VERIFY OUTSIDE REPOSITORY** |
| City chat messages | Yes, optional | Participant communication | `order_messages` | Deleted user's text replaced with `[сообщение удалено]`; row, sender UUID and timestamp remain | Yes, redacted. Other users' messages remain unchanged | **NO EXPLICIT RETENTION PERIOD IN CURRENT IMPLEMENTATION** |
| Intercity chat messages | Yes, optional | Booking communication | `intercity_booking_messages` | Same replacement for deleted sender | Yes, redacted. Other users' messages remain unchanged | **NO EXPLICIT RETENTION PERIOD IN CURRENT IMPLEMENTATION** |
| Chat read state | Yes | Unread badge/state | `order_chat_reads`, `intercity_booking_chat_reads` | Not explicitly deleted because user row remains | Yes | **NO EXPLICIT RETENTION PERIOD IN CURRENT IMPLEMENTATION** |
| Ratings and reviews | Yes, optional | Reputation and safety | `ratings`, aggregate fields in `users` | Comment authored by deleted user becomes `NULL`; score and from/to UUIDs remain. Aggregate resets. Comments written by others about the deleted user remain unchanged | Yes | **NO EXPLICIT RETENTION PERIOD IN CURRENT IMPLEMENTATION** |
| Content reports | Yes, optional | Safety and moderation | `content_reports` | Not touched | Yes: reporter/reported UUIDs, reason code/text, context links, status, resolver and timestamps | **NO EXPLICIT RETENTION PERIOD IN CURRENT IMPLEMENTATION** |
| Blocks | Yes, optional | Safety and future matching | `user_blocks` | All rows involving user physically deleted | No | Deleted during account deletion |
| Terms acceptance history | Yes | UGC/terms gate | `user_terms_acceptances` | Rows physically deleted | No | Deleted during account deletion |
| Moderation administrator record | Conditional | Authorize moderation access | `moderation_admins` | Not touched because user tombstone is retained | Yes; a deleted user can remain listed as a moderation admin record, although active-account auth should prevent access | **NO EXPLICIT RETENTION PERIOD IN CURRENT IMPLEMENTATION** |
| Moderation resolution record | Conditional | Audit report decisions | `content_reports.resolved_by/resolved_at` | Not touched | Yes | **NO EXPLICIT RETENTION PERIOD IN CURRENT IMPLEMENTATION** |
| Driver subscription/payment legacy record | Conditional | Driver access and payment state | `driver_subscriptions` | Active subscription status becomes `cancelled`; amount, periods, payment status/reference and driver UUID remain | Yes | **NO EXPLICIT RETENTION PERIOD IN CURRENT IMPLEMENTATION** |
| Account deletion audit/retry job | Yes on deletion | Idempotency, Firebase deletion retry and recovery | `account_deletion_jobs` | Job remains. Raw Firebase UID is cleared only on completion; irreversible UID hash and user UUID remain. Terminal failure retains raw UID | Yes | Retry lease 5 minutes, retry limit 20; row/hash/raw-failure cleanup has **NO EXPLICIT RETENTION PERIOD IN CURRENT IMPLEMENTATION** |
| Server/application logs | Yes operationally | Reliability, security and diagnostics | Container stdout/stderr and hosting stack | Account deletion does not address logs | Potentially | Compose/Docker configuration sets no rotation or retention. **NO EXPLICIT RETENTION PERIOD IN CURRENT IMPLEMENTATION**; production host/aggregator: **VERIFY OUTSIDE REPOSITORY** |
| Photos and identity documents | No repository evidence of upload/storage | Not established | No image/file picker, upload endpoint, object-storage dependency, or DB media field was found | Not applicable in reviewed repo | Unknown outside repo | **VERIFY OUTSIDE REPOSITORY** for provider consoles/manual operations |

## Personal data remaining after account deletion

| Personal data | Actual result |
|---|---|
| Primary account phone | Cleared from `users`, deleted from `auth_phone_identities`, and matching OTP/password-verification rows are physically deleted |
| Name | Cleared from `users`; delivery sender/recipient names are cleared for the deleted passenger's delivery orders |
| Password hash | Cleared |
| Precise primary pickup/dropoff | Cleared for passenger-owned orders and passenger intercity pickup fields |
| Intermediate stops | Stop records remain, but exact address and coordinates are cleared |
| Intercity driver's origin/destination coordinates | Exact coordinates are cleared; city-level origin/destination and minimized ride history remain |
| Driver live location | Cleared from `orders` driven by the deleted user |
| City/intercity chat text authored by user | Replaced by a deletion marker; sender UUID and timestamps remain |
| Chat text authored by others | Remains unchanged, even if it mentions the deleted user |
| Vehicle plate and vehicle profile | Driver-profile row is physically deleted |
| Photos/documents | No collection/storage path found in repository; **VERIFY OUTSIDE REPOSITORY** |
| Review text | Deleted user's authored comment is cleared; another user's comment about the deleted user remains |
| Report text and moderation metadata | Remain unchanged, linked to retained user UUIDs |
| Terms acceptance | Physically deleted |
| Block relationships | Physically deleted |
| IP/device identifiers | Sessions and matching OTP/password history are deleted with the account; expired auth history is removed after its security windows close |
| Firebase identifier | Cleared locally; raw UID remains in pending/failed deletion job until success/manual recovery; hash remains indefinitely |

## NOT YET IMPLEMENTED

1. Content reports, free-text reasons, moderation resolver data, and moderation
   admin membership have no deletion/anonymization rule or TTL.
2. Other users' chat/review text can continue to contain the deleted user's
   personal data.
3. Subscription/payment references, Terms evidence policy, and minimized
   historical business records have no approved retention/purge schedule.
4. Failed Firebase deletion jobs retain the raw Firebase UID until manual
   recovery; completed jobs and UID hashes have no cleanup schedule.
5. The `users` tombstone and pseudonymous participant references have no final
   purge or irreversible re-key process.

## EXTERNAL RETENTION TO VERIFY

1. Docker/application log retention, reverse-proxy logs, database backups,
   provider logs, and deletion propagation to backups are not defined in the
   repository.
2. Firebase Auth/FCM, Mobizon/AutoCall, Nominatim and OSRM provider retention
   must be verified with the production configuration and contracts.
3. Public app API defaults to HTTPS, but `OSRM_BASE_URL` accepts HTTP as well as
   HTTPS and the live value is not in the repository. End-to-end production
   transport encryption must be verified externally.
4. Production payment processing and any manual driver-document storage remain
   outside repository evidence.

## Remaining implementation risks

1. Subscription/payment references and historical business records have no
   explicit retention or purge schedule.
2. Routine post-trip minimization is not implemented: exact trip and delivery
   PII may remain indefinitely while an account stays active.

## PROPOSED RETENTION POLICY — REQUIRES OWNER APPROVAL

This section is a proposal, not a statement of current behavior or Kazakhstan
legal requirements. Owner and qualified legal/privacy review are required.

| Data class | Proposed retention/principle | Current alignment |
|---|---|---|
| Active account profile and credentials | Keep while account is active; clear direct identifiers immediately on confirmed deletion | Mostly aligned |
| User tombstone/internal UUID | Keep only as long as necessary to preserve required transaction/safety records; prevent use as a public identity; delete or irreversibly re-key after the longest approved linked-record period | Not implemented; no terminal purge/re-key |
| Sessions, push tokens and phone identity | Delete immediately on account deletion; purge expired sessions and invalid FCM tokens promptly | Account deletion is aligned; expired sessions are cleaned every five minutes; invalid-token removal is event-driven rather than a scheduled sweep |
| OTP/password verification data | Purge when no longer usable; if a narrowly justified fraud window is later approved, retain only minimized hashed/risk signals instead of raw phone/IP/device/provider IDs | Aligned locally: deleted with account and background cleanup runs after expiry/security windows |
| Primary and intermediate route addresses/coordinates | Remove or coarse-grain 30 days after completion/cancellation; remove immediately on account deletion unless an open safety/dispute hold applies | Account-deletion path aligned locally; routine post-trip TTL is not implemented |
| Driver live location | Keep only during active trip plus a short operational buffer, proposed maximum 24 hours; do not retain as history | Deletion aligned; routine TTL not implemented |
| Order history and prices | Retain a minimized, pseudonymous transaction record for 3 years after completion/cancellation, subject to owner/legal approval; exclude precise location and free text after their shorter windows | Not implemented; retained indefinitely |
| Delivery contact/access details | Clear 30 days after completed/cancelled delivery and immediately on account deletion; retain only minimized order facts | Account deletion aligned; routine TTL not implemented |
| Intercity rides/bookings/requests | Apply the same 3-year minimized transaction period; clear pickup coordinates/comments within 30 days and expire unmatched requests within 30 days after travel date | Partly aligned on deletion; routine purge not implemented |
| Chat messages | Delete or irreversibly redact 90 days after trip/booking closure; reported content may move to a restricted moderation record until the report period ends | Deletion redaction exists; routine TTL/evidence hold not implemented |
| Ratings/reviews | Keep score while needed for reputation, proposed maximum 3 years; remove free text on account deletion and within 1 year after posting unless under report review | Partly aligned; TTL and other-authored PII handling not implemented |
| Reports and moderation records | Keep open cases until closure, then 1 year; retain only minimized pseudonymous parties and decision evidence; remove moderator role immediately when account is deleted | Not implemented |
| Blocks | Keep while both accounts are active; delete when either account is deleted | Aligned |
| Terms acceptance | Retain a minimized version/timestamp proof for 5 years after acceptance or account deletion, subject to legal approval; do not retain unrelated profile data | Current deletion removes it, so proposed evidence retention is not aligned |
| Subscription/payment references | Retain only legally/accountingly required fields for a proposed 5 years, subject to Kazakhstan counsel; never store card/bank credentials in this schema | Historical rows persist but no approved TTL; not aligned |
| Account deletion jobs | Keep raw Firebase UID only until provider deletion succeeds; manual escalation within 24 hours and resolve within 30 days; delete raw UID immediately after resolution and purge/hash-rotate completed jobs after 90 days | Partly aligned; failed/completed cleanup not implemented |
| Operational logs | 30 days for normal application logs; up to 90 days for restricted security logs; redact tokens, phone numbers, addresses and coordinates | Repository avoids bodies/headers in generic error logs, but retention is not configured |
| Backups | Encrypted rolling backups for 30 days; deleted data ages out through rotation; access audited and restore procedures reapply deletion requests | **VERIFY OUTSIDE REPOSITORY** and not evidenced in code |

### Overall policy mismatch

The production account-deletion cleanup now covers auth-history PII,
intermediate stops, delivery contacts, intercity exact coordinates/comments,
and Firebase raw UID removal after successful provider deletion. The proposed
policy still cannot be published as fully implemented: routine post-trip
retention is not implemented, and moderation, historical records, logs/backups
and provider retention still require decisions. The legal placeholder
`<RETENTION_POLICY>` must remain unchanged. The decision-ready matrix is kept
separately in `retention-policy-proposal.md`.
