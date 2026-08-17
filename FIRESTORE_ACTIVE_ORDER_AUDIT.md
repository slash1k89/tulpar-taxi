# Active-order Rules audit

`active_orders/{uid}` is a private, one-document binding with `orderId`,
`role`, `status`, and `createdAt`. Active statuses are `searching`,
`accepted`, `arrived`, and `in_progress`.

- A passenger creates its binding atomically with a `searching` order.
- A driver creates its binding atomically with accepting that order.
- Driver status updates keep existing bindings' statuses in sync.
- Cancellation and completion remove the bindings in the same transaction.
- Orders from before this schema remain readable via a client-side fallback;
  they are never migrated or deleted automatically.

Attack review:

- A second order or driver acceptance is rejected by both a transaction read
  conflict and Rules requiring that no active binding currently exists.
- A forged binding cannot target another user: create is owner-only and Rules
  compare its role, order ID, and status to `getAfter(order)`.
- A binding cannot be changed to another order or role; only a driver's valid
  in-progress status transition may change its status.
- A binding cannot be removed during an active ride: deletion requires the
  related order's `getAfter()` terminal status and terminal timestamp to equal
  the current request time, so it must be part of that transition.
- Terminal order updates require both participants' bindings to be absent
  after the transaction. Existing legacy orders, which have no bindings, keep
  working without automatic mutation.

Known migration constraint:

- Firestore Rules cannot query `orders` to prove that an older unbound active
  order does not exist. The application detects these orders read-only on
  startup, but a modified legacy client could bypass that client-side check and
  create a new binding. A one-time trusted migration (Admin SDK or a future
  privileged server path) is required before Rules alone can enforce this
  invariant for pre-binding data.
