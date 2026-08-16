-- Unofficial Bitvavo Extension (https://bitvavo.com) for MoneyMoney
-- Fetches crypto and EUR balances and lists each asset with its current EUR price.
-- MoneyMoney has no account type for crypto, so the account appears as a portfolio.
--
-- Fixed-staking balances are NOT included: Bitvavo reports them through a separate
-- endpoint (GET /stakingBalance) that this version deliberately does not call.
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
-- https://github.com/GordonSeipold/moneymoney-bitvavo

local BANK_CODE  = "Bitvavo"
local API_HOST   = "https://api.bitvavo.com"
local API_PREFIX = "/v2"

-- Milliseconds of clock skew Bitvavo accepts on a signed request. Official SDK default.
local ACCESS_WINDOW = "10000"

-- Display names change rarely, so one /assets call a week is plenty. The saving is a request,
-- not weight: /assets costs 1 rate-limit point of 1000 per minute. Caching keeps a normal
-- refresh at two calls, /balance (5 points) and /ticker/price (1).
local ASSET_NAME_TTL = 7 * 24 * 60 * 60

WebBanking{
  -- Pre-release. 1.0 is reserved for the first signed, published build; until then every
  -- version handed over for testing gets the next 0.x, so the protocol window says which
  -- build is actually loaded.
  version  = 0.9,
  url      = "https://bitvavo.com",
  services = { BANK_CODE },
  -- MoneyMoney gives an extension no way to rename the credential fields, so this description
  -- is the only place in the UI that can say which value belongs in which field.
  description = string.format(MM.localizeText("Fetch balances from %s"), BANK_CODE) .. " " ..
    MM.localizeText("Enter the API key as user name and the API secret as password.")
}

local apiKey
local apiSecret
local connection

-- The /balance response from the login check. MoneyMoney runs InitializeSession2 on every
-- refresh cycle, not only when the account is added, so fetching it again in RefreshAccount
-- would mean asking for the same data twice per refresh - and /balance is the most expensive
-- call in the set at 5 rate-limit points. It is consumed once and then discarded.
local loginBalances

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

  loginBalances = balances
  print("Bitvavo: Anmeldung erfolgreich.")
end

function ListAccounts (knownAccounts)
  return {
    {
      name = BANK_CODE,
      -- A constant, deliberately not derived from the API key: rotating the key must not
      -- orphan the account and its history in MoneyMoney.
      accountNumber = "Bitvavo",
      currency = "EUR",
      portfolio = true,
      type = AccountTypePortfolio
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
  if symbol == "EUR" then
    return 1.0
  end

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

function RefreshAccount (account, since)
  MM.printStatus(MM.localizeText("Fetching balances"))

  -- The login check fetched this moments ago in the same cycle. Consume it once, so a second
  -- refresh in the same session still asks for fresh numbers.
  local balances = loginBalances
  loginBalances = nil
  if balances == nil then
    local err
    balances, err = requestPrivate("/balance")
    if balances == nil then
      error(describeError(err))
    end
  end

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
        "please report this at https://github.com/GordonSeipold/moneymoney-bitvavo/issues"))
    end

    local quantity = available + inOrder
    if quantity > 0 then
      local price = priceInEur(symbol, prices)
      if price == nil then
        unpriced[#unpriced + 1] = symbol
      end

      securities[#securities + 1] = {
        name = names[symbol] or symbol,
        market = BANK_CODE,
        quantity = quantity,
        -- nil marks a unit holding rather than a cash amount, so MoneyMoney values the
        -- position as quantity * price. EUR rides along at a price of 1.00.
        currencyOfQuantity = nil,
        price = price,
        currencyOfPrice = "EUR"
      }
    end
  end

  if #unpriced > 0 then
    print(string.format(
      "Bitvavo: kein EUR-Kurs für %s - diese Bestände werden ohne Wert angezeigt.",
      table.concat(unpriced, ", ")))
  end

  return { securities = securities }
end

function EndSession ()
  if connection ~= nil then
    connection:close()
    connection = nil
  end
end
