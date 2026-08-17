# Bitvavo API notes

Researched 2026-08-16. Marked **[verified]** where confirmed against a live response or two
independent official SDKs, **[unconfirmed]** otherwise. Do not treat unconfirmed items as facts.

## Base

- REST base: `https://api.bitvavo.com/v2` **[verified – live]**
- Docs: <https://docs.bitvavo.com/docs/rest-api/introduction/>
- **OpenAPI specification: <https://docs.bitvavo.com/api-specs/exchange-rest-api.yaml>** - the
  authoritative description of every response, machine-readable, with an example per field.
  Prefer it over the SDKs: the Python wrapper has no `stakingBalance` method, which once led to
  the wrong conclusion that the endpoint did not exist.
- Official SDKs: <https://github.com/bitvavo/php-bitvavo-api>,
  <https://github.com/bitvavo/python-bitvavo-api>

**There is no test environment.** The specification lists a single server,
`https://api.bitvavo.com/v2`, and the documentation contains no mention of a sandbox, testnet or
demo account. The official Postman collection needs your own key and secret. Every call is
against a real account, which is why the offline simulation exists.

The help centre is behind Cloudflare and cannot be fetched programmatically; a browser reaches
it.

## Authentication **[verified – PHP and Python SDKs agree]**

Headers on every private request:

| Header | Value |
|---|---|
| `bitvavo-access-key` | the API key |
| `bitvavo-access-signature` | see below |
| `bitvavo-access-timestamp` | milliseconds since epoch, as a string |
| `bitvavo-access-window` | milliseconds of tolerance; SDK default `10000` |
| `Content-Type` | `application/json` |
| `Accept` | `application/json` – required, and capitalised, see *Error responses* |

Signature string, concatenated with **no delimiter**:

```
timestamp + METHOD + "/v2" + path + [body]
```

- `path` is the endpoint **including its query string**, e.g. `/balance?symbol=BTC`.
- The `/v2` prefix is part of the signed string. Both SDKs prepend it explicitly.
- `body` is omitted entirely for GET (not an empty-string placeholder in the SDKs, though
  appending `""` is equivalent).
- `HMAC-SHA256(secret, string)`, **hex encoded** (PHP `hash_hmac` default, Python `hexdigest`).

In MoneyMoney terms: `MM.hmac256` returns **binary**, so the result must be hex-encoded
explicitly before it goes into the header.

Worked example from the official docs. **[verified]** – the concatenation order above reproduces
this digest exactly (`openssl dgst -sha256 -hmac`), so the signed-string construction is settled
even though a live authenticated call has not been made:

```
secret    = "bitvavo"
timestamp = 1548172481125
method    = "POST"
path      = "/v2/order"
body      = {"market":"BTC-EUR","side":"buy","price":"5000","amount":"1.23","orderType":"limit"}
=> 44d022723a20973a18f7ee97398b9fdd405d2d019c8d39e24b8cc0dcb39ca016
```

## Error responses **[verified – live]**

Failures come back as JSON with a numeric `errorCode`:

```json
{ "errorCode": 301, "error": "API Key must be of length 64." }
```

**Authentication failures use HTTP 403, not 401**, and the status alone is useless: a typo, a
missing permission and a blocked IP all produce 403. The `errorCode` in the body is what
distinguishes them.

| Code | Meaning |
|---|---|
| 105 | rate limit exceeded (HTTP 429) |
| 300 | endpoint requires authentication |
| 301 | API key has an invalid length |
| 302 | timestamp is not in milliseconds |
| 303 | `Bitvavo-Access-Window` out of range |
| 304 | request did not arrive within the access window |
| 305 | API key is not active |
| 306 | API key activation not confirmed |
| 307 | IP is not in the whitelist for this key |
| 308 | signature format is invalid |
| 309 | signature is invalid |
| 311 | key lacks the `View access` permission |

Source: <https://docs.bitvavo.com/docs/errors/>.

**Reading that body from MoneyMoney requires `Accept: application/json` on the request.** Without
it the engine terminates the script on a non-2xx status and shows its own generic error message
instead of anything the extension returns; with it, the response is handed back to the script.
Documented at <https://moneymoney.app/api/webbanking/> under `connection:request`.

**Spell the key `Accept`, not `accept`.** HTTP header names are case-insensitive on the wire and
Bitvavo answers either spelling identically, but MoneyMoney reads the header table itself to
decide whether to return the body, and that lookup is literal. A lowercase key behaves exactly
like no header at all.

