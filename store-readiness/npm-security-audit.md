# MEKEN backend npm security audit

Audit date: 2026-09-29

Command: `npm audit --json`

Baseline: 10 moderate, 0 high, 0 critical.

After controlled local updates: 2 moderate, 0 high, 0 critical.

`npm audit fix`, `npm audit fix --force`, broad `npm update`, production deploy,
and application-code changes were not performed.

Environment and integrity evidence:

- Node.js: `v24.14.0`; npm: `11.9.0`.
- Baseline `package.json` SHA-256:
  `4048F04E1433E203BB96F2B12AFF93D03DDAFBB433ECE4DC5E989B4E73DF2126`.
- Baseline `package-lock.json` SHA-256:
  `3983DE571BE113338D08AEB341F0822BE2306B3888EEC7E1620BFD4C9D86BC2B`.
- Final `package.json` SHA-256:
  `C023536BA768A19AB278248D6094D9877FC572632E357E059D19A74960B1B7A5`.
- Final `package-lock.json` SHA-256:
  `FA8FB97622ADAB44631100085CA67C85DB318BF38215A55FCF4FE33D2BCF81F7`.

## Executive assessment

The production request-path findings were removed locally: `qs` is now 6.16.0
and `ip-address` is now 10.7.2. Their existing parents already permitted these
versions, so no Express or rate-limit major update was needed.

`firebase-admin` was updated from 13.10.0 to 14.5.0 after verifying the Node 22
runtime requirement and modular API compatibility. The current code already
uses `firebase-admin/app`, `firebase-admin/auth`, and
`firebase-admin/messaging`; no removed namespaced API was present.

Two moderate findings remain in an optional Cloud Storage branch:
`@google-cloud/storage@8.2.0 -> gaxios@6.7.1 -> uuid@9.0.1`. MEKEN does not
import or initialize Cloud Storage. There is no published safe `gaxios` 6.7.2,
and forcing `uuid` 11+ outside the parent's declared range would be an
unsupported override. These findings are therefore documented rather than
artificially suppressed.

`npm audit` identifies `firebase-admin@14.5.0` as the supported remediation for
the Firebase chain and marks it as a SemVer-major update from installed
`13.10.0`. Registry versions below are informational; no update was performed.

## Findings

| Package | Direct? | Runtime class | Advisory / affected installed version | Fixed version or remediation | Major update? | Current use and practical exposure | Classification |
|---|---|---|---|---|---|---|---|
| `firebase-admin` 13.10.0 | Direct | Production | Aggregate moderate finding through Firestore and Storage; audit range includes 13.10.0 | `firebase-admin` 14.5.0 | Yes | Auth deletion and FCM messaging are used. Vulnerable child services are not imported, but the dependency is shipped | Should fix before release through controlled upgrade |
| `@google-cloud/firestore` 7.11.6 | Transitive via `firebase-admin` | Production-installed | Via vulnerable `google-gax`; affected through 7.11.6 | Audit remediation: `firebase-admin` 14.5.0; current registry Firestore 9.2.0 | Parent remediation is major | No Firestore import, initialization or query exists in backend source; not reachable through known request flow | Acceptable temporarily with justification |
| `@google-cloud/storage` 7.22.0 | Transitive via `firebase-admin` | Production-installed | Via `retry-request` and `teeny-request`; audit range includes 7.22.0 | Audit remediation: `firebase-admin` 14.5.0; current registry Storage 8.2.0 | Parent remediation is major | No Storage/bucket API is imported or configured; no upload path found | Acceptable temporarily with justification |
| `google-gax` 4.6.1 | Transitive via Firestore | Production-installed | Via `retry-request` and `uuid`; affected through 4.6.1 | Newer unaffected line; registry 6.9.0, delivered by parent upgrade | Yes in dependency chain | Only present behind unused Firestore client | Acceptable temporarily with justification |
| `retry-request` 7.0.2 | Transitive via Storage/Google GAX | Production-installed | Via `teeny-request`; affected 7.0.0–7.0.2 | 7.0.3+ boundary; registry 9.0.1, delivered by parent upgrade | Parent upgrade required | No application import; paths belong to unused Storage/Firestore clients | Acceptable temporarily with justification |
| `teeny-request` 9.0.0 | Transitive via Storage/retry-request | Production-installed | Via vulnerable `uuid`; affected through 9.0.0 | Newer unaffected line; registry 11.0.1, delivered by parent upgrade | Parent upgrade required | No application import; unused Storage request path | Acceptable temporarily with justification |
| `uuid` 9.0.1 | Transitive | Production-installed | GHSA-w5hq-g745-h8pq: missing buffer bounds check in v3/v5/v6 with caller-provided buffer; affected below 11.1.1 | 11.1.1+; registry 14.0.2 | Yes for direct package line; parent remediation supplied by Firebase upgrade | Application uses Node `crypto.randomUUID`, not this package. No untrusted caller-provided buffer reaches transitive UUID APIs in known flows | Acceptable temporarily with justification |
| `gaxios` 6.7.1 | Transitive via Google clients | Production-installed | Via vulnerable `uuid`; affected 6.4.0–6.7.1 | 6.7.2+ or current registry 8.1.0; audit says fix available | Potentially, depending on parent resolution | Firebase Auth/Messaging may use Google auth HTTP code, but the cited issue is UUID buffer handling and no such input path was found | Acceptable temporarily with justification |
| `ip-address` 10.5.0 | Transitive via direct `express-rate-limit` | Production | GHSA-rpw4-54j3-4h4q and GHSA-2vr4-cq9g-pvrc: incorrect IPv6 link-local/NAT64 classification; affected through 10.5.0 | 10.5.1+ boundary; registry 10.7.2; audit says fix available | No major required at package level; parent lock update must be tested | Rate limiting is on the HTTP request path. Exposure depends on production proxy IPv6 handling and trusted-IP configuration; incorrect classification could weaken an IP trust/rate-limit boundary | **Should fix before release** |
| `qs` 6.15.3 | Transitive via direct `express` and dev-only `supertest` | Production and dev | GHSA-x5fp-wj9c-mxmx array-limit bypass and GHSA-4mjr-xmp4-gh2g DoS; affected through 6.15.3 | 6.16.0 | No major required at package level; parent lock update must be tested | Express query/body parsing is reachable from public HTTP requests. Existing rate/body limits reduce impact but do not remove parser exposure | **Should fix before release** |

