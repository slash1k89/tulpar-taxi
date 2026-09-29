# MEKEN retention policy proposal

Status: **PROPOSAL — REQUIRES OWNER AND LEGAL APPROVAL**

Prepared: 2026-09-29

This document does not describe an already adopted policy. Current production
behavior is documented in `data-retention-audit.md`. No period below should be
published or implemented until the operator and qualified legal/privacy counsel
approve it.

## Decision principles

1. Minimize precise location and free-text PII first.
2. Remove expired security artifacts promptly without weakening an active
   verification, reset, resend, or session flow.
3. Preserve only minimized commercial, dispute, accounting, and consent history
   until its legally appropriate period is confirmed.
4. A documented legal hold must suspend only the affected purge and must be
   access-controlled and auditable.
5. Backups and external processors need separate verified schedules; application
   deletion alone does not prove deletion from those systems.

## Proposed retention matrix

| Category / data | Current production behavior | Proposed retention period | Reason | Delete or anonymize | Backend/schema/job required | User impact | Legal approval |
|---|---|---|---|---|---|---|---|
| OTP challenges | Active challenge defaults to 5 minutes; cleanup every 5 minutes removes a row after expiry and resend window, once no password-verification context references it; matching rows are deleted with account | Keep current usable-window rule; no additional grace period by default | Authentication and resend safety only | Physically delete row, including phone, IP/device and provider IDs | No for baseline; optional metrics should be anonymous | None if active windows remain protected | Confirm that no fraud-evidence window is required |
| Password verifications | Valid for 10 minutes; consumed/expired rows are removed every 5 minutes; matching rows are deleted with account | Keep until consumed or expired, then delete in next cleanup cycle | Password setup/reset authorization | Physically delete | No | None | Confirm |
| Sessions | Refresh validity defaults to 30 days; expired rows are cleaned every 5 minutes; all user sessions are deleted with account | Active session until expiry/revocation; delete expired/revoked sessions within 24 hours | Login continuity and security audit during validity | Physically delete token hash and device/IP metadata | Small cleanup extension for revoked-but-not-expired rows | Users may need to sign in again after revocation, as expected | Confirm security/audit need |
| FCM tokens | Rows deleted with account; invalid tokens can be removed after provider failure | Active account plus last successful registration; delete invalid/stale tokens within 30 days | Push delivery | Physically delete | Scheduled stale-token cleanup and `last_seen_at` may be needed | Old inactive devices stop receiving pushes | Usually low; confirm processor retention separately |
| Exact order pickup/destination | Retained without TTL for active accounts; cleared on passenger account deletion | Proposed 30 days after completion/cancellation, subject to dispute hold | Short operational support/dispute window | Set address and coordinates to `NULL`; keep city-level/minimized history | Configurable post-trip PII cleanup job and indexes | Old trips lose exact route details | **Required** |
| `order_stops` exact location | Rows retained; address/lat/lon cleared together on either participant's account deletion | Proposed 30 days after completion/cancellation | Same as primary route location | Null exact fields; retain sequence/type/reached timestamp | Same configurable job; schema already supports null triplet | Old trip stops become non-mapable | **Required** |
| Intercity exact coordinates/comments | No TTL; cleared for the relevant user during account deletion | Proposed 30 days after trip closure or travel date for unmatched requests | Routing support with reduced long-term location/free-text exposure | Null exact coordinates, pickup address and comments; keep cities/date/seats/status/price | Configurable cleanup job for rides/bookings/requests | Historical intercity entries show city-level data only | **Required** |
| Delivery contacts/access details | No TTL; passenger deletion clears names, phones, entrance/apartment/floor/intercom/comments and replaces item description | Proposed 30 days after completion/cancellation | Delivery support and short dispute window | Null contacts/access instructions/comments; replace or classify item description without free text | Configurable cleanup job | Old delivery detail becomes limited | **Required** |
| Live driver location | Stored on order; cleared when driver deletes account, but no routine TTL | Active trip plus at most 24 hours after terminal status | Live tracking and short incident diagnosis | Null coordinates and update timestamp | Small frequent cleanup job keyed by terminal status | No impact on active navigation; old live marker disappears | Confirm 24-hour maximum |
| City/intercity chat | Author's text becomes tombstone on deletion; other messages persist indefinitely | Proposed 90 days after trip/booking closure; reported excerpts follow moderation retention | Support, dispute and safety with bounded free text | Delete text or replace with irreversible tombstone; preserve minimal metadata only if justified | Cleanup job plus legal-hold/report linkage | Old conversations become unavailable | **Required** |
| Reviews/ratings | Deleted author's comment is cleared; score and links remain; others' comments persist | Proposed free text: 1 year; minimized score: 3 years or account lifetime, whichever approved | Reputation and abuse prevention | Remove free text; retain score with pseudonymous linkage | Cleanup job; possibly separate aggregate/evidence model | Older review text disappears; rating may remain | **Required** |
| Reports and moderation evidence | Persist without TTL; deletion does not alter them | Open case until resolution, then proposed 1 year; longer only under documented hold | Safety investigation, appeals and abuse defense | Minimize narrative/identifiers after closure; retain decision code and timestamps | Moderation retention fields, hold flag, restricted cleanup job | No normal product impact | **Required** |
| Orders and prices | Minimized and PII-bearing fields persist without routine TTL; order rows survive deletion | Proposed minimized commercial history: 3 years after terminal status | Receipts, disputes, analytics and operational history | Remove exact location/free text early; retain UUID, service, status, coarse cities, price and timestamps | PII cleanup job first; final-history purge/re-key later | History remains useful but less detailed | **Required; period not final** |
| Subscription/payment references | Rows persist; active subscription is cancelled on deletion | Proposed 5 years only if counsel/accounting confirms; otherwise shortest supported period | Accounting, reconciliation and disputes | Never retain payment credentials; minimize provider reference and user linkage after approved period | Policy-driven cleanup/re-key job | No driver-access impact after expiry | **Required; do not implement yet** |
| Terms acceptance | Currently deleted with account | Proposed retain minimized terms version, acceptance timestamp and pseudonymous proof for 5 years only if counsel confirms | Evidence of consent/contract version | Remove profile data; retain minimal proof or cryptographic/pseudonymous linkage | Account-deletion behavior and schema may need change | No UI impact | **Required; current behavior conflicts** |
| Account-deletion jobs | Completed jobs retain hash/user UUID but clear raw Firebase UID; pending/failed jobs retain raw UID for retry; no TTL | Raw UID until success; operator escalation after terminal failure; proposed completed-job purge after 90 days | Idempotency and provider deletion recovery | Clear raw UID immediately on success; later delete or rotate hash/job metadata | Cleanup job, escalation monitoring and possibly separate minimal audit event | None | Confirm audit period |
| Application/proxy logs | No repository-defined rotation or TTL | Proposed 30 days normal logs; up to 90 days restricted security logs | Reliability and security investigation | Rotate/delete; redact tokens, phones, exact addresses and coordinates | Host/runtime logging configuration, not app schema alone | None | Confirm and verify host configuration |
| Database backups | Outside repository; production backup lifecycle not established here | Proposed encrypted rolling 30 days; deletion requests age out through rotation; restore runbook reapplies deletions | Disaster recovery | Expire backup sets; control and audit restore access | Infrastructure policy and restore tooling | None | **Required; VERIFY OUTSIDE REPOSITORY** |