## Rate limits **[verified – live response headers]**

```
bitvavo-ratelimit-limit: 1000
bitvavo-ratelimit-remaining: 999
bitvavo-ratelimit-resetat: 1786898340000   (ms epoch)
```

1000 weight per minute, and the cost differs sharply per endpoint **[verified – official docs]**:
`/balance` and `/stakingBalance` cost **5** each, `/ticker/price` and `/assets` cost **1**. Error
code `105` signals the limit was exceeded. Irrelevant in practice at three calls per refresh,
but worth knowing where the cost sits: the two balance calls, not the full asset list.

## Endpoints needed

### `GET /v2/balance` – private **[verified – live, 2026-08-16]**

Optional `symbol` param. Confirmed against a real account: a top-level **array**, three string
fields per entry, exactly as both SDKs document.

```json
[{ "symbol": "EUR", "available": "100.00", "inOrder": "0" }]
```

- Total holding = `available + inOrder`. Both are **strings**, including a plain `"0"`.
- Fiat appears here like any other asset, with `symbol: "EUR"`.
- Only assets with a balance are returned; zero balances are omitted.
- **Fixed-staking positions are not included** - they come from `GET /stakingBalance`.
- **Flex staking and lending are included.** Neither locks the asset: flex-staked crypto can be
  traded at any time, and lent crypto can be sold or withdrawn at any time, so both remain part
  of the tradable balance. Sources: <https://bitvavo.com/de/earn> and Bitvavo's help centre
  article on lending.

### `GET /v2/ticker/price` – public **[verified – live]**

```json
[{"market":"0G-EUR","price":"0.13789"},{"market":"1INCH-EUR","price":"0.071444"}]
```

- 440 markets in one call. **All prices for the whole portfolio cost a single request.**
- Quote currencies: **429 EUR, 11 USDC**, nothing else.
- `price` is a **string** – always `tonumber()`.
- **Prices carry five significant digits, not two decimals** [verified – live, 2026-08-17]. 309
  of the 440 markets show exactly five, the rest fewer because trailing zeros are dropped. At a
  Bitcoin price around 54,868 EUR that leaves no room for cents at all: `BTC-EUR` arrives as the
  plain integer `"54868"`, and the bid/ask spread of exactly 1 EUR confirms that is the tick
  size rather than rounding. `PEPE-EUR` shows the same rule from the other end, at
  `"0.0000022537"`.

  No other endpoint offers more: `/ticker/24h` and `/ticker/book` report whole euros for
  `BTC-EUR` too. So a position in MoneyMoney showing "54.849,00 €" is displaying Bitvavo's real
  precision, not a rounding this extension introduced. The effect on a valuation is negligible -
  half a euro on 54,868 is 0.0009 % - but it surprises people, which is why it is written down.

  The API has no `pricePrecision` field; all 440 entries in `/v2/markets` leave it unset.

> The specification's example for this field reads `'34,243'`, with a comma. Live responses use
> a plain decimal point (`"54821"`), so the example is a documentation error. Worth knowing what
> the extension would do if it were not: `tonumber` returns `nil` for such a string and the asset
> is listed unpriced, rather than silently valued at 34.

**No asset is priced only in USDC [verified – live, 2026-08-16].** All eleven USDC markets –
`ADA`, `BTC`, `DOGE`, `ETH`, `EURC`, `PEPE`, `SOL`, `SUI`, `TIA`, `USDCV` and `XRP` against
USDC – have an EUR market as well. They are convenience pairs for traders holding stablecoin,
not the only route to a price, so no two-hop conversion via `USDC-EUR` is required.

`USDC-EUR` does exist as a market, so that fallback is implementable and worth keeping as a
safety net should an EUR pair ever be delisted. Today it is dead code. The situation that
actually leaves an asset unpriced is a different one – see below.

This is why no third-party price source is needed. Prices come from Bitvavo itself, so there is
no symbol-mapping table that can silently value an unmapped asset at 0 - a common failure mode in
crypto extensions that source prices externally.

### `GET /v2/assets` – public **[verified – live]**

475 assets. Fields: `symbol`, `name`, `decimals`, `depositFee`, `depositConfirmations`,
`depositStatus`, `withdrawalFee`, `withdrawalMinAmount`, `withdrawalStatus`, `networks`,
`message`.

