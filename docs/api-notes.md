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

Worked example from the official docs, useful as a unit check:

```
secret    = "bitvavo"
timestamp = 1548172481125
method    = "POST"
path      = "/v2/order"
body      = {"market":"BTC-EUR","side":"buy","price":"5000","amount":"1.23","orderType":"limit"}
=> 44d022723a20973a18f7ee97398b9fdd405d2d019c8d39e24b8cc0dcb39ca016
```

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

### `GET /v2/balance` – private **[unconfirmed – requires a key]**

Optional `symbol` param. Per the SDKs the response is:

```json
[{ "symbol": "BTC", "available": "1.57593193", "inOrder": "0.74832374" }]
```

Total holding = `available + inOrder`. **Must be confirmed against a real response**, in
particular whether staked/earning balances appear here at all – see open questions.

### `GET /v2/ticker/price` – public **[verified – live]**

```json
[{"market":"0G-EUR","price":"0.13789"},{"market":"1INCH-EUR","price":"0.071444"}]
```

- 440 markets in one call. **All prices for the whole portfolio cost a single request.**
- Quote currencies: **429 EUR, 11 USDC**. Nearly everything prices directly in EUR; an asset
  quoted only in USDC needs a second hop via `USDC-EUR`.
- `price` is a **string** – always `tonumber()`.

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
EUR is itself an asset here. Note 475 assets vs 440 markets: some have no tradable market.

### Possible later additions **[unconfirmed]**

- `GET /v2/depositHistory` – params `symbol`, `limit`, `start`, `end`
- `GET /v2/withdrawalHistory` – same params

Both read-only. Only relevant if transactions are wanted alongside holdings.

## API key permissions **[unconfirmed – must be read off the real UI]**

Secondary sources list **View**, **Trade** and **Withdraw**, with wording suggesting a separate
read-only toggle. The exact labels could not be verified: the Bitvavo help centre blocks
automated fetching.

The minimum needed is the permission covering balance retrieval. Trading and withdrawal rights
are not required by this extension and must stay off.

Bitvavo supports **IP whitelisting** on keys **[unconfirmed]** – worth recommending in the README
if present. Note that API withdrawals reportedly bypass 2FA and email confirmation, which makes
leaving the withdrawal right disabled genuinely important, not merely tidy.

## Planned request budget per refresh

| Call | Weight | Purpose |
|---|---|---|
| `GET /v2/balance` | 1 | holdings |
| `GET /v2/ticker/price` | 1 | all prices, one call |
| `GET /v2/assets` | ~4 | symbol → display name (cacheable via `LocalStorage`) |

Three requests against a budget of 1000 per minute.

## Still to be verified

These need a real API key or the live account UI, and are not settled facts:

1. The exact `/v2/balance` response shape.
2. Whether **staked / earning** balances appear in `/v2/balance` at all. Bitvavo offers staking,
   and the SDK surface shows no dedicated endpoint for it.
3. The exact wording of the API key permission labels in the Bitvavo UI.
4. Whether Bitvavo offers IP whitelisting on API keys.
