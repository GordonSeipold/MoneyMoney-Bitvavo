-- Unofficial Bitvavo Extension (https://bitvavo.com) for MoneyMoney
-- Fetches the crypto holdings and the EUR cash balance from a Bitvavo account.
--
-- Two accounts, because the two halves want different things from MoneyMoney. MoneyMoney has no
-- account type for crypto, so the holdings appear as a portfolio, priced in EUR. The EUR cash
-- sits in a giro account, where it can carry the transactions that a portfolio cannot show.
--
-- Covers everything the API exposes as a holding: available, bound in open orders, and fixed
-- staking. Flex staking needs no special handling - those assets stay tradable and are part of
-- the ordinary balance.
--
-- Data sources:
--   https://api.bitvavo.com/v2  - balances (private), market prices and asset names (public)
--
-- Credentials:
--   User name  - Bitvavo API key, needs the "View access" permission only
--   Password   - Bitvavo API secret
--
-- Required API key permissions: "View access" only  (no trade, no withdraw, no transfer)
--
-- Tested with: MoneyMoney 2.5.1 (build 516) on macOS 26.5.2
--
-- MIT License
-- Copyright (c) 2026 Gordon Seipold
-- https://github.com/GordonSeipold/MoneyMoney-Bitvavo

local BANK_CODE  = "Bitvavo"

-- The portfolio keeps the number it has always had: changing it would orphan the account and
-- its history in an existing MoneyMoney database. The cash account is new and gets its own.
local PORTFOLIO_ACCOUNT = "Bitvavo"
local CASH_ACCOUNT      = "Bitvavo-EUR"
local API_HOST   = "https://api.bitvavo.com"
local API_PREFIX = "/v2"

-- Milliseconds of clock skew Bitvavo accepts on a signed request. Official SDK default.
local ACCESS_WINDOW = "10000"

-- Display names change rarely, so one /assets call a week is plenty. The saving is a request,
-- not weight: /assets costs 1 rate-limit point of 1000 per minute. Caching keeps a normal
-- refresh at three calls - /balance (5 points), /stakingBalance (5) and /ticker/price (1).
local ASSET_NAME_TTL = 7 * 24 * 60 * 60

WebBanking{
  -- MAJOR.NN, two decimals - the resolution MoneyMoney prints in the protocol window. 1.00 is
  -- the first published release; every change after it increments the last position.
  version  = 1.10,
  url      = "https://bitvavo.com",
  services = { BANK_CODE },
  -- Observed on the account dialog: MoneyMoney displays none of this, and offers no way to
  -- rename the credential fields either. Which value belongs in which field can therefore only
  -- be said in the README and in the header of this file.
  description = string.format(MM.localizeText("Fetch balances from %s"), BANK_CODE)
}

local apiKey
local apiSecret
local connection

-- The /balance response from the login check, kept for the whole session.
--
-- MoneyMoney runs InitializeSession2 once per refresh cycle and then RefreshAccount once per
-- account - twice here, for the portfolio and for the cash account. Both need the same balance,
-- and it is the most expensive call in the set at 5 rate-limit points. Session-scoped is
-- therefore right: fresh every cycle, fetched once within it.
local sessionBalances


function SupportsBank (protocol, bankCode)
  return protocol == ProtocolWebBanking and bankCode == BANK_CODE
end

-- MM.hmac256 returns raw bytes. Bitvavo expects the signature hex encoded.
local function bin2hex (s)
  return (s:gsub(".", function (byte)
    return string.format("%02x", string.byte(byte))
  end))
end

-- A credential pasted from a password manager or a web page routinely carries a trailing
-- space or newline. It would be signed and sent verbatim and rejected, with nothing on screen
-- to suggest why.
local function trim (s)
  return (string.gsub(s, "^%s*(.-)%s*$", "%1"))
end

-- Bitvavo names the exact cause in the response body. Setting Accept: application/json is what
-- makes that body reach us at all: MoneyMoney otherwise terminates the script on a non-2xx
-- status and shows its own generic message instead. The API docs state it plainly - "Dann wird
-- auch bei einem HTTP-Fehler die Serverantwort im Skript zurückgegeben."
--
-- These strings are shown to the user in MoneyMoney, so they are German, like the README.
local ERROR_ADVICE = {
  [105] = "Bitvavo hat wegen zu vieler Anfragen vorübergehend gesperrt. Warten Sie eine Minute.",
  [301] = "Der API-Schlüssel hat nicht die erwartete Länge von 64 Zeichen. In das Feld " ..
          "Benutzername gehört der Schlüssel, in das Feld Passwort das Secret.",
  [304] = "Die Anfrage kam zu spät bei Bitvavo an. Prüfen Sie, ob die Uhr dieses Macs richtig geht.",
  [305] = "Der API-Schlüssel ist nicht aktiv - widerrufen, abgelaufen oder gelöscht.",
  [307] = "Die IP-Adresse dieses Macs steht nicht auf der Whitelist des Schlüssels. Passen Sie " ..
          "sie bei Bitvavo unter Einstellungen, API an - oder lassen Sie das Feld leer.",
  [309] = "Die Signatur der Anfrage ist ungültig. Meist ist das Secret falsch oder unvollständig " ..
          "im Feld Passwort eingetragen.",
  [311] = "Dem API-Schlüssel fehlt die Berechtigung \"View access\". Aktivieren Sie sie bei " ..
          "Bitvavo unter Einstellungen, API."
}

-- Bitvavo's own message is shown unless translating it adds something the user can act on.
-- "Your signature is invalid" is the case that justifies the table at all: it is accurate and
-- useless, because Bitvavo cannot know that the secret goes in a field MoneyMoney labels
-- Passwort. Codes describing a fault in this extension rather than in the user's setup - a
-- malformed timestamp, a signature of the wrong length - are deliberately absent: inventing
-- friendly wording for a bug would only obscure it.
--
-- err is the table returned by tryRequest: { code = Number|nil, message = String }.
local function describeError (err)
  local advice = err.code and ERROR_ADVICE[err.code]
  if advice then
    return advice
  end
  if err.code then
    return string.format("Bitvavo hat die Anfrage abgelehnt (Fehler %d): %s",
      err.code, tostring(err.message))
  end
  return string.format("Die Anfrage an Bitvavo ist fehlgeschlagen: %s", tostring(err.message))
end

-- Performs a request and decodes the body. Returns nil plus { code, message } on failure.
--
-- The pcall still matters for what never reaches HTTP at all - no network, a refused
-- connection, a body that is not JSON.
local function tryRequest (path, headers)
  local ok, content = pcall(function ()
    return connection:request("GET", API_HOST .. API_PREFIX .. path, nil, nil, headers)
  end)
  if not ok then
    return nil, { message = tostring(content) }
  end

  local decoded
  ok, decoded = pcall(function ()
    return JSON(content):dictionary()
  end)
  if not ok or type(decoded) ~= "table" then
    return nil, { message = "die Antwort von Bitvavo war kein gültiges JSON" }
  end

  -- Failures arrive as {"errorCode":n,"error":"..."}, with the HTTP status set accordingly.
  if decoded["errorCode"] ~= nil then
    return nil, { code = tonumber(decoded["errorCode"]), message = tostring(decoded["error"]) }
  end

  return decoded
end

-- Bitvavo signs timestamp .. METHOD .. "/v2" .. path, concatenated with no delimiter. The
-- body is omitted on a GET. The /v2 prefix is part of the signed string, not just the URL.
local function requestPrivate (path)
  local timestamp = string.format("%d", math.floor(MM.time() * 1000))
  local message = timestamp .. "GET" .. API_PREFIX .. path

  return tryRequest(path, {
    ["bitvavo-access-key"]       = apiKey,
    ["bitvavo-access-signature"] = bin2hex(MM.hmac256(apiSecret, message)),
    ["bitvavo-access-timestamp"] = timestamp,
    ["bitvavo-access-window"]    = ACCESS_WINDOW,
    ["Content-Type"]             = "application/json",
    -- Capitalised deliberately. On the wire HTTP header names are case-insensitive, but
    -- MoneyMoney has to inspect this table itself to decide whether to hand a failed response
    -- back to the script, and its documentation spells the field "Accept". A lowercase key
    -- would be sent correctly and still miss that check.
    ["Accept"]                   = "application/json"
  })
end

local function requestPublic (path)
  return tryRequest(path, {
    ["Content-Type"] = "application/json",
    ["Accept"]       = "application/json"
  })
end

function InitializeSession2 (protocol, bankCode, step, credentials, interactive)
  apiKey = trim(credentials[1] or "")
  apiSecret = trim(credentials[2] or "")

  if apiKey == "" or apiSecret == "" then
    return LoginFailed
  end

  -- Lengths only, never the values themselves. Enough to spot a truncated paste or two fields
  -- filled the wrong way round, without putting a credential anywhere near a log.
  --
  -- There is deliberately no local length check any more. Bitvavo rejects a wrong length itself
  -- with errorCode 301, and that message now reaches the user, so a hardcoded 64 here would
  -- only duplicate a server-side rule - and lock out valid keys if Bitvavo ever changes it.
  print(string.format("Bitvavo: Zugangsdaten erhalten, %d und %d Zeichen.",
    string.len(apiKey), string.len(apiSecret)))

  connection = Connection()

  -- Validate at setup time rather than leaving the first failure to a later refresh, so the
  -- error is tied to the credentials the user just typed.
  local balances, err = requestPrivate("/balance")
  if balances == nil then
    print(string.format("Bitvavo: Anmeldung fehlgeschlagen (%s) %s",
      tostring(err.code or "-"), tostring(err.message)))
    return describeError(err)
  end

  sessionBalances = balances
  print("Bitvavo: Anmeldung erfolgreich.")
end

function ListAccounts (knownAccounts)
  return {
    {
      -- The names are what MoneyMoney shows; the numbers are what it keys on. Renaming is
      -- therefore free, and "Depot" and "Verrechnungskonto" are what a German statement calls
      -- these two - the holdings, and the cash account that settles them.
      name = BANK_CODE .. " Depot",
      accountNumber = PORTFOLIO_ACCOUNT,
      currency = "EUR",
      portfolio = true,
      type = AccountTypePortfolio
    },
    {
      -- EUR moved out of the portfolio and into an account of its own. It cannot be in both:
      -- a cash balance plus a Euro position would count the same money twice.
      name = BANK_CODE .. " Verrechnungskonto",
      accountNumber = CASH_ACCOUNT,
      currency = "EUR",
      portfolio = false,
      type = AccountTypeGiro
    }
  }
end

-- market -> price, for all ~440 markets in a single request.
local function fetchPrices ()
  local response, err = requestPublic("/ticker/price")
  if response == nil then
    error(describeError(err))
  end

  local prices = {}
  for _, entry in pairs(response) do
    if type(entry) == "table" then
      local market = entry["market"]
      local price = tonumber(entry["price"])
      if market ~= nil and price ~= nil then
        prices[market] = price
      end
    end
  end

  if next(prices) == nil then
    error(MM.localizeText(
      "Bitvavo returned no market prices, so the portfolio cannot be valued. Try again later."))
  end

  return prices
end

-- symbol -> display name, cached in LocalStorage. Purely cosmetic, so a failure here degrades
-- to showing the ticker symbol instead of aborting the refresh.
local function fetchAssetNames ()
  local cache = LocalStorage["assetNames"]
  local cachedNames = type(cache) == "table" and type(cache.names) == "table" and cache.names or nil

  if cachedNames ~= nil and type(cache.fetchedAt) == "number"
      and (MM.time() - cache.fetchedAt) < ASSET_NAME_TTL then
    return cachedNames
  end

  local response = requestPublic("/assets")
  local names = {}
  if response ~= nil then
    for _, entry in pairs(response) do
      if type(entry) == "table" and entry["symbol"] ~= nil and entry["name"] ~= nil then
        names[entry["symbol"]] = entry["name"]
      end
    end
  end

  if next(names) ~= nil then
    LocalStorage["assetNames"] = { names = names, fetchedAt = MM.time() }
    return names
  end

  return cachedNames or {}
end

-- Every price comes from a real Bitvavo market. A USDC-only asset is converted at the live
-- USDC-EUR rate, never at an assumed 1:1 peg. An asset with no route to EUR returns nil and
-- is shown unpriced, because no value is honest where an invented one would not be.
local function priceInEur (symbol, prices)

  local direct = prices[symbol .. "-EUR"]
  if direct ~= nil and direct > 0 then
    return direct
  end

  local inUsdc = prices[symbol .. "-USDC"]
  local usdcInEur = prices["USDC-EUR"]
  if inUsdc ~= nil and inUsdc > 0 and usdcInEur ~= nil and usdcInEur > 0 then
    return inUsdc * usdcInEur
  end

  return nil
end

-- Builds one MoneyMoney position. Shared by the tradable balance and the staking balance so
-- the two cannot drift apart in how they are priced or named.
local function addPosition (securities, unpriced, symbol, quantity, names, prices, suffix)
  if quantity <= 0 then
    return
  end

  local price = priceInEur(symbol, prices)
  if price == nil then
    unpriced[#unpriced + 1] = symbol
  end

  securities[#securities + 1] = {
    name = (names[symbol] or symbol) .. (suffix or ""),
    market = BANK_CODE,
    quantity = quantity,
    -- nil marks a unit holding rather than a cash amount, so MoneyMoney values the position
    -- as quantity * price. EUR rides along at a price of 1.00.
    currencyOfQuantity = nil,
    price = price,
    currencyOfPrice = "EUR"
  }
end

-- The balance from the login check if this cycle already has it, otherwise a fresh call.
local function fetchBalances ()
  if sessionBalances ~= nil then
    return sessionBalances
  end

  local balances, err = requestPrivate("/balance")
  if balances == nil then
    error(describeError(err))
  end
  sessionBalances = balances
  return balances
end

-- Assets locked in fixed staking. Bitvavo excludes them from /balance, so without this call a
-- portfolio that stakes is reported too low - silently, which is the one outcome worth failing
-- over. An account that stakes nothing gets an empty array, not an error; verified live.
local function fetchStakingBalance ()
  local response, err = requestPrivate("/stakingBalance")
  if response == nil then
    error(describeError(err))
  end
  return response
end

-- ---------------------------------------------------------------------------
-- Account history - the cash account's transactions
-- ---------------------------------------------------------------------------

-- Bitvavo pages this endpoint. 100 keeps the number of round trips low without asking for a
-- response so large that a slow connection times out.
local HISTORY_PAGE_SIZE = 100

-- Guards against an endless loop should totalPages ever misbehave. 200 pages at 100 items is
-- 20000 events - far beyond any private account.
local HISTORY_PAGE_LIMIT = 200

-- executedAt is ISO 8601 in UTC ("2026-08-17T03:23:57.215Z"), while MoneyMoney wants POSIX
-- seconds. os.time reads its table as local time, so the offset has to be added back.
local function parseIsoTimestamp (iso)
  if type(iso) ~= "string" then
    return nil
  end

  local year, month, day, hour, minute, second =
    iso:match("^(%d+)-(%d+)-(%d+)T(%d+):(%d+):(%d+)")
  if year == nil then
    return nil
  end

  local asLocal = os.time({
    year = tonumber(year), month = tonumber(month), day = tonumber(day),
    hour = tonumber(hour), min = tonumber(minute), sec = tonumber(second),
    isdst = false
  })
  if asLocal == nil then
    return nil
  end

  return asLocal + os.difftime(asLocal, os.time(os.date("!*t", asLocal)))
end

-- How much EUR an event moved, fees included, positive for money in.
--
-- Deliberately computed from the currency fields rather than from the event type. Bitvavo
-- documents fourteen types and adds to them; a table of known types would silently drop the
-- unfamiliar ones, and the running balance would be wrong without anything looking wrong. An
-- event that moved no EUR returns 0 and is not a cash booking at all - a crypto withdrawal, for
-- instance, or a swap between two coins.
local function currencyEffect (event, currency)
  local total = 0.0

  if event["receivedCurrency"] == currency then
    total = total + (tonumber(event["receivedAmount"]) or 0)
  end
  if event["sentCurrency"] == currency then
    total = total - (tonumber(event["sentAmount"]) or 0)
  end
  -- A rebate carries no fee fields at all, so nothing here may be assumed present.
  if event["feesCurrency"] == currency then
    total = total - (tonumber(event["feesAmount"]) or 0)
  end

  return total
end

local function eurEffect (event)
  return currencyEffect(event, "EUR")
end

-- The one asset an event moved, or nil where none did. A trade touches exactly one besides EUR,
-- and a coin-to-coin swap - two of them - is deliberately not represented: it is one event, and
-- MoneyMoney has no booking that is two amounts in two currencies.
local function movedAsset (event)
  for _, field in ipairs({ "receivedCurrency", "sentCurrency" }) do
    local currency = event[field]
    if type(currency) == "string" and currency ~= "" and currency ~= "EUR" then
      return currency
    end
  end
  return nil
end

-- Same principle as the error codes: translate where it helps, fall back to what Bitvavo says.
local EVENT_LABEL = {
  buy        = "Kauf",
  sell       = "Verkauf",
  deposit    = "Einzahlung",
  withdrawal = "Auszahlung",
  rebate     = "Rückvergütung",
  staking    = "Staking-Ertrag",
  fixed_staking = "Staking-Ertrag (fest)"
}

-- Bitvavo writes its type names in snake case. An unknown one ends up in the name column of a
-- statement, where "campaign_new_user_incentive" reads as machine output that escaped. Seen
-- live: that exact type, for a new-customer credit that no documentation lists.
local function humaniseType (rawType)
  local text = tostring(rawType):gsub("_", " ")
  return (text:gsub("^%l", string.upper))
end

-- Formats a number the way a German statement reads, with a comma for the decimal mark.
--
-- EUR gets two decimals because that is what money looks like - unless two decimals would round
-- a real amount down to zero. A coin trading below a cent is exactly that case, and "0,00" in a
-- price would be a lie rather than a rounding. Quantities keep up to eight decimals with the
-- trailing zeros trimmed, so a whole number is not padded with noise.
-- Groups the integer part in threes, German style: 54676 -> 54.676. A rate in the tens of
-- thousands is the normal case here, and an ungrouped one has to be counted rather than read.
local function groupThousands (digits)
  local reversed = digits:reverse():gsub("(%d%d%d)", "%1.")
  local grouped = reversed:reverse()
  return (grouped:gsub("^%.", ""))
end

local function formatNumber (value, currency)
  local number = tonumber(value)
  if number == nil then
    return nil
  end

  local text
  if currency == "EUR" and math.abs(number) >= 0.005 then
    text = string.format("%.2f", number)
  else
    text = string.format("%.8f", number)
    text = text:gsub("0+$", "")
    text = text:gsub("%.$", "")
  end

  local sign, whole, fraction = text:match("^(%-?)(%d+)%.?(%d*)$")
  if whole == nil then
    return (text:gsub("%.", ","))
  end

  local formatted = sign .. groupThousands(whole)
  if fraction ~= "" then
    formatted = formatted .. "," .. fraction
  end
  return formatted
end

-- Returns the two strings MoneyMoney shows for a booking: its name and its purpose line.
--
-- A trade names the quantity and the asset, with the rate and any fee behind it. "Kauf" on its
-- own is an amount without a story, and the rate is the one number a statement cannot
-- reconstruct later once the market has moved.
--
-- Everything else carries Bitvavo's own type in the purpose, which is what someone comparing
-- this against a Bitvavo export needs. The exception is a type this extension does not know:
-- there the name already is that term, so repeating it would only fill the column twice.
-- Bitvavo calls both of these "withdrawal": euro sent to a bank account, and a coin sent to a
-- wallet the customer controls. They are not the same event. The first leaves the relationship;
-- the second moves the same holding into the customer's own custody, and nothing was spent.
-- Labelling both "Auszahlung" reads as if the coins had been cashed out.
--
-- "Übertragung" says what happened without implying either. The direction is not in the word
-- because it does not need to be: the purpose line names the other side as "An ..." or
-- "Von ...", and one label for both directions is what lets a statement group them.
local ASSET_EVENT_LABEL = {
  deposit    = "Übertragung",
  withdrawal = "Übertragung"
}

local function describeEvent (event)
  local eventType = event["type"]
  local label = EVENT_LABEL[eventType] or humaniseType(eventType)

  -- On a buy the asset arrives and EUR leaves; on a sell, and on a transfer out, the reverse.
  local asset = movedAsset(event)
  local quantity = nil
  if asset ~= nil then
    quantity = (asset == event["receivedCurrency"]) and event["receivedAmount"]
               or event["sentAmount"]
  end

  -- Where the money came from or went to. Present on transfers, null on everything else.
  --
  -- Read from /account/history rather than from /depositHistory, which carries the same field
  -- unmasked. Bitvavo shortens a bank account to "DE80***00" here, and that is the better
  -- value: it names the source unambiguously for anyone who owns the account, and it keeps a
  -- full IBAN out of MoneyMoney's database. The direction follows the currency fields, not the
  -- event type, for the same reason the amount does - an unfamiliar transfer type still reads
  -- correctly.
  local address = event["address"]
  local transfer = nil
  if type(address) == "string" and address ~= "" then
    if event["receivedCurrency"] ~= nil and event["sentCurrency"] == nil then
      transfer = "Von " .. address
    elseif event["sentCurrency"] ~= nil and event["receivedCurrency"] == nil then
      transfer = "An " .. address
    end
  end

  -- The name is a category, not a description of this one booking. "Kauf BTC" is the same
  -- string on every Bitcoin purchase, so a statement groups by it, a search finds all of them,
  -- and a MoneyMoney rule can match it. "Kauf 0,00456086 BTC" is unique to a single row and
  -- defeats all three. The quantity belongs in the purpose, where being unique costs nothing.
  --
  -- The purpose leads with the quantity and puts the rest in brackets behind it, because the
  -- quantity is the fact and the rate and the fee qualify it. A euro amount is never repeated
  -- there - it is already in its own column, and saying it twice is how the column stops being
  -- read.
  local details = {}
  if transfer ~= nil then
    details[#details + 1] = transfer
  end

  if eventType == "buy" or eventType == "sell" then
    local rate = formatNumber(event["priceAmount"], event["priceCurrency"])
    if rate ~= nil and event["priceCurrency"] ~= nil then
      details[#details + 1] = "Kurs " .. rate .. " " .. event["priceCurrency"]
    end
  end

  local fee = tonumber(event["feesAmount"])
  if fee ~= nil and fee > 0 and event["feesCurrency"] ~= nil then
    details[#details + 1] =
      "Gebühr " .. formatNumber(fee, event["feesCurrency"]) .. " " .. event["feesCurrency"]
  end

  if asset ~= nil then
    -- asset is never EUR here, so a transfer label applies whenever one exists for the type.
    label = ASSET_EVENT_LABEL[eventType] or label

    local moved = formatNumber(quantity, asset)
    local name = label .. " " .. asset
    local head = moved and (moved .. " " .. asset) or nil

    if head == nil then
      return name, (#details > 0) and table.concat(details, ", ") or nil
    end
    if #details == 0 then
      return name, head
    end
    return name, head .. " (" .. table.concat(details, ", ") .. ")"
  end

  -- No asset involved: a plain euro movement. The purpose stays empty unless it carries
  -- something the name does not - the source of a deposit, say. Bitvavo's own type name was in
  -- here once and earned its place badly: next to "Rückvergütung" it printed "rebate", the same
  -- word in the other language, and it was the only English string in a German column.
  return label, (#details > 0) and table.concat(details, ", ") or nil
end

-- Fetches /v2/account/history and returns the events as one flat list.
--
-- The range is narrowed server side with fromDate, so a refresh asks for what happened since
-- MoneyMoney last looked instead of for everything. Without it an account with ten thousand
-- events would page through all hundred pages on every single refresh, and the cost would grow
-- with the account's age forever. A first sync has no cut-off and does read everything, once.
--
-- Deliberately not narrowed by type. The endpoint offers that filter and its enumeration is the
-- same fourteen types Bitvavo documents - which a live account was already found to exceed. A
-- type filter would have dropped a real credit of 20 EUR at the server, where nothing in the
-- response could hint that anything was missing.
local function fetchAccountHistory (since)
  local events = {}
  local page = 1

  -- Milliseconds, and an integer: "%d" because Lua would otherwise render a float and Bitvavo
  -- would reject it. fromDate is inclusive where the filter below is strict, so an event landing
  -- exactly on the cut-off is fetched and then dropped - the two are not redundant, they draw
  -- the boundary at different sharpness.
  local range = ""
  if since ~= nil then
    range = string.format("&fromDate=%d", math.floor(since) * 1000)
  end

  repeat
    local response, err = requestPrivate(string.format(
      "/account/history?page=%d&maxItems=%d%s", page, HISTORY_PAGE_SIZE, range))
    if response == nil then
      error(describeError(err))
    end

    local items = response["items"]
    if type(items) ~= "table" then
      error(MM.localizeText(
        "Bitvavo returned an account history in an unexpected format. The API may have changed; " ..
        "please report this at https://github.com/GordonSeipold/MoneyMoney-Bitvavo/issues"))
    end

    for _, event in pairs(items) do
      if type(event) == "table" then
        events[#events + 1] = event
      end
    end

    local totalPages = tonumber(response["totalPages"]) or 1
    page = page + 1
  until page > totalPages or page > HISTORY_PAGE_LIMIT

  return events
end

-- Turns the event list into MoneyMoney transactions for a cash account.
--
-- Events at or before "since" are dropped. MoneyMoney passes the point from which it wants
-- transactions, and whether it discards a repeat of something it already stored is not
-- documented anywhere we could find. Honouring the cut-off is the only behaviour that is
-- correct either way: if MoneyMoney does deduplicate, nothing is lost by sending less, and if
-- it does not, this is what keeps every refresh from stacking the whole history on top of
-- itself. No overlap margin for the same reason - an overlap is only free under the assumption
-- we are declining to make. A nil since means a first sync and everything is sent.
--
-- The cut-off filters rather than stopping the paging early, because Bitvavo does not document
-- an ordering for /account/history. Observed responses are newest first, but breaking out of
-- the loop on that basis would drop events if it ever came back unsorted, and the endpoint is
-- cheap enough at one rate-limit point per page that reading all of it costs nothing worth
-- having.
local function buildCashTransactions (events, since)
  local transactions = {}

  for _, event in pairs(events) do
    local amount = eurEffect(event)

    -- A coin that moved without costing anything - sent to a private wallet, arrived from one -
    -- is booked at zero rather than dropped. Otherwise the coins simply stop appearing in the
    -- portfolio one day with nothing anywhere to say where they went, and the statement shows
    -- two purchases where the portfolio holds one. Zero leaves the balance untouched, so the
    -- reconciliation still holds; the line exists to carry its name and its address.
    if amount ~= 0 or movedAsset(event) ~= nil then
      local bookingDate = parseIsoTimestamp(event["executedAt"])
      if bookingDate == nil then
        error(MM.localizeText(
          "Bitvavo returned an account history entry without a usable date. The API may have " ..
          "changed; please report this at " ..
          "https://github.com/GordonSeipold/MoneyMoney-Bitvavo/issues"))
      end

      if since == nil or bookingDate > since then
        local name, purpose = describeEvent(event)

        transactions[#transactions + 1] = {
          name = name,
          amount = amount,
          currency = "EUR",
          bookingDate = bookingDate,
          purpose = purpose,
          -- Not transactionCode: MoneyMoney wants an integer there and rejects Bitvavo's UUID
          -- with a warning per booking. It deduplicates without any help from us - a refresh
          -- that returns two known bookings reports "0 are new" - but that match is on the
          -- visible fields, so two identical amounts on one day would collapse into one. The
          -- reference is what keeps them apart.
          endToEndReference = tostring(event["transactionId"]),
          booked = true
        }
      end
    end
  end

  return transactions
end

-- The cash account: EUR balance plus every event that moved EUR.
local function refreshCashAccount (since)
  MM.printStatus(MM.localizeText("Fetching balances"))
  local balances = fetchBalances()

  local balance = 0.0
  for _, entry in pairs(balances) do
    if type(entry) == "table" and entry["symbol"] == "EUR" then
      balance = (tonumber(entry["available"]) or 0) + (tonumber(entry["inOrder"]) or 0)
    end
  end

  MM.printStatus(MM.localizeText("Fetching transactions"))
  return {
    balance = balance,
    transactions = buildCashTransactions(fetchAccountHistory(since), since)
  }
end

function RefreshAccount (account, since)
  if account["accountNumber"] == CASH_ACCOUNT then
    return refreshCashAccount(since)
  end

  MM.printStatus(MM.localizeText("Fetching balances"))

  local balances = fetchBalances()

  local staked = fetchStakingBalance()

  MM.printStatus(MM.localizeText("Fetching prices"))
  local prices = fetchPrices()
  local names = fetchAssetNames()

  local securities = {}
  local unpriced = {}

  for _, entry in pairs(balances) do
    local symbol = type(entry) == "table" and entry["symbol"] or nil
    local available = type(entry) == "table" and tonumber(entry["available"]) or nil
    local inOrder = type(entry) == "table" and tonumber(entry["inOrder"]) or nil

    -- Deliberately strict. Defaulting a missing amount to zero would quietly understate the
    -- portfolio, which is worse than a refresh that fails and says why.
    if symbol == nil or available == nil or inOrder == nil then
      error(MM.localizeText(
        "Bitvavo returned a balance entry in an unexpected format. The API may have changed; " ..
        "please report this at https://github.com/GordonSeipold/MoneyMoney-Bitvavo/issues"))
    end

    -- EUR is the cash account now, not a position.
    if symbol ~= "EUR" then
      addPosition(securities, unpriced, symbol, available + inOrder, names, prices)
    end
  end

  -- Locked positions are listed separately rather than added to the tradable one. Merging them
  -- would make the total right and hide that part of it cannot be sold.
  for _, entry in pairs(staked) do
    local symbol = type(entry) == "table" and entry["symbol"] or nil
    local amount = type(entry) == "table" and tonumber(entry["amount"]) or nil

    if symbol == nil or amount == nil then
      error(MM.localizeText(
        "Bitvavo returned a staking entry in an unexpected format. The API may have changed; " ..
        "please report this at https://github.com/GordonSeipold/MoneyMoney-Bitvavo/issues"))
    end

    addPosition(securities, unpriced, symbol, amount, names, prices, " (Fixed Staking)")
  end

  if #unpriced > 0 then
    print(string.format(
      "Bitvavo: kein EUR-Kurs für %s - diese Bestände werden ohne Wert angezeigt.",
      table.concat(unpriced, ", ")))
  end

  -- Positions only. MoneyMoney ignores transactions on an account of type AccountTypePortfolio:
  -- returning three of them alongside the securities produced no list and no error, verified
  -- live on 2026-08-17. A coin movement is therefore recorded on the cash account instead.
  return { securities = securities }
end

function EndSession ()
  sessionBalances = nil
  if connection ~= nil then
    connection:close()
    connection = nil
  end
end