```json
{"symbol":"BTC","name":"Bitcoin","decimals":8,...}
{"symbol":"EUR","name":"Euro","decimals":2,"networks":["SEPA"],...}
```

One call gives a `symbol → name` map, so a position can show "Bitcoin" rather than "BTC".
EUR is itself an asset here.

**475 assets but only 440 markets. 45 assets have no price route to EUR at all**
**[verified – live, 2026-08-16]:** `ACA`, `AERGO`, `AR`, `ATA`, `BLAST`, `BLZ`, `CKB`, `CORE`,
`COS`, `D`, `DATA`, `DCR`, `DENT`, `DMC`, `ES`, `FLOW`, `FORTH`, `GHST`, `HIGH`, `HOOK`, `IDEX`,
`IOTX`, `JST`, `LYX`, `MBOX`, `MDT`, `MINA`, `NANO`, `NFP`, `NKN`, `OM`, `ONE`, `ORDI`, `OXT`,
`PHB`, `POLS`, `POLYX`, `PRIME`, `QTUM`, `RDNT`, `SOPH`, `SXP`, `THETA`, `TRU`, `UXLINK`.

These are delisted from trading but can still be held, so a balance in one of them is entirely
possible - and not hypothetically. Bitvavo's own list of lending-enabled assets currently
includes `TRU`, `IOTX`, `MBOX`, `BLAST`, `NKN`, `FORTH`, `GHST`, `RDNT`, `CORE`, `POLS`, `PHB`
and `COS`, every one of which has no market. Users evidently hold them. **This is the case the unpriced code path exists for.** At roughly one asset in ten it
is a normal occurrence rather than an exotic edge case, which is what makes returning no price
the right behaviour: a zero would silently understate the portfolio. The list is a snapshot and
will drift as Bitvavo lists and delists; nothing in the code depends on it.

### `GET /v2/stakingBalance` – private **[verified – live, 2026-08-17]**

Weight 5. Returns `[{ "symbol": ..., "amount": ... }]` for assets in fixed staking, which the
balance endpoint deliberately excludes: *"This request only returns assets locked in fixed
staking. To get your balance available for trading, use the Get account balance request."*

Two things the documentation does not say, both confirmed against a live account:

- **A key with `View access` alone may call it.** No extra permission is needed.
- **An account with nothing staked receives `[]` and HTTP 200**, not an error. Calling it
  unconditionally is therefore safe for users who do not stake.

A locked amount is listed as its own position rather than added to the tradable one. The total
would be right either way, but merging would hide that part of it cannot be sold.

### `GET /v2/account/history` – private **[verified – live, 2026-08-17]**

Weight 1. Returns every account event in one paginated call, which makes the separate history
endpoints largely redundant.

Parameters: `fromDate` and `toDate` (Unix milliseconds), `page`, `maxItems` (max 100), `type`.

- **`fromDate` is what keeps a refresh cheap.** Without it every refresh pages through the whole
  history, and the cost grows with the account's age: ten thousand events are a hundred requests,
  every time. With it a refresh asks only for what happened since the last one. A first sync
  still reads everything, once.
- **Do not filter by `type`.** Its enumeration is the same fourteen documented types, and a live
  account was found to return a fifteenth. Filtering server side would drop such an event where
  nothing in the response could hint that anything was missing.
- The spec documents no sort order for `items`. Observed responses are newest first, but nothing
  should depend on it - narrow the range instead of breaking out of the paging loop early.

```json
{ "items": [ ... ], "currentPage": 1, "totalPages": 2, "maxItems": 5 }
```

- **A `View access` key is enough.** Confirmed against a live account, including `buy` events.
  Bitvavo's permission note says order and trade information requires the Trade permission, but
  that applies to the order endpoints, not to this one.
- Event types documented: `sell`, `buy`, `staking`, `fixed_staking`, `deposit`, `withdrawal`,
  `affiliate`, `distribution`, `internal_transfer`, `withdrawal_cancelled`, `rebate`, `loan`,
  `external_transferred_funds`, `manually_assigned`.
- **The list is not exhaustive.** A live account returned `campaign_new_user_incentive`, which
  appears in no Bitvavo documentation. Treat the documented set as a starting point: derive an
  event's effect from its currency fields, not from a table of known types, or an unfamiliar one
  will be dropped and the balance will be wrong with nothing looking wrong.
