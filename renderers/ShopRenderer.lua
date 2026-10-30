-- OmniUI Poké Mart / Shop Screen Renderer
-- Split catalog layout with live item descriptions, quantity stepper, and purchase confirmation.

local Layout = require("mods.omni_ui.core.Layout")
local AdapterResolver = require("mods.omni_ui.adapters.AdapterResolver")

local ShopRenderer = {}

local ROOT_LABEL = { buy = "BUY", sell = "SELL", quit = "SEE YA" }
local ROOT_DESC = {
  buy = "Browse the shelf and buy items.",
  sell = "Sell items from your bag.",
  quit = "Leave the counter.",
}

local function shopPhase(state)
  local st = state and state.state
  if st == "root" or st == "list" or st == "msg" or st == "qty" or st == "confirm" or st == "sell" then
    return st
  end
  return (state and state.mode) or "buy"
end

function ShopRenderer.clerkPages(raw)
  local text = tostring(raw or "")
  if text == "" then return {} end
  local pages = {}
  for page in (text .. "\f"):gmatch("(.-)\f") do
    if page ~= "" then pages[#pages + 1] = page end
  end
  if #pages == 0 then pages[1] = text end
  return pages
end

-- One A per clerk page. The last page is left for the shop itself.
function ShopRenderer.holdClerkPage(state, input)
  if not state or not input or not input.wasPressed then return false end
  local phase = shopPhase(state)
  if phase ~= "buy_msg" and phase ~= "msg" then return false end
  local pages = ShopRenderer.clerkPages(state._status)
  local page = state.__omniShopPage or 1
  if page >= #pages then return false end
  if input:wasPressed("a") or input:wasPressed("b") then
    state.__omniShopPage = page + 1
    return true
  end
  return false
end

local function syncClerkPage(state)
  if state.__omniShopSpeech ~= state._status then
    state.__omniShopSpeech = state._status
    state.__omniShopPage = 1
  end
end

local function dialogueBox(w, h)
  local ctx = Layout.getContext(w, h)
  local dw = math.min(w - (ctx.isCompact and 16 or 36), 740)
  local dh = ctx.isUltraCompact and 92 or 114
  local dx = math.floor((w - dw) / 2)
  local marginBottom = ctx.isUltraCompact and 8 or (ctx.isCompact and 14 or 24)
  local dy = ctx.isPortrait and math.min(h - dh - 160, math.floor(h * 0.44)) or (h - dh - marginBottom)
  return dx, dy, dw, dh
end

local function priceNumber(price)
  if type(price) == "number" then return price end
  if type(price) == "string" then
    return tonumber(price:match("%d+")) or 0
  end
  return 0
end

local function priceEach(price)
  local n = priceNumber(price)
  if type(price) == "string" and price:find("EACH", 1, true) then return price end
  return ("¥%d EACH"):format(n)
end

local function bagCount(state, itemId)
  local bag = state and state._session and state._session.bag
  if not bag or itemId == nil then return nil end
  local ok, Bag = pcall(require, "src.core.game3.bag")
  if not (ok and Bag and Bag.get) then return nil end
  local okN, n = pcall(Bag.get, bag, itemId)
  if okN and n ~= nil then return tonumber(n) or 0 end
  return nil
end

local function drawClerkSpeech(game, state, w, h, theme, quiet)
  local pages = ShopRenderer.clerkPages(state._status)
  if #pages == 0 then return end
  syncClerkPage(state)
  local page = math.max(1, math.min(#pages, state.__omniShopPage or 1))
  state.__omniShopPage = page
  local DialogueRenderer = require("mods.omni_ui.renderers.DialogueRenderer")
  DialogueRenderer.draw(game, {
    speaker = "CLERK",
    _pages = pages,
    _page = page,
    _waiting = not quiet,
    _revealed = 9999,
  }, w, h, theme)
end

-- The count lives on the clerk's "how many" line. Up and down change it.
local function drawQtyChooser(state, w, h, theme, money, qty, unitPrice, itemId)
  local dx, dy, dw, dh = dialogueBox(w, h)
  local cardW = math.min(196, math.floor(dw * 0.42))
  local cardH = math.max(64, dh - 20)
  local cx = dx + dw - cardW - 12
  local cy = dy + math.floor((dh - cardH) / 2)
  Layout.drawCard(cx, cy, cardW, cardH, {
    color = theme.surfaceHigh,
    borderColor = theme.borderStrong,
    borderWidth = 2,
    radius = 8,
  })
  Layout.drawText(("x%02d"):format(qty), cx + 14, cy + 12, {
    font = "headline",
    color = theme.heading,
    bold = true,
  })
  local total = (tonumber(unitPrice) or 0) * qty
  local totalStr = ("¥%d"):format(total)
  local badgeW = Layout.textWidth(totalStr, "tiny") + 16
  Layout.drawBadge(cx + cardW - badgeW - 10, cy + 14, totalStr, {
    kind = (total <= (tonumber(money) or 0)) and "good" or "danger",
    font = "tiny",
    width = badgeW,
  })
  local held = bagCount(state, itemId)
  local sub = held and ("IN BAG: %d"):format(held) or "UP / DOWN"
  Layout.drawText(sub, cx + 14, cy + 42, { font = "caption", color = theme.textDim })
end

local function rootChoices(state)
  if state._martType == "DECOR" or state._martType == "DECOR2" then
    return { "buy", "quit" }
  end
  if type(state.ROOT) == "table" and #state.ROOT > 0 then
    local out = {}
    for _, entry in ipairs(state.ROOT) do
      out[#out + 1] = type(entry) == "table" and (entry.id or entry.label) or entry
    end
    if #out > 0 then return out end
  end
  return { "buy", "sell", "quit" }
end

local function rootRows(state)
  local rows = {}
  for _, id in ipairs(rootChoices(state)) do
    local label = ROOT_LABEL[id] or tostring(id):upper()
    rows[#rows + 1] = {
      id = id,
      label = label,
      name = label,
      choice = true,
      description = ROOT_DESC[id] or "",
    }
  end
  return rows
end

-- Ruby, Sapphire, and Emerald move a window cursor (scroll + row). FireRed uses cursor.
local function windowCursor(state)
  return state and state.row ~= nil and state.state ~= nil and state.state ~= "root" and state.state ~= "sell"
end

local function catalogItems(items, phase)
  local browsing = phase == "list" or phase == "buy" or phase == "buy_qty" or phase == "qty"
    or phase == "buy_confirm" or phase == "confirm"
  if not browsing or type(items) ~= "table" then return items end
  local last = items[#items]
  if type(last) == "table" and last.cancel then return items end
  local copy = {}
  for i = 1, #items do copy[i] = items[i] end
  copy[#copy + 1] = { cancel = true, label = "CANCEL", name = "CANCEL" }
  return copy
end

local function decorRecord(id)
  local ok, decor = pcall(require, "src.core.game3.rse.decoration_inventory")
  if not (ok and decor and decor.info) then return nil end
  local okD, info = pcall(decor.info, id)
  if okD and type(info) == "table" then return info end
  return nil
end

local function newsHalfPrice(state)
  if not state or not state.state or not state._session then return false end
  if state._martType and state._martType ~= "NORMAL" then return false end
  local ok, Tv = pcall(require, "src.core.game3.rse.tv")
  local okR, Rse = pcall(require, "src.core.game3.rse.init")
  if not (ok and Tv and Tv.isPokeNewsActive and okR and Rse and Rse.call) then return false end
  local okA, active = pcall(Tv.isPokeNewsActive, state._session, 1, function(kind)
    return Rse.call("tv", "shouldApplyPokeNews", "ShouldApplyPokeNewsEffect", nil, kind) == true
  end)
  return okA and active == true
end

-- Gen 3 marts store stock as item ids. Gen 1 and 2 already pass row tables.
local function asShopItem(it, game, state, halfPrice)
  if type(it) == "table" then
    if halfPrice and type(it.price) == "number" and not it.cancel then
      local copy = {}
      for k, v in pairs(it) do copy[k] = v end
      copy.price = math.floor(it.price / 2)
      return copy
    end
    return it
  end
  if type(it) ~= "number" and type(it) ~= "string" then return it end
  local name, price, desc
  local fromDecor = false
  if state and (state._martType == "DECOR" or state._martType == "DECOR2") then
    local info = decorRecord(it)
    if info then
      fromDecor = true
      name = info.name
      price = tonumber(info.price)
      desc = info.description
    end
  end
  local ok, ItemsData = pcall(require, "src.core.game3.items_data")
  if ok and ItemsData and not fromDecor then
    if ItemsData.displayName then
      local okN, n = pcall(ItemsData.displayName, it)
      if okN and n and n ~= "" then name = n end
    end
    if ItemsData.info then
      local okI, info = pcall(ItemsData.info, it)
      if okI and type(info) == "table" then price = tonumber(info.price) end
    end
    if ItemsData.description then
      local okD, d = pcall(ItemsData.description, it)
      if okD and d and d ~= "" then desc = d end
    end
  end
  local def = game and game.data and game.data.items and game.data.items[it]
  if type(def) == "table" then
    name = name or def.name
    price = price or tonumber(def.price)
    desc = desc or def.description
  end
  if halfPrice and type(price) == "number" then price = math.floor(price / 2) end
  return {
    id = it,
    value = it,
    name = name or tostring(it),
    label = name or tostring(it),
    price = price,
    description = desc,
    def = type(def) == "table" and def or nil,
  }
end

function ShopRenderer.draw(game, state, w, h, theme, subState)
  local adapter = AdapterResolver.resolve(game)
  local playerInfo = adapter:getPlayerInfo()

  local items = state.items or state.rows or state._items or {}
  local hoennList = windowCursor(state)
  local curIdx = hoennList and ((state.scroll or 0) + (state.row or 0) + 1) or (state.index or state.cursor or 1)
  local scroll = state.scroll or 0
  local halfPrice = newsHalfPrice(state)
  local mode = state.mode or "buy"
  local qty = state.qty or 1
  local yesNoCursor = state.yesNoCursor or state.yesCursor or 1
  local phase = shopPhase(state)
  syncClerkPage(state)

  -- Money amount
  local money = playerInfo.money
  if state.money and type(state.money) == "function" then
    local ok, m = pcall(state.money)
    if ok and m then money = m end
  elseif state._session and state._session.money then
    money = state._session.money
  end

  local ctx = Layout.getContext(w, h)
  local isNarrow = (w < 580) or ctx.isPortrait

  -- 1. Top Header Card
  Layout.drawCard(0, 0, w, 44, { color = theme.surface, borderColor = theme.border, radius = 8 })
  Layout.drawText("POKÉ MART CATALOG", 18, 12, { font = "headline", color = theme.heading, bold = true })
  Layout.drawBadge(w - (isNarrow and 120 or 180), 12, isNarrow and ("¥%d"):format(money) or ("FUNDS: ¥%d"):format(money), { kind = "good" })

  if phase == "root" then
    items = rootRows(state)
    curIdx = state.cursor or state.index or 1
    scroll = 0
  end

  if phase == "buy_msg" or phase == "msg" then
    drawClerkSpeech(game, state, w, h, theme)
    return
  end

  if phase ~= "root" then
    items = catalogItems(items, phase)
  end

  local footY = h - 38

  if isNarrow then
    -- =========================================================================
    -- PORTRAIT / COMPACT MOBILE FULL-WIDTH CATALOG + DOCKED PREVIEW DRAWER
    -- =========================================================================
    local detailH = 132
    local listH = footY - 50 - detailH - 8
    Layout.drawCard(0, 50, w, listH, { color = theme.surface, borderColor = theme.border, radius = 8 })

    local rowH = 36
    local visibleCount = math.max(1, math.floor((listH - 16) / (rowH + 3)))

    if curIdx <= scroll then
      scroll = curIdx - 1
    elseif curIdx > scroll + visibleCount then
      scroll = curIdx - visibleCount
    end
    scroll = math.max(0, math.min(math.max(0, #items - visibleCount), scroll))
    if not hoennList then state.scroll = scroll end

    local itemW = (#items > visibleCount) and (w - 28) or (w - 16)

    for r = 1, visibleCount do
      local idx = scroll + r
      local it = asShopItem(items[idx], game, state, halfPrice)
      if it then
        local isSel = (curIdx == idx)
        local iy = 56 + (r - 1) * (rowH + 3)

        if isSel then
          Layout.drawCard(8, iy, itemW, rowH, {
            color = theme.accentDark,
            borderColor = theme.borderStrong,
            borderWidth = 2,
            radius = 6,
          })
        else
          Layout.drawSlot(8, iy, itemW, rowH, {
            color = theme.surfaceHigh,
            borderColor = theme.border,
            borderWidth = 1,
            radius = 6,
          })
        end

        local name = it.label or it.name or it.id or "ITEM"
        Layout.drawText(name, 16, iy + 8, {
          font = "button",
          color = isSel and theme.heading or theme.text,
          bold = isSel,
        })

        local price = it.price or (it.def and it.def.price)
        if price then
          local pStr = (type(price) == "number") and ("¥%d"):format(price) or tostring(price)
          local pBadgeW = Layout.textWidth(pStr, "tiny") + 16
          local badgeX = 8 + itemW - pBadgeW - 6
          Layout.drawBadge(badgeX, iy + 6, pStr, { kind = isSel and "good" or "ghost", font = "tiny", width = pBadgeW })
        end
      end
    end

    if #items > visibleCount then
      Layout.drawScrollBar(w - 12, 56, 5, listH - 12, #items, visibleCount, scroll)
    end

    -- Docked Item Preview Drawer
    local detailY = 50 + listH + 6
    Layout.drawCard(0, detailY, w, detailH, { color = theme.surface, borderColor = theme.border, radius = 8 })

    local curItem = asShopItem(items[curIdx], game, state, halfPrice)
    if curItem and not curItem.cancel then
      local name = curItem.label or curItem.name or curItem.id or "ITEM"
      Layout.drawText(name, 14, detailY + 8, { font = "headline", color = theme.heading, bold = true })

      local price = curItem.price or (curItem.def and curItem.def.price) or 0
      if not curItem.choice then
        Layout.drawBadge(w - 100, detailY + 8, priceEach(price), { kind = "ghost" })
      end

      local itemId = curItem.value or curItem.id
      local def = (curItem.def) or (itemId and game.data and game.data.items and game.data.items[itemId])
      local desc = (def and def.description) or (curItem.description) or "Standard merchandise available at the Poké Mart."
      if type(desc) == "table" then desc = table.concat(desc, " ") end

      local isQty = (mode == "buy_qty" or mode == "sell_qty" or phase == "qty" or state.isQuantityBox or (subState and (subState.qty ~= nil or subState.isQuantityBox)))
      local isConfirm = (mode == "buy_confirm" or mode == "sell_confirm" or phase == "confirm" or (subState and (subState.labels or subState.choices or (subState.onChoose and not subState.items))))

      if isQty then
        local activeQty = (subState and subState.qty) or state.qty or qty
        local totalCost = priceNumber(price) * activeQty
        Layout.drawText(("x%02d"):format(activeQty), 14, detailY + 36, { font = "headline", color = theme.heading, bold = true })
        Layout.drawBadge(w - 130, detailY + 38, ("TOTAL: ¥%d"):format(totalCost), { kind = (totalCost <= money) and "good" or "danger" })
        Layout.drawText("Up / Down changes the amount", 14, detailY + 70, { font = "tiny", color = theme.textDim })
      elseif isConfirm then
        local activeYesNoCursor = (subState and subState.index) or state.yesNoCursor or state.yesCursor or yesNoCursor
        local isYes = (activeYesNoCursor == 1)
        Layout.drawText("Confirm transaction?", 14, detailY + 36, { font = "body", color = theme.heading, bold = true })
        Layout.drawButton(w - 150, detailY + 32, 64, 30, "Yes", { kind = isYes and "primary" or "ghost", selected = isYes })
        Layout.drawButton(w - 76, detailY + 32, 64, 30, "No", { kind = (not isYes) and "primary" or "ghost", selected = (not isYes) })
      else
        Layout.drawTextWrapped(desc, 14, detailY + 34, w - 28, { font = "caption", color = theme.textDim })
      end
    else
      Layout.drawText("CLOSE MART", 14, detailY + 12, { font = "headline", color = theme.textMuted, bold = true })
      Layout.drawText("Leave the counter and return to the shop floor.", 14, detailY + 38, { font = "caption", color = theme.textDim })
    end
  else
    -- =========================================================================
    -- LANDSCAPE / STANDARD 2-PANEL LAYOUT
    -- =========================================================================
    local bodyH = h - 96
    local lw = math.floor(w * 0.54)
    Layout.drawCard(0, 52, lw, bodyH, { color = theme.surface, borderColor = theme.border, radius = 8 })

    local rowH = 40
    local visibleCount = math.max(1, math.floor((bodyH - 24) / (rowH + 4)))

    if curIdx <= scroll then
      scroll = curIdx - 1
    elseif curIdx > scroll + visibleCount then
      scroll = curIdx - visibleCount
    end
    scroll = math.max(0, math.min(math.max(0, #items - visibleCount), scroll))
    if not hoennList then state.scroll = scroll end

    local itemW = (#items > visibleCount) and (lw - 28) or (lw - 16)

    for r = 1, visibleCount do
      local idx = scroll + r
      local it = asShopItem(items[idx], game, state, halfPrice)
      if it then
        local isSel = (curIdx == idx)
        local iy = 62 + (r - 1) * (rowH + 4)

        if isSel then
          Layout.drawCard(8, iy, itemW, rowH, {
            color = theme.accentDark,
            borderColor = theme.borderStrong,
            borderWidth = 2,
            radius = 6,
          })
        else
          Layout.drawSlot(8, iy, itemW, rowH, {
            color = theme.surfaceHigh,
            borderColor = theme.border,
            borderWidth = 1,
            radius = 6,
          })
        end

        local name = it.label or it.name or it.id or "ITEM"
        Layout.drawText(name, 20, iy + 10, {
          font = "button",
          color = isSel and theme.heading or theme.text,
          bold = isSel,
        })

        local price = it.price or (it.def and it.def.price)
        if price then
          local pStr = (type(price) == "number") and ("¥%d"):format(price) or tostring(price)
          local pBadgeW = Layout.textWidth(pStr, "tiny") + 16
          local badgeX = 8 + itemW - pBadgeW - 8
          Layout.drawBadge(badgeX, iy + 8, pStr, { kind = isSel and "good" or "ghost", font = "tiny", width = pBadgeW })
        end
      end
    end

    if #items > visibleCount then
      Layout.drawScrollBar(lw - 14, 62, 6, bodyH - 24, #items, visibleCount, scroll)
    end

    -- 3. Right Item Preview & Action Panel
    local rx = lw + 12
    local rw = w - rx
    Layout.drawCard(rx, 52, rw, bodyH, { color = theme.surface, borderColor = theme.border, radius = 8 })

    local curItem = asShopItem(items[curIdx], game, state, halfPrice)
    if curItem and not curItem.cancel then
      local name = curItem.label or curItem.name or curItem.id or "ITEM"
      Layout.drawText(name, rx + 18, 66, { font = "headline", color = theme.heading, bold = true })

      local price = curItem.price or (curItem.def and curItem.def.price) or 0
      if not curItem.choice then
        Layout.drawBadge(rx + rw - 110, 66, priceEach(price), { kind = "ghost" })
      end

      local itemId = curItem.value or curItem.id
      local def = (curItem.def) or (itemId and game.data and game.data.items and game.data.items[itemId])
      local desc = (def and def.description) or (curItem.description) or "Standard merchandise available at the Poké Mart."
      if type(desc) == "table" then desc = table.concat(desc, " ") end

      local descH = 120
      Layout.drawSlot(rx + 14, 100, rw - 28, descH, { color = theme.surfaceHigh, borderColor = theme.border, radius = 6 })
      Layout.drawTextWrapped(desc, rx + 26, 114, rw - 52, { font = "body", color = theme.textDim })

      local isQty = (mode == "buy_qty" or mode == "sell_qty" or phase == "qty" or state.isQuantityBox or (subState and (subState.qty ~= nil or subState.isQuantityBox)))
      local activeQty = (subState and subState.qty) or state.qty or qty
      if isQty then
        local qtyY = 100 + descH + 12
        local qtyH = 80
        Layout.drawCard(rx + 14, qtyY, rw - 28, qtyH, {
          color = theme.surfaceHigh,
          borderColor = theme.borderStrong,
          borderWidth = 1,
          radius = 8,
        })
        Layout.drawText("SELECT QUANTITY", rx + 26, qtyY + 12, { font = "caption", color = theme.textDim, bold = true })
        Layout.drawText(("x%02d"):format(activeQty), rx + 26, qtyY + 36, { font = "headline", color = theme.heading, bold = true })

        local itemPrice = priceNumber(curItem.price or (def and def.price) or 0)
        local totalCost = itemPrice * activeQty
        Layout.drawBadge(rx + rw - 140, qtyY + 38, ("TOTAL: ¥%d"):format(totalCost), { kind = (totalCost <= money) and "good" or "danger" })
      end

      local isConfirm = (mode == "buy_confirm" or mode == "sell_confirm" or phase == "confirm" or (subState and (subState.labels or subState.choices or (subState.onChoose and not subState.items))))
      local activeYesNoCursor = (subState and subState.index) or state.yesNoCursor or state.yesCursor or yesNoCursor
      if isConfirm then
        local confY = 100 + descH + 12
        local confH = 80
        Layout.drawCard(rx + 14, confY, rw - 28, confH, {
          color = theme.surfaceHigh,
          borderColor = theme.borderStrong,
          borderWidth = 1,
          radius = 8,
        })
        Layout.drawText("Confirm transaction?", rx + 26, confY + 14, { font = "body", color = theme.heading, bold = true })

        local isYes = (activeYesNoCursor == 1)
        local btnW = 80
        local btnH = 34
        local btnY = confY + 36

        Layout.drawButton(rx + 26, btnY, btnW, btnH, "Yes", {
          kind = isYes and "primary" or "ghost",
          selected = isYes,
        })

        Layout.drawButton(rx + 116, btnY, btnW, btnH, "No", {
          kind = (not isYes) and "primary" or "ghost",
          selected = (not isYes),
        })
      end
    else
      Layout.drawText("CLOSE MART", rx + 18, 66, { font = "headline", color = theme.textMuted, bold = true })
      Layout.drawSlot(rx + 14, 100, rw - 28, 80, { color = theme.surfaceHigh, borderColor = theme.border, radius = 6 })
      Layout.drawText("Leave the counter and return to the shop floor.", rx + 26, 126, { font = "caption", color = theme.textDim })
    end
  end

  -- 4. Bottom Button Hints Footer Bar
  local hints
  if phase == "root" then
    hints = {
      { key = "▲ ▼", label = "Choose", primary = true },
      { key = "A", label = "Select" },
      { key = "B", label = "Leave" },
    }
  elseif phase == "buy_qty" or phase == "qty" then
    hints = {
      { key = "▲ ▼", label = "Amount", primary = true },
      { key = "◄ ►", label = "By 10" },
      { key = "A", label = "Confirm" },
      { key = "B", label = "Back" },
    }
  elseif phase == "buy_confirm" or phase == "confirm" then
    hints = {
      { key = "◄ ►", label = "Yes / No", primary = true },
      { key = "A", label = "Confirm" },
      { key = "B", label = "Back" },
    }
  else
    hints = {
      { key = "▲ ▼", label = "Select Item", primary = true },
      { key = "A", label = "Buy / Confirm" },
      { key = "B", label = "Exit Mart" },
    }
  end
  Layout.drawHintBar(0, footY, w, 36, hints, { paddingX = isNarrow and 8 or 16, gap = isNarrow and 10 or 20 })

  if state._status and (phase == "root" or phase == "buy_qty" or phase == "qty" or phase == "buy_confirm" or phase == "confirm" or phase == "buy_msg" or phase == "msg") then
    local choosing = phase == "root" or phase == "buy_qty" or phase == "qty" or phase == "buy_confirm" or phase == "confirm"
    drawClerkSpeech(game, state, w, h, theme, choosing)
    if phase == "buy_qty" or phase == "qty" then
      local pending = state._pending
      local offer = asShopItem((pending and pending.id) or items[curIdx], game, state, halfPrice)
      local unit = (pending and tonumber(pending.price)) or (offer and tonumber(offer.price)) or 0
      local itemId = (pending and pending.id) or (offer and (offer.value or offer.id)) or state._itemId
      local activeQty = (subState and subState.qty) or state.qty or qty
      drawQtyChooser(state, w, h, theme, money, activeQty, unit, itemId)
    end
  end
end

return ShopRenderer
