# Razorpay payments and resident benefits

Provider selected by Rakesh · 2026-09-16 · decisions applied 2026-09-18 ·
[Economy](../../gameplay/ECONOMY.md)

**Use Razorpay for real-money purchases and recurring service plans.** This
supersedes the earlier GitHub Sponsors-first recommendation. The merchant
account, enabled products, supported payment methods/currencies and existing
integration have not been inspected. Selecting a provider is not a deployment
or confirmation that every desired payment flow is enabled for SJL.

## What changed on 2026-09-18

Three decisions widen what this plan has to cover. Credits can be bought with
real money (RD07); credits buy real things, including compute and storage
(RD08); and the product is global (RD11). Razorpay stays Rakesh's selected
provider. Stated plainly, the following are **unverified**:

- **Global coverage.** Whether Razorpay can accept payments from the
  countries, currencies and payment methods a global audience will use, and
  settle them to an Indian merchant, has not been checked against current
  provider documentation or the account's enabled products.
- **Purchasable credits and virtual goods.** Since this section was written,
  the [payments research](../../research/PAYMENTS_AND_CREDITS.md) found the
  relevant clause and it is not a neutral one. Razorpay's published terms
  list, among prohibited activities, "credits that can be monetized, re-sold
  or converted to physical or digital goods or services or otherwise exit the
  virtual world", with suspension of settlement as a remedy. Read literally
  that describes credits bought with money (RD07) that buy compute and
  storage (RD08). The clause may instead be aimed at crypto and cash-out, or
  may turn on what a credit redeems for. **Only Razorpay can say which
  reading applies**, so put the question to them in writing before any
  integration work; the research drafts it. Until then, treat the provider
  and the credit design as one coupled decision rather than two.
- **Tax handling.** How GST on domestic sales, export-of-services treatment,
  and VAT/sales tax in buyers' countries are collected and reported is not
  handled by a payment gateway alone and has not been designed.

A **merchant of record** or a **second provider** may be needed for a global
product: a merchant of record takes on buyer-country tax and compliance, and
a second provider covers markets or methods the first cannot. Neither is
proposed here as a decision. The research is in
[payments and credits](../../research/PAYMENTS_AND_CREDITS.md) and
[legal and compliance](../../research/LEGAL_COMPLIANCE.md).

Consequences for the rest of this plan:

- The offer table gains **credit packs**: a verified capture adds purchased
  credits to a city account's ledger balance, tracked separately from earned
  credits (RD07 leaves earned versus purchased balances open).