- **Fields differ per type.** `transactionId`, `executedAt`, `type` and `address` are always
  present. A `buy` adds price, sent, received and fee fields; a `deposit` only received and fee;
  a `withdrawal` only sent and fee; a `rebate` only received, with **no fee fields at all**.
  Nothing may be assumed present.
- `executedAt` is an ISO 8601 string, while `/v2/depositHistory` reports milliseconds since
  epoch. Two time formats in one API.
- The event stream reconciles to `/v2/balance` exactly, to the cent, when every type is counted -
  including `rebate`, which is easy to overlook and was worth six cents on a nearly empty account.
- `address` names the other side of a transfer: a bank account for a fiat deposit, a wallet
  address for a crypto withdrawal. It is `null` on everything that moves nothing in or out, a
  trade included.
- **The masking differs between endpoints.** This one shortens a bank account to `DE80***00`;
  `/v2/depositHistory` returns the same field as a full IBAN. Prefer the masked value - it
  identifies the account for whoever owns it without putting an IBAN somewhere it need not be.
- Amounts come back with binary floating point artefacts (`0.00033875999999999996`). Format for
  display; never compare for equality.

This endpoint is the source for the cash account's transactions.

### `GET /v2/depositHistory` and `GET /v2/withdrawalHistory` – private, not used **[verified – live, 2026-08-17]**

Params `symbol`, `limit`, `start`, `end`. Both readable with a `View access` key.

Not used, because `/v2/account/history` already carries every event these return, and it does so
in one call rather than two. They hold two fields it lacks - `status`, and a `txId` on a crypto
withdrawal - neither of which a statement needs: an incomplete transfer has not moved the
balance yet, and a blockchain transaction id is a detail for a block explorer, not a booking.
`timestamp` here is milliseconds since epoch, where `/v2/account/history` uses ISO 8601.

## API key permissions **[verified – official docs]**

Source: <https://docs.bitvavo.com/docs/get-started/>. The help centre itself still blocks
automated fetching (HTTP 403), but the get-started page documents the creation flow in full.

Keys are created under *Settings → API tab → Add new API key*. Creating one requires 2FA to be
enabled, and the secret is displayed exactly once.

The permission checkboxes are:

| Label | Grants |
|---|---|
| **View access** | view account information, including balances and transactions |
| **Trade digital assets** | create, update and cancel orders |
| **Withdraw digital assets** | withdraw to an external address or verified bank account |
| **Include all subaccounts** | cancel orders and retrieve information for subaccounts |
| **Internal Transfer** | transfer assets between subaccounts and the main account |
| **Administrative** | create and view subaccounts |

**`View access` alone is sufficient** for this extension. Everything else must stay off.

> Inconsistency in Bitvavo's own documentation: the REST API introduction page calls the same
> permission **"Read-only"**, while the get-started page calls it **"View access"**. The
> get-started page is the one that documents the actual creation dialog, so its wording is used
> in the README, with a note covering the other.

**IP whitelisting is supported [verified]** – an *IP Whitelist* field is part of the key creation
dialog, and multiple addresses are comma-separated. Worth recommending wherever the user has a
static address.

Bitvavo documents that **withdrawals made through the API do not require 2FA or email
confirmation [verified]**. That removes the usual second line of defence, which is what makes
leaving the withdrawal right disabled a real security measure rather than mere tidiness.

## Request budget per refresh

| Call | Weight | Frequency | Purpose |
|---|---|---|---|
| `GET /v2/balance` | 5 | every refresh | tradable holdings |
| `GET /v2/stakingBalance` | 5 | every refresh | fixed-staking holdings |
| `GET /v2/ticker/price` | 1 | every refresh | all prices in one call |
| `GET /v2/assets` | 1 | once a week | symbol → display name, cached in `LocalStorage` |

**Three requests and 11 weight on a normal refresh**, four and 12 when the cached display names
expire, against a budget of 1000 per minute.

Note that `InitializeSession2` runs on every refresh cycle, not only when the account is added.
Fetching `/balance` there *and* in `RefreshAccount` would double the most expensive call in the
set, so the login check hands its response to the first refresh instead.

## Still to be verified

Everything here has been checked against the live API or the official documentation, with two
exceptions that need an account holding crypto:

- How MoneyMoney renders a position whose `price` is `nil`. The expectation is quantity without
  a value; that has not been seen on screen.
- Whether a staked amount is better merged into the asset's position or listed separately, once
  `GET /v2/stakingBalance` is used at all.

Anyone able to settle either point is welcome to open an issue.
