# MoneyMoney Extension for {{SERVICE}}

Unofficial [MoneyMoney](https://moneymoney.app) extension that fetches {{WHAT_IT_FETCHES}} from
[{{SERVICE}}]({{SERVICE_URL}}) and shows them {{HOW_PRESENTED}}.

> Not affiliated with or endorsed by {{SERVICE}} or MoneyMoney.

## What it does

- {{FEATURE}}

### Limitations

- {{LIMITATION}}

## Requirements

- MoneyMoney 2.4 or newer
- A {{SERVICE}} account with an API key that has **read permission only**

## Setup

### 1. Create a read-only API key

{{STEP_BY_STEP_KEY_CREATION}}

**Enable only the minimum permission: `{{MINIMUM_PERMISSION}}`.**
Do **not** enable trading, withdrawal or transfer rights. This extension never writes to your
account, so those rights would add risk without adding function.

{{IP_ALLOWLIST_NOTE}}

### 2. Install the extension

**Signed (recommended, once available):** download from
<https://moneymoney.app/extensions/> and drop the file into MoneyMoney's `Extensions` folder
(*Help → Show Database in Finder*).

**Unsigned, from this repository:**

1. Download `{{SERVICE}}.lua` from the [latest release](../../releases/latest).
2. *Help → Show Database in Finder*, then move the file into `Extensions`.
3. *MoneyMoney → Settings → Extensions* → uncheck **Verify digital signature of extensions**.
   On the App Store build this may require the beta channel.
4. Restart MoneyMoney.

### 3. Add the account

*Account → Add Account → Other → {{SERVICE}}*, then enter:

| Field | Value |
|---|---|
| {{FIELD_1}} | {{FIELD_1_DESC}} |
| {{FIELD_2}} | {{FIELD_2_DESC}} |

## Security

- Read-only: the extension issues read requests only. `POST` is used solely for authentication.
- Your API key and secret stay in MoneyMoney's encrypted database. They are sent only to
  {{SERVICE}}, in request headers, never in a URL.
- Nothing is logged, cached or transmitted anywhere else.

## Development

```bash
make check     # syntax, encoding, indentation and secret checks
make install   # copy into MoneyMoney's Extensions folder
```

## Note on development

Parts of this extension were written or reviewed with AI assistance. All code has been reviewed
and tested by the author before release.

## License

MIT - see [LICENSE](LICENSE).
