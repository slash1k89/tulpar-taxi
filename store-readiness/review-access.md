# Store reviewer access

No credentials are stored in Git. Put the four values below only in the private
Google Play or App Store review fields (or an approved secrets manager):

- `<REVIEW_PASSENGER_PHONE>`
- `<REVIEW_PASSENGER_PASSWORD>`
- `<REVIEW_DRIVER_PHONE>`
- `<REVIEW_DRIVER_PASSWORD>`

Provision the two new accounts from a trusted backend workstation with
`backend/scripts/provision-review-accounts.js`. Phones and passwords are read
from runtime environment variables; the script bypasses Flash Call only during
trusted provisioning and creates normal phone/password identities. It refuses
to replace an existing phone identity. The driver receives an approved profile,
agreement 1.0, test vehicle, and selected work city. The existing free-access
policy grants every approved driver access; the reviewer receives no exemption,
moderation, or other administrative role. Do not run this script
until the final non-personal phone numbers and test vehicle are approved.

## Passenger review steps

1. Open MEKEN and choose RU, ҚАЗ, or EN if desired.
2. Enter `<REVIEW_PASSENGER_PHONE>` and `<REVIEW_PASSENGER_PASSWORD>`, then tap
   Sign in. No Flash Call is required for this prepared account.
3. Read and accept Terms 1.0 when the normal first-login screen appears.
4. Select a supported city. Open City Taxi, choose pickup and destination,
   optionally add stops, enter a price, and create an order.
5. Delivery is available from the menu. Intercity has a separate search and
   booking flow.
6. Profile and settings contains account deletion. The About and support page
   links to Privacy, Terms, and the public account-deletion instructions.

## Driver review steps

1. Sign out from the passenger account.
2. Enter `<REVIEW_DRIVER_PHONE>` and `<REVIEW_DRIVER_PASSWORD>`, then tap Sign
   in. No Flash Call, payment, or manual approval is required.
3. Read and accept Terms 1.0 when the normal first-login screen appears.
4. Switch to Driver mode. The profile is already approved for the selected work
   city and the fictional test vehicle is populated.
5. City and delivery orders for that city appear on the driver screen. Accept
   an order or make a counter-offer, then open navigation.
6. Chat is available to both participants; use only the two review accounts.
7. In Intercity, the driver can create a ride and the passenger can search and
   book it. Use only fictional pickup/contact data.

## Before submission

Verify both credentials, refresh/logout/login, city scope, order acceptance,
chat, account deletion, and public legal URLs in the exact release environment.
Copy credentials only to the private store console. Do not expose database,
Firebase, moderation, or server credentials in review notes.