- Because credits meter real compute and storage, a refund of a credit pack
  must account for credits already spent on metered use; the ledger,
  metering and quota systems are coupled (see the
  [storage consequence](../../architecture/STORAGE.md#credits-meter-real-storage-and-compute)).
- A one-time residency purchase (RD09) and sponsorship (RD10) are distinct
  offers with different tax and refund character.
- Currency, price display, invoicing language and time zones are per market
  (RD11). Nothing below has been re-derived for a non-Indian buyer.

Agent tooling research found an official [Razorpay CLI](https://github.com/razorpay/razorpay-cli)
and [MCP server](https://github.com/razorpay/razorpay-mcp-server). These are
development/reconciliation candidates, not the runtime fulfilment architecture.
Evaluate them with test credentials and scoped/read-only capabilities first;
any live mutation requires its own authorised workflow. Neither interface
allows a builder agent to grant residency or change JC by bypassing city rules.
See the [tool evidence catalogue](../../research/TOOL_AUTOMATION.md). No account
connection, tool installation or provider transaction was performed in that audit.

## Map offers to benefits

| Offer | Intended payment flow | Result after verified payment |
| --- | --- | --- |
| One-time residency purchase (RD09) | Server-created order and checkout | One residency qualification with a unique block/plot claim; hosting period and what the price includes are open |
| Sponsorship of the lab (RD10) | Order or subscription for a named sponsorship offer | Sponsorship record; residency and other perks only if the offer says so |
| Credit pack (RD07, RD08) | Server-created order for a versioned pack of credits | Purchased credits posted to the account's ledger balance once, keyed by payment ID; provider policy on prepaid credits unverified |
| One-time lifestyle package | Order and checkout for a specific versioned package | Lasting unlock and advertised included construction; no duplicate grant |
| Ongoing resident service plan | Explicitly authorized subscription | Period-scoped voice/tutor/hosting allowances |
| Single activity or event | Order linked to a capacity reservation | One booking/ticket, or a documented refund/rebooking path |
| Facility sponsorship | Order or subscription tied to an approved campaign | Actual operating allocation; separately reviewed city project/unlock |
| Credit spending, taxes and simulation bills | City ledger only | No Razorpay call; spending purchased or earned credits on compute, storage, items or access is a ledger posting, never a provider transaction |

Use exact currency and integer minor-unit amounts on real-money offers. Never
interpret `800 JC` as `800` units of a real currency. Keep payment fees, refunds,
provider settlement and allocation records separate from a virtual treasury.
A captured customer payment and money arriving in the lab's bank account are
different events. Do not allocate the entire gross receipt as spendable hosting
budget without accounting for the actual financial records.

## Browser and native entry

The city backend creates a purchase intent tied to an authenticated city account,
offer version and permitted amount. A registered account can purchase its first
residency offer or a credit pack; existing residency is not a checkout
prerequisite. An anonymous visitor cannot buy anything: purchasing starts at a
registered account (RD03, RD04). Check each offer's eligibility separately
and bind its intent to
the account before opening checkout. Browser checkout receives only the public
integration fields; API secrets remain on the backend. For the first native
client, open a first-party HTTPS checkout page in the system browser and poll
the authenticated city purchase status on return. This is our architecture
proposal, not a claim that Razorpay provides a Godot or Bevy SDK.

An expiring handoff reference identifies the intent but never authorizes a
different account's purchase. Bind checkout to the account, require re-entry
when the browser session belongs to someone else, and never put hub tokens in
URLs. Closing the native app must not lose a confirmed purchase. Deep-link
return is a convenience; the server remains the source of entitlement state.

## One-time payment verification

Create the order on the server and persist its binding to the purchase intent.
Verify Checkout's response signature server-side against the stored order ID
and returned payment ID. Check the provider's payment state: authorization
alone is insufficient; fulfil on verified capture. Confirm matching amount,
currency and order association as well as the signature. Razorpay documents
the order/signature/capture flow in
[Standard Checkout integration](https://razorpay.com/docs/payments/payment-gateway/web-integration/standard/integration-steps/).

Signature validity does not establish which account owns the purchase intent. Never
trust a client-supplied account, amount, tier, order association or success flag.
Both immediate API verification and later webhooks enter the same fulfilment
transaction, keyed by provider payment ID and purchase intent.

Track `draft → awaiting_payment → authorized → captured → fulfilled` with
explicit failed/expired states and separate refund/dispute records. Capture
timing/settings need a verified account configuration before integration tests;
do not assume authorization reserves the benefit indefinitely.

## Webhooks, retries and recovery

Verify `X-Razorpay-Signature` against the **raw body** with the webhook secret.
Deduplicate delivery using `x-razorpay-event-id`; additionally deduplicate the
underlying payment/period/benefit because different events may describe the
same purchase. Delivery ordering is not guaranteed. These requirements come
from [Razorpay webhook validation](https://razorpay.com/docs/webhooks/validate-test/).

Persist verified events durably before acknowledgement, then process through
an inbox/outbox. Reconcile uncertain state through provider reads. Store prior
webhook-secret versions for deliveries created before a rotation, following
the provider's guidance; do not print the secrets or raw private payloads.

Do not assume a Stripe-style idempotency header exists on every Razorpay API.
Choose retry behavior per documented endpoint. Refund requests support
[`X-Refund-Idempotency`](https://razorpay.com/docs/api/refunds/normal-refunds-idempotent/?preferred-country=IN);
reuse the same key and request body for the same refund operation. A local unique intent prevents
concurrent creation, but an HTTP timeout can still leave a remote order or
refund created. Record the unknown result, reconcile provider objects before
retrying, and permit at most one fulfilment of the business intent. If duplicate
captured payments occur, queue the surplus for reviewed refund instead of
creating duplicate plots or doubling an allowance.

## Recurring allowances

Razorpay Subscriptions uses plans and billing cycles. Its lifecycle includes
authentication, charging, pending/halted states and cancellation; see
[subscription states](https://razorpay.com/docs/payments/subscriptions/states/)
and [subscription events](https://razorpay.com/docs/webhooks/subscriptions/).
Build a dedicated subscription adapter; its checkout verification differs
from a one-time order and must use the documented subscription flow in
[the integration guide](https://razorpay.com/docs/payments/subscriptions/integration-guide/).

Authentication or creation alone does not grant unlimited paid months. Map a
confirmed charge and covered period to exactly one service entitlement.
Prorations, upgrades, future changes, cancellation timing and included quotas
must be stated by the offer and tested against account capabilities. A failed
renewal cannot cause the same period to be granted again on every retry.

Default proposal: preserve earned homes/cosmetics, show service expiry and a
defined grace period, then stop new costly work beyond that entitlement.
Cancellation must not erase the already-paid period by guessing an end date
from webhook arrival. Reconcile provider period data; refunds and disputes are
separate corrections. Renewals are real billing periods, not simulation ticks.

## Booking compensation and refunds

A paid booking needs both funding and actual capacity. Set a bounded hold
while checkout is pending. If payment succeeds after the slot has expired,
offer the declared alternative or start a recorded refund; never oversell the
slot or silently replace it with store credit.

Maintain refund request, provider refund ID, amount and processing outcome.
An accepted API request is not proof the customer received the refund. Support
partial refunds by reference to the original payment and affected benefits,
with cumulative refunds bounded by captured value. Use the provider's
[refund API documentation](https://razorpay.com/docs/api/refunds/create-normal/) when
implementing and verifying these transitions.

Append compensating entries, correct unused benefits and preserve saved home
designs. A recurring plan cancellation, payment refund and charge dispute are
different operations. Confirm each operation's intent before calling a live
API; a simulation reset or replay can perform none of them.

## Implementation and validation

1. Implement `purchase_intents`, provider object bindings, inbox/outbox,
   fulfilment grants and period entitlements in the city service. Use stable
   city IDs independent of GitHub handles or AgentPod operator credentials.
2. Define offers and account capabilities, then rehearse with Razorpay Test
   Mode: a free account's first residency grant, one upgrade, one capacity-limited activity and one
   recurring allowance. Test and live records/keys must remain separated.
3. Exercise signature failure, mismatched order/amount/currency, multiple
   attempts, concurrent fulfilment, delayed capture, missing/reordered webhook,
   failed renewal, cancellation, partial refund and expired booking holds.
4. Demonstrate restart/reconciliation without duplicate benefits or charges;
   verify that a user cannot claim another account's intent. A no-cash game
   purchase and every simulation replay must make zero payment API calls.
5. Only offer benefits once delivery, support, terms, measured cost and payment
   recovery work. Real prices and service limits remain unset by this plan.

6. Before any live credit-pack offer, confirm the provider's policy on
   prepaid credits and virtual goods, the countries and currencies the account
   can accept, and the tax treatment per market; decide whether a merchant of
   record or second provider is needed (RD07, RD08, RD11).

The provider sources were reviewed September 16, 2026, and were not
re-checked on 2026-09-18. No Razorpay dashboard, account credentials, orders,
subscriptions, live payments or refunds were accessed or changed in this work.