## Preferred technical sequence after approval

1. Add configuration-only retention values with safe defaults, metrics and a dry-run
   report. Do not hard-code legal periods into scattered SQL.
2. Implement a bounded, resumable job for terminal-trip precise PII. Process
   primary locations, `order_stops`, intercity coordinates/comments, delivery
   contacts and stale live-driver location in small batches.
3. Add cleanup for revoked sessions, stale FCM tokens and completed deletion jobs.
4. Add chat/review/report cleanup only after evidence-hold rules and moderation
   access controls are approved.
5. Do not purge or re-key long-term order, payment/subscription or Terms history
   until legal/accounting approves both purpose and period.

## Configurable precise-location cleanup option

Exact geodata can currently remain indefinitely when an account remains active.
The preferred design is a scheduled job controlled by environment-backed policy
values, for example a disabled-by-default `PRECISE_TRIP_PII_RETENTION_DAYS`.
The job should select only terminal orders/rides older than the configured
cutoff, skip documented holds, clear exact fields transactionally in bounded
batches, emit aggregate counts without PII, and be idempotent. A dry-run query
and restore-tested backup are required before first activation.

## Owner/legal decisions still required

- Exact-location, delivery-detail, chat and review periods.
- Whether and how long reports under investigation override normal deletion.
- Retention of minimized orders, prices, subscription/payment references and
  Terms acceptance evidence.
- Treatment of deletion-job hashes and terminal Firebase failures.
- Production log, backup and external-processor retention.
