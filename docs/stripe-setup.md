# Stripe Setup

Direct-download subscriptions use a Stripe **Checkout Session created server-side**
by the Cloudflare Pages Function at `/api/stripe/*`. There is no Payment Link:
only a server-created Checkout Session can stamp this Mac's `instance_id` into the
session and subscription metadata, which `activate` later verifies. A Payment Link
cannot carry per-request metadata, so a link-based checkout could never satisfy
that binding.

## Cloudflare environment

Set these as secrets on the Cloudflare Pages project
(`wrangler pages secret put …`):

- `STRIPE_SECRET_KEY`: a restricted (or secret) key with:
  - **Checkout Sessions — write** (create) and read,
  - **Subscriptions — read**,
  - **Customer portal — write** (create sessions).
- `STRIPE_PRICE_ID`: the recurring price for Unlimited Dictation (under product
  `prod_UiOOOGUtAsNHhA`). Required — the server creates the Checkout Session from it.
- `STRIPE_PRODUCT_ID`: `prod_UiOOOGUtAsNHhA`.
- `ENTITLEMENT_SIGNING_SECRET`: a long random secret used to sign VTT entitlement
  tokens.

`PUBLIC_BASE_URL` (`https://vtt.the-ihor.com`) is a plain var already set in
`wrangler.toml` — do not also add it as a secret.

## Checkout flow

1. The app POSTs `/api/stripe/checkout` with its `instance_id`. The function
   creates a subscription Checkout Session for `STRIPE_PRICE_ID`, stamping
   `metadata[instance_id]` (and the same on the subscription via
   `subscription_data[metadata]`), and sets the success redirect to
   `…/stripe-success.html?session_id={CHECKOUT_SESSION_ID}`.
2. The success page shows the `cs_…` Checkout Session ID. The user pastes it into
   VTT → Settings → Subscription, and the app exchanges it at
   `/api/stripe/activate` for a signed entitlement token bound to this Mac.

`activate` validates that the session's `metadata.instance_id` matches this Mac
and that the resulting subscription has an active item whose `price.product` is
`prod_UiOOOGUtAsNHhA`, so future price changes under the same product do not
require an app update.

## Customer Portal

`portal` creates a Stripe Billing Portal session for cancellation and billing
management. Enable and configure the Customer Portal once in the Stripe Dashboard
(Settings → Billing → Customer portal) or these calls will fail.

## Recovery (reinstall / new Mac)

If a user wipes their Keychain or moves to a new Mac, their `instance_id` changes,
so the old token and the original `cs_` code stop working. They recover with their
**Stripe customer ID** (`cus_…`), which acts as a support-issued license key:

- The user enters it in VTT → Settings → Subscription → "Reinstalled or on a new
  Mac?". The app calls `/api/stripe/recover`, which mints a fresh token bound to
  the new Mac **only if** that customer has an active VTT subscription.
- Users don't normally know their `cus_…`. Look it up in the Stripe Dashboard
  (search by email, name, or card) and send it to the verified account owner.
  Treat it like a license key — anyone who has it can activate on a Mac (the
  subscription must be active), so only hand it to the real customer.
