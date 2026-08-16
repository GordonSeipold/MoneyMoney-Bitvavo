# Bitvavo API notes

Researched 2026-08-16. Marked **[verified]** where confirmed against a live response or two
independent official SDKs, **[unconfirmed]** otherwise. Do not treat unconfirmed items as facts.

## Base

- REST base: `https://api.bitvavo.com/v2` **[verified – live]**
- Official SDKs: <https://github.com/bitvavo/php-bitvavo-api>,
  <https://github.com/bitvavo/python-bitvavo-api>
- Docs: <https://docs.bitvavo.com/docs/rest-api/introduction/>
  (the help centre is behind Cloudflare and cannot be fetched programmatically)

## Authentication **[verified – PHP and Python SDKs agree]**

Headers on every private request:

| Header | Value |
|---|---|
| `bitvavo-access-key` | the API key |
| `bitvavo-access-signature` | see below |
| `bitvavo-access-timestamp` | milliseconds since epoch, as a string |
| `bitvavo-access-window` | milliseconds of tolerance; SDK default `10000` |
| `content-type` | `application/json` |

Signature string, concatenated with **no delimiter**:

```
timestamp + METHOD + "/v2" + path + [body]
```

- `path` is the endpoint **including its query string**, e.g. `/balance?symbol=BTC`.
- The `/v2` prefix is part of the signed string. Both SDKs prepend it explicitly.
- `body` is omitted entirely for GET (not an empty-string placeholder in the SDKs, though
  appending `""` is equivalent).
- `HMAC-SHA256(secret, string)`, **hex encoded** (PHP `hash_hmac` default, Python `hexdigest`).

In MoneyMoney terms: `MM.hmac256` returns **binary**, so it must be hex-encoded explicitly –
the same `bin2hex` helper the existing Binance script uses.

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

**Authentication failures use HTTP 403, not 401.** A malformed or unknown key returns 403
(`errorCode` 301 for a wrong-length key). This matters for an extension: 403 cannot be read as
"credentials fine, permission missing", because a plain typo produces the same status. Since
MoneyMoney discards the response body along with the failed request, a 403 message has to name
every possible cause – wrong key or secret, missing `View access`, IP not whitelisted.

## Rate limits **[verified – live response headers]**

```
bitvavo-ratelimit-limit: 1000
bitvavo-ratelimit-remaining: 999
bitvavo-ratelimit-resetat: 1786898340000   (ms epoch)
```

1000 weight per minute. A simple call costs 1; `/assets` (full list) cost ~4. Error code `105`
signals the limit was exceeded. Irrelevant in practice for an extension that makes three
requests per refresh, but the headers are worth reading for a clear error message.

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
- Still open: whether **staked / earning** balances appear. The account used for verification
  held no crypto, so this is untested rather than answered.

### `GET /v2/ticker/price` – public **[verified – live]**

```json
[{"market":"0G-EUR","price":"0.13789"},{"market":"1INCH-EUR","price":"0.071444"}]
```

- 440 markets in one call. **All prices for the whole portfolio cost a single request.**
- Quote currencies: **429 EUR, 11 USDC**, nothing else.
- `price` is a **string** – always `tonumber()`.

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

One call gives a `symbol → name` map, so securities can show "Bitcoin" rather than "BTC".
EUR is itself an asset here.

**475 assets but only 440 markets. 45 assets have no price route to EUR at all**
**[verified – live, 2026-08-16]:** `ACA`, `AERGO`, `AR`, `ATA`, `BLAST`, `BLZ`, `CKB`, `CORE`,
`COS`, `D`, `DATA`, `DCR`, `DENT`, `DMC`, `ES`, `FLOW`, `FORTH`, `GHST`, `HIGH`, `HOOK`, `IDEX`,
`IOTX`, `JST`, `LYX`, `MBOX`, `MDT`, `MINA`, `NANO`, `NFP`, `NKN`, `OM`, `ONE`, `ORDI`, `OXT`,
`PHB`, `POLS`, `POLYX`, `PRIME`, `QTUM`, `RDNT`, `SOPH`, `SXP`, `THETA`, `TRU`, `UXLINK`.

These are delisted from trading but can still be held, so a balance in one of them is entirely
possible. **This is the case the unpriced code path exists for.** At roughly one asset in ten it
is a normal occurrence rather than an exotic edge case, which is what makes returning no price
the right behaviour: a zero would silently understate the portfolio. The list is a snapshot and
will drift as Bitvavo lists and delists; nothing in the code depends on it.

### Possible later additions **[unconfirmed]**

- `GET /v2/depositHistory` – params `symbol`, `limit`, `start`, `end`
- `GET /v2/withdrawalHistory` – same params

Both read-only. Only relevant if transactions are wanted alongside holdings.

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
| `GET /v2/balance` | 1 | every refresh | holdings |
| `GET /v2/ticker/price` | 1 | every refresh | all prices in one call |
| `GET /v2/assets` | ~4 | once a week | symbol → display name, cached in `LocalStorage` |

**Two requests on a normal refresh**, three when the cached display names expire, against a
budget of 1000 weight per minute. Display names change rarely, which is what makes the weekly
TTL worth the small amount of state it costs.

## Still to be verified

These need a real API key, and are not settled facts:

1. The exact `/v2/balance` response shape. Implemented against the shape both official SDKs
   document; a mismatch raises an error rather than producing wrong numbers, but it is untested.
2. Whether **staked / earning** balances appear in `/v2/balance` at all. Bitvavo offers staking,
   and the SDK surface shows no dedicated endpoint for it. If they are absent, a portfolio is
   understated with no visible sign – the most consequential open question here.

Anyone able to settle either point against an account holding crypto is welcome to open an issue.
