# MoneyMoney Extension for Bitvavo

*Einrichtung auf Deutsch: [README.de.md](README.de.md)*

Unofficial [MoneyMoney](https://moneymoney.app) extension that fetches your balances from
[Bitvavo](https://bitvavo.com) and shows them as a securities portfolio valued in EUR.

> Not affiliated with or endorsed by Bitvavo or MoneyMoney.

## What it does

- Lists every asset you hold as a position, using the asset's full name ("Bitcoin", not "BTC")
- Values each position with Bitvavo's own market price, so there is no external price service
  and no symbol mapping table that could silently value an asset at zero
- Includes balances reserved in open orders, not just freely available ones
- Shows your EUR cash as a position too, so the portfolio total is complete
- Two requests per refresh; the asset name list is cached for a week

### Limitations

- **Holdings only.** Deposits, withdrawals and trades are not imported.
- **Staked or earning balances may not be included.** Whether Bitvavo reports these through the
  balance endpoint is not yet confirmed. Compare the total against the Bitvavo app on first use.
- **Around 45 of Bitvavo's 475 assets are delisted from trading and have no price.** You can
  still hold them, and if you do they are listed with their quantity but no value, rather than
  at a made-up price. The protocol window names any asset this affects, so a position never
  disappears silently.

## Requirements

- **Tested with MoneyMoney 2.5.1 on macOS 26.5.2.** Earlier versions are untested rather than
  known to be unsupported – if it works for you on an older one, please open an issue saying so.
- A Bitvavo account with an API key that has **read permission only**

## Setup

### 1. Create a read-only API key

You need two-factor authentication enabled on your Bitvavo account before you can create a key.

1. Log in at [bitvavo.com](https://bitvavo.com/).
2. Under your account, select **Settings**.
3. Open the **API** tab and select **Add new API key**.
4. Enter a **Name** for the key, for example `MoneyMoney`.
5. Under **IP Whitelist**, enter the IP address this Mac makes requests from. See the note below.
6. Tick **View access** and nothing else.
7. Enter your **2FA** code and select **Confirm**.
8. Copy the key and the secret straight into MoneyMoney. **Bitvavo shows the secret once and
   cannot show it again.**

**Enable only `View access`** – "view account information, including balances and transactions".
Leave **Trade digital assets**, **Withdraw digital assets**, **Internal Transfer** and
**Administrative** switched off. This extension only ever reads, so those rights would add risk
without adding function.

> Parts of Bitvavo's documentation call this permission "Read-only" rather than "View access".
> If the wording in your account differs, tick whichever single permission grants read access.

Withdrawal rights matter more here than on most exchanges. Bitvavo documents that withdrawals
made through the API **do not require 2FA or email confirmation** – so a key with that right,
if leaked, is a drained account with nothing standing in the way.

**On the IP whitelist:** a key restricted to one IP address is useless to anyone who steals it,
which is the single most effective thing you can do here. It only works if your connection has a
static IP; on a normal consumer line the address changes and the key stops working until you
update it. Multiple addresses are separated by commas. If you can't use a static IP, leaving the
field empty works – but then the key's safety rests entirely on it never leaking.

### 2. Install the extension

**Signed (recommended, once available):** download from
<https://moneymoney.app/extensions/> and drop the file into MoneyMoney's `Extensions` folder
(*Help → Show Database in Finder*).

**Unsigned, from this repository:**

1. Download `Bitvavo.lua` from the [latest release](../../releases/latest).
2. *Help → Show Database in Finder*, then move the file into `Extensions`.
3. *MoneyMoney → Settings → Extensions* → uncheck **Verify digital signature of extensions**.
   On the App Store build this may require the beta channel.
4. Restart MoneyMoney.

### 3. Add the account

*Account → Add Account → Other → Bitvavo*, then enter:

| Field | Value |
|---|---|
| User name | Your Bitvavo **API key** |
| Password | Your Bitvavo **API secret** |

MoneyMoney does not let an extension rename these two fields, so they keep their standard
labels. The key goes in the upper field, the secret in the lower one. Tick **Save password**,
otherwise you are asked for the 64-character secret on every refresh.

On the first connection MoneyMoney asks you to confirm the SSL certificate for
`api.bitvavo.com`. That is normal for a host it has not seen before.

### If setup fails

MoneyMoney reports every rejected request as *"Der Server Ihrer Bank meldet einen internen
Fehler"* / *"The server of your bank reported an internal error"*, whatever the real cause was.
The extension cannot replace that text – MoneyMoney stops the script before it can say anything.

So if you see it, work through these in order:

1. **Key and secret the right way round?** The user name field takes the key, the password field
   the secret. A wrong-length key is caught with a proper message; a wrong secret is not.
2. **Is `View access` enabled** on the key?
3. **Did your IP address change** since you created the key? A whitelisted key stops working the
   moment your connection gets a new address. This is the most common cause of a setup that
   worked yesterday and fails today.
4. **Has the key been revoked or expired?**

The protocol window (*Window → Protocol*) shows the number of characters received in each field,
which usually settles cause 1 immediately.

## Security

- Read-only: the extension issues read requests only. It never places an order, moves funds or
  changes a setting.
- Your API key and secret stay in MoneyMoney's encrypted database. They are sent only to
  Bitvavo, in request headers, never in a URL or query string.
- Nothing is logged, cached or transmitted anywhere else. The only cached data is the public
  list of asset display names.

## Development

```bash
make check     # syntax, encoding, indentation and secret checks
make install   # copy into MoneyMoney's Extensions folder
```

API details, including what is verified and what is not, are in
[`docs/api-notes.md`](docs/api-notes.md).

## Note on development

Parts of this extension were written or reviewed with AI assistance. All code has been reviewed
and tested by the author before release.

## License

MIT - see [LICENSE](LICENSE).