## Local remediation result

| Item | Before | After | Method | Result |
|---|---:|---:|---|---|
| `qs` | 6.15.3 | 6.16.0 | Targeted transitive lock update within existing Express/body-parser ranges | Both public Express and test paths resolve to 6.16.0 |
| `ip-address` | 10.5.0 | 10.7.2 | Targeted transitive lock update within `express-rate-limit` range | Rate-limit dependency resolves to 10.7.2 |
| `firebase-admin` | 13.10.0 | 14.5.0 | Controlled direct major update | Auth, Messaging, credential and deletion targeted tests passed without JS changes |
| Audit count | 10 moderate | 2 moderate | No force/override | Eight package findings removed |

## Test evidence

- HTTP/API targeted suite: 84/84 passed, including malformed JSON, body size,
  CORS, proxy handling, rate limiting, public routes, geocoding and routing.
- Firebase/FCM/account-deletion targeted suite: 76/76 passed.
- Full backend suite: 419/427 passed. The same eight failures reproduce when
  only `test/otp-service.test.js` and `test/hardening-1b.test.js` are run:
  six stale OTP in-memory SQL matchers do not recognize the current
  `purpose/method` query, and two pre-existing post-commit hardening scenarios
  expect HTTP 200 but receive 500. These files and production JS were not
  changed by this dependency task.

## Release decision

- **Release blocker from the dependency changes:** none demonstrated.
- **Resolved applicable runtime risks:** `qs` and `ip-address`.
- **Resolved Firebase aggregate chain:** eight baseline findings were removed
  by `firebase-admin` 14.5.0.
- **Temporarily acceptable:** the two remaining `gaxios`/`uuid` findings only
  while Cloud Storage stays unused and no unsupported override is introduced.
- **Separate existing test debt:** the eight full-suite failures should be
  reconciled before treating the entire backend suite as green, even though
  they are outside the dependency-update scope.

## Required follow-up (not performed in this task)

1. Do not force `uuid` 11+ into the optional Storage dependency tree. Recheck
   after a supported `@google-cloud/storage`/Firebase Admin release changes its
   `gaxios` major.
2. Keep Cloud Storage uninitialized unless this audit is revisited.
3. Reconcile the eight existing OTP/hardening test failures in a separate task.
4. Before any production deployment, build the normal candidate image and run
   the established isolated health/Auth/FCM/account-deletion smoke process.
