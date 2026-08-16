-- Unofficial Bitvavo Extension (https://bitvavo.com) for MoneyMoney
-- Fetches crypto and EUR balances and presents them as a securities portfolio priced in EUR.
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

-- Display names change rarely, so one /assets call a week is plenty. It costs ~4 rate-limit
-- weight against a budget of 1000 per minute; caching keeps a normal refresh at two requests.
local ASSET_NAME_TTL = 7 * 24 * 60 * 60

WebBanking{
  -- Pre-release. 1.0 is reserved for the first signed, published build; until then every
  -- version handed over for testing gets the next 0.x, so the protocol window says which
  -- build is actually loaded.
  version  = 0.4,
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

-- Reports a failure that this script actually gets to see.
--
-- Deliberately no mapping of HTTP statuses to friendly messages. Verified experimentally
-- (see research notes): MoneyMoney terminates the script inside connection:request on any
-- non-2xx status, so no code after the call runs and nothing returned from here is ever
-- displayed for a 401, 403 or 429. Such a mapping would look protective while being
-- unreachable, which is worse than not having it. Everything checkable is therefore checked
-- before the first request instead.
--
-- What does still arrive here: a 200 response carrying an errorCode, or a body that is not
-- JSON at all.
local function describeError (message)
  return string.format(
    MM.localizeText("Bitvavo returned an unexpected response: %s"), message)
end

-- Performs a request and decodes the body, returning nil plus a message on failure.
--
-- The pcall does not catch an HTTP error status - the engine terminates the script before it
-- could. It is kept for the failures that do stay inside Lua, such as a malformed response.
local function tryRequest (path, headers)
  local ok, content = pcall(function ()
    return connection:request("GET", API_HOST .. API_PREFIX .. path, nil, nil, headers)
  end)
  if not ok then
    return nil, tostring(content)
  end

  local decoded
  ok, decoded = pcall(function ()
    return JSON(content):dictionary()
  end)
  if not ok or type(decoded) ~= "table" then
    return nil, "the response was not valid JSON"
  end

  -- Bitvavo reports failures as {"errorCode":n,"error":"..."}. Those normally arrive with a
  -- non-2xx status and are caught above, but a 200 carrying an error body would otherwise be
  -- iterated as if it were a result list.
  if decoded["errorCode"] ~= nil then
    return nil, string.format("error %s: %s",
      tostring(decoded["errorCode"]), tostring(decoded["error"]))
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
    ["content-type"]             = "application/json"
  })
end

local function requestPublic (path)
  return tryRequest(path, { ["content-type"] = "application/json" })
end

function InitializeSession2 (protocol, bankCode, step, credentials, interactive)
  apiKey = trim(credentials[1] or "")
  apiSecret = trim(credentials[2] or "")

  if apiKey == "" or apiSecret == "" then
    return LoginFailed
  end

  -- Lengths only, never the values themselves. The protocol window is the one channel that
  -- demonstrably reaches the user when a request fails, so this is where a credential problem
  -- has to become visible.
  local keyLength = string.len(apiKey)
  local sigLength = string.len(apiSecret)
  print(string.format(
    "Bitvavo: credentials received, %d and %d characters (the key should be 64).",
    keyLength, sigLength))

  -- A Bitvavo key is exactly 64 characters; the API rejects any other length itself with
  -- errorCode 301. Checking here rather than letting the request fail is not redundant:
  -- observed live, MoneyMoney aborts on an HTTP error status and shows its own "internal
  -- error" message instead of the text this function returns. Whatever a wrong key produces
  -- server-side never reaches the user, so the common mistakes - key and secret swapped, or
  -- a truncated paste - have to be caught before the call goes out.
  if keyLength ~= 64 then
    return MM.localizeText(
      "That does not look like a Bitvavo API key - it should be exactly 64 characters. " ..
      "The user name field takes the API key, the password field takes the API secret.")
  end

  connection = Connection()

  -- Validate at setup time rather than leaving the first failure to a later refresh. The
  -- message is the same generic one either way, but failing here at least ties it to the
  -- credentials the user just typed.
  local balances, err = requestPrivate("/balance")
  if balances == nil then
    -- Reached only when the response was a 200 that could not be used. A rejected request
    -- never gets here: the engine has already aborted the script by then.
    print("Bitvavo: login check failed - " .. tostring(err))
    return describeError(err)
  end

  print("Bitvavo: login check succeeded.")
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
  local balances, err = requestPrivate("/balance")
  if balances == nil then
    error(describeError(err))
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
      "No EUR price available on Bitvavo for: %s. These holdings are listed without a value.",
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
