-- OmniUI Bag Menu Renderer
-- Multi-pocket inventory browser with item details, ItemDatabase descriptions,
-- vector typography, usable action menus, Mart Sell support, and orientation adaptability.

local Layout = require("mods.omni_ui.core.Layout")
local AdapterResolver = require("mods.omni_ui.adapters.AdapterResolver")
local ItemDatabase = require("mods.omni_ui.core.ItemDatabase")

local BagRenderer = {}

-- Pocket rows use count, qty, or quantity depending on the generation.
function BagRenderer.stackCount(item)
  if type(item) ~= "table" then return nil end
  return tonumber(item.count or item.qty or item.quantity or item.right or item.displayValue)
end

function BagRenderer.draw(game, state, w, h, theme, subState, animProgress)
  local adapter = AdapterResolver.resolve(game)
  local playerInfo = adapter:getPlayerInfo()

  local ctx = Layout.getContext(w, h)
  local isNarrow = (w < 540) or ctx.isPortrait

  local isSellMode = (state.location == "shop" or state.mode == "sell" or state.sellMode or state._sellMode or (state.dialogue and state.money ~= nil))
  local money = playerInfo.money
  if state.money and type(state.money) == "function" then
    local ok, m = pcall(state.money)
    if ok and m then money = m end
  elseif state._session and state._session.money then
    money = state._session.money
  end

  local isGen2Pack = (state.isPackMenu or state.pocketIndex ~= nil or state.pocketItems ~= nil or state.staleRows ~= nil or (type(state.rows) == "table" and not state.party))
  local POCKET_LABELS = {
    items = "ITEMS",
    balls = "BALLS",
    key = "KEY ITEMS",
    tmhm = "TMs & HMs",
    berries = "BERRIES",
    ITEM = "ITEMS",
    BALL = "BALLS",
    KEY_ITEM = "KEY ITEMS",
    TM_HM = "TMs & HMs",
  }

  local pockets = nil
  if isGen2Pack then
    pockets = {
      { id = "ITEM", label = "ITEMS" },
      { id = "BALL", label = "BALLS" },
      { id = "KEY_ITEM", label = "KEY ITEMS" },
      { id = "TM_HM", label = "TMs & HMs" },
    }
  elseif state.__pocketIds and type(state.__pocketIds) == "table" and #state.__pocketIds > 0 then
    pockets = {}
    for _, pid in ipairs(state.__pocketIds) do
      pockets[#pockets + 1] = { id = pid, label = POCKET_LABELS[pid] or pid:upper() }
    end
  elseif state.pockets and type(state.pockets) == "table" and #state.pockets > 0 then
    pockets = state.pockets
  elseif adapter and adapter.getBagPockets then
    pockets = adapter:getBagPockets()
  else
    pockets = {
      { id = "items", label = "ITEMS" },
      { id = "balls", label = "BALLS" },
      { id = "key",   label = "KEY ITEMS" },
      { id = "tmhm",  label = "TMs & HMs" },
    }
  end
  local pocketIdx = state.pocketIndex or state.__pocketIndex or state.pocketIdx or 1

  -- 1. Top Pocket Tab Bar / Header
  Layout.drawCard(0, 0, w, 44, { color = theme.surface, borderColor = theme.border, radius = 8 })
  if isSellMode and not state.pockets and not state.__pocketIds then
    Layout.drawText("SELL FROM BAG", 18, 12, { font = "headline", color = theme.heading, bold = true })
    Layout.drawBadge(w - 180, 12, ("FUNDS: ¥%d"):format(money), { kind = "good" })
  else
    local tabW = math.floor((w - 24) / #pockets)
    for i, p in ipairs(pockets) do
      local rawLabel = type(p) == "table" and (p.label or p.id) or tostring(p):upper()
      local isCur = (pocketIdx == i)
      local tx = 12 + (i - 1) * tabW
      local label = rawLabel
      if tabW < 100 or isNarrow then
        label = label:gsub("^KEY ITEMS", "KEY"):gsub("^TMs & HMs", "TM/HM"):gsub("^BERRIES", "BERRY")
      end
      Layout.drawButton(tx, 7, tabW - 6, 30, label, {
        kind = isCur and "accent" or "ghost",
        selected = isCur,
        font = "caption",
      })
    end
    if isSellMode and not isNarrow then
      Layout.drawBadge(w - 160, 12, ("¥%d"):format(money), { kind = "good" })
    end
  end

  local footY = h - 38
  local curPocketId = pockets[pocketIdx] and pockets[pocketIdx].id
  local items = nil
  if state.__omniPocketView then
    items = state.__omniPocketItems or {}
  else
    items = (isGen2Pack and state.rows)
      or (state.items and #state.items > 0 and state.items)
  end
  if not items or #items == 0 then
    if state.list and type(state.list) == "function" then
      local okL, resL = pcall(state.list, curPocketId)
      if okL and resL and type(resL) == "table" and #resL > 0 then
        items = resL
      end
    end
  end
  if not items or #items == 0 then
    if pockets[pocketIdx] and pockets[pocketIdx].items and #pockets[pocketIdx].items > 0 then
      items = pockets[pocketIdx].items
    elseif adapter and adapter.getBagItems then
      items = adapter:getBagItems(curPocketId)
    end
  end
  items = items or {}
  if adapter and adapter.generation == 2 and adapter.presentBagItem then
    local shown = {}
    for i = 1, #items do
      shown[i] = adapter:presentBagItem(items[i])
    end
    items = shown
  end
  local function powerText(item)
    local p = item and item.power
    if type(p) ~= "number" or p <= 0 then return "--" end
    return tostring(p)
  end
  local function accuracyText(item, withPercent)
    local a = item and item.accuracy
    if type(a) ~= "number" or a <= 0 then return "--" end
    if withPercent then return tostring(a) .. "%" end
    return tostring(a)
  end
  local function itemText(curItem, itemId, def)
    local own = curItem and (curItem.description or curItem.desc)
    if type(own) == "string" then
      own = own:gsub("\\n", " "):gsub("\n", " "):gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
      if own ~= "" then return own end
    end
    return ItemDatabase.getDescription(itemId, def, game)
  end
  local function itemPrice(curItem, def)
    local price = def and tonumber(def.price)
    if price and price > 0 then return price end
    local info = curItem and curItem.info
    price = info and tonumber(info.price)
    if price and price > 0 then return price end
    return 0
  end
  -- Gen 3 pocket rows store the stack on `qty`. The list badge already reads
  -- that field; the detail panel has to use the same one.
  local function heldQty(item)
    return BagRenderer.stackCount(item)
  end
  -- Gen 3 bag lists are one row longer than the pocket. That last row is
  -- Cancel, so one-handed play (L confirms) can leave the bag from the list.
  local isGen3Bag = adapter and adapter.generation == 3 and (
    state.POCKET_KEYS ~= nil or type(state.list) == "function" or type(state.currentPocket) == "function"
  )
  if isGen3Bag then
    local shown = {}
    for i = 1, #items do shown[i] = items[i] end
    local last = shown[#shown]
    local lastLabel = type(last) == "table" and tostring(last.label or last.name or last.id or ""):upper() or ""
    if not (type(last) == "table" and (last.cancel or lastLabel == "CANCEL")) then
      shown[#shown + 1] = { cancel = true, label = "CANCEL" }
    end
    items = shown
  end
  local curIdx = state.hollowIndex or (state.items and state.items.hollowIndex) or state.cursor or state.index or 1

  -- Gen 3 carts move the cursor inside a short window (FRLG shows 6 rows)
  -- and raise `scroll` to reach later entries. The overlay window is taller,
  -- so clamping that scroll to "already on screen" and writing it back froze
  -- the cursor after the first pocket's worth of rows.
  local function viewScroll(count, visibleCount)
    local scroll = state.scroll or 0
    if curIdx <= scroll then
      scroll = math.max(0, curIdx - 1)
    elseif curIdx > scroll + visibleCount then
      scroll = curIdx - visibleCount
    end
    scroll = math.max(0, math.min(math.max(0, count - visibleCount), scroll))
    if not isGen3Bag then
      state.scroll = scroll
    end
    return scroll
  end

  if not isNarrow then
    -- =========================================================================
    -- LANDSCAPE / STANDARD 2-PANEL LAYOUT
    -- =========================================================================
    local bodyH = footY - 54
    local lw = math.floor(w * 0.52)
    Layout.drawCard(0, 50, lw, bodyH, { color = theme.surface, borderColor = theme.border, radius = 8 })

    local rowH = 38
    local visibleCount = math.max(1, math.floor((bodyH - 20) / (rowH + 4)))

    local scroll = viewScroll(#items, visibleCount)

    local itemW = (#items > visibleCount) and (lw - 26) or (lw - 16)

    for r = 1, visibleCount do
      local idx = scroll + r
      local item = items[idx]
      if item then
        local isSel = (curIdx == idx)
        local iy = 58 + (r - 1) * (rowH + 4)
        local label = item.label or item.name or item.id or "ITEM"
        local count = item.count or item.qty or item.quantity or item.right or item.displayValue

        local offsetX = Layout.getCascadeOffset(r, animProgress, 0.022, 18)
        love.graphics.push()
        if offsetX ~= 0 then love.graphics.translate(offsetX, 0) end

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

        if item.isTM or item.teaches then
          local tmTag = item.tmLabel or item.id or "TM"
          local mName = item.moveName or item.label or item.id
          Layout.drawText(tmTag .. " " .. mName, 18, iy + 4, { font = "caption", color = isSel and theme.heading or theme.text, bold = true })
          if item.moveType then
            local Widgets = require("mods.omni_ui.core.Widgets")
            Widgets.drawTypeBadge(item.moveType, 18, iy + 19)
          end
          local pwrAcc = ("PWR %s  ACC %s"):format(powerText(item), accuracyText(item))
          Layout.drawText(pwrAcc, 84, iy + 21, { font = "tiny", color = theme.textDim })
          if count and tostring(count) ~= "" then
            local cntStr = "x" .. tostring(count)
            local cntW = Layout.textWidth(cntStr, "tiny") + 16
            Layout.drawBadge(8 + itemW - cntW - 8, iy + 8, cntStr, { kind = isSel and "good" or "ghost", font = "tiny", width = cntW })
          end
        else
          Layout.drawText(label, 18, iy + 9, { font = "button", color = isSel and theme.heading or theme.text, bold = isSel or item.cancel })
          if item.cancel then
            Layout.drawText("Close the bag", 18, iy + 24, { font = "tiny", color = theme.textDim })
          elseif count and tostring(count) ~= "" then
            local cntStr = "x" .. tostring(count)
            local cntW = Layout.textWidth(cntStr, "tiny") + 16
            Layout.drawBadge(8 + itemW - cntW - 8, iy + 7, cntStr, { kind = isSel and "good" or "ghost", font = "tiny", width = cntW })
          end
        end

        love.graphics.pop()
      end
    end

    if #items > visibleCount then
      Layout.drawScrollBar(lw - 12, 58, 5, bodyH - 16, #items, visibleCount, scroll)
    end

    -- Item Detail Preview Panel (Right Side)
    local rx = lw + 12
    local rw = w - rx
    Layout.drawCard(rx, 50, rw, bodyH, { color = theme.surface, borderColor = theme.border, radius = 8 })

    local curItem = items[curIdx]
    if curItem and not curItem.cancel then
      local label = curItem.label or curItem.name or curItem.id or "ITEM"
      local itemId = curItem.value or curItem.id
      local def = (curItem.def) or (itemId and game.data and game.data.items and game.data.items[itemId])
      local isKeyed = (def and def.keyItem) or (itemId and type(itemId) == "string" and itemId:find("^HM_") ~= nil)

      if curItem.isTM or curItem.teaches then
        local tmTag = curItem.tmLabel or curItem.id or "TM"
        local mName = curItem.moveName or curItem.label or curItem.id
        Layout.drawText(tmTag .. ": " .. mName, rx + 18, 64, { font = "headline", color = theme.heading, bold = true })
        if curItem.moveType then
          local Widgets = require("mods.omni_ui.core.Widgets")
          Widgets.drawTypeBadge(curItem.moveType, rx + rw - 84, 62)
        else
          Layout.drawBadge(rx + rw - 110, 64, "TECH MACHINE", { kind = "primary" })
        end

        local desc = itemText(curItem, itemId, def)
        local descH = 92
        Layout.drawSlot(rx + 14, 96, rw - 28, descH, { color = theme.surfaceHigh, borderColor = theme.border, radius = 6 })
        Layout.drawTextWrapped(desc, rx + 24, 108, rw - 48, { font = "body", color = theme.textDim })

        local specSlotY = 96 + descH + 10
        local specSlotH = 64
        Layout.drawSlot(rx + 14, specSlotY, rw - 28, specSlotH, { color = theme.surfaceHigh, borderColor = theme.border, radius = 6 })

        local colW = math.floor((rw - 36) / 3)
        Layout.drawStatMetric(rx + 18, specSlotY + 10, colW, powerText(curItem), "power")
        Layout.drawStatMetric(rx + 18 + colW, specSlotY + 10, colW, accuracyText(curItem, true), "accuracy")
        Layout.drawStatMetric(rx + 18 + colW * 2, specSlotY + 10, colW, ("x %02d"):format(heldQty(curItem) or 1), "in bag")
      else
        Layout.drawText(label, rx + 18, 64, { font = "headline", color = theme.heading, bold = true })

        local categoryTag = "GENERAL ITEM"
        local catKind = "ghost"
        if isKeyed then
          categoryTag = "KEY ITEM"
          catKind = "gold"
        elseif label:find("BALL") then
          categoryTag = "POKÉ BALL"
          catKind = "good"
        elseif label:find("POTION") or label:find("HEAL") or label:find("RESTORE") or label:find("REVIVE") or label:find("CANDY") then
          categoryTag = "MEDICINE"
          catKind = "team"
        elseif label:find("^TM") or label:find("^HM") then
          categoryTag = "TECH MACHINE"
          catKind = "primary"
        elseif label:find("STONE") or label:find("FOSSIL") then
          categoryTag = "EVOLUTION"
          catKind = "accent"
        end

        if isSellMode then
          if isKeyed then
            Layout.drawBadge(rx + rw - 110, 64, "UNSELLABLE", { kind = "danger" })
          else
            local unitPrice = math.floor(((def and def.price) or 0) / 2)
            Layout.drawBadge(rx + rw - 110, 64, ("¥%d EACH"):format(unitPrice), { kind = "good" })
          end
        else
          Layout.drawBadge(rx + rw - 120, 64, categoryTag, { kind = catKind })
        end

        local desc = itemText(curItem, itemId, def)
        local descH = 92
        Layout.drawSlot(rx + 14, 96, rw - 28, descH, { color = theme.surfaceHigh, borderColor = theme.border, radius = 6 })
        Layout.drawTextWrapped(desc, rx + 24, 108, rw - 48, { font = "body", color = theme.textDim })

        local specSlotY = 96 + descH + 10
        local specSlotH = 64
        Layout.drawSlot(rx + 14, specSlotY, rw - 28, specSlotH, { color = theme.surfaceHigh, borderColor = theme.border, radius = 6 })

        local qty = heldQty(curItem)
        local countStr = (qty and ("x %02d"):format(qty)) or (isKeyed and "UNIQUE") or "x 01"
        local sellPrice = math.floor(itemPrice(curItem, def) / 2)
        local valStr = isKeyed and "NO SALE" or (sellPrice > 0 and ("¥%d"):format(sellPrice) or "¥0")
        local colW = math.floor((rw - 36) / 2)

        Layout.drawStatMetric(rx + 18, specSlotY + 10, colW, countStr, "held count")
        Layout.drawStatMetric(rx + 18 + colW, specSlotY + 10, colW, valStr, "sell value")
      end
    elseif curItem and curItem.cancel then
      Layout.drawText("CANCEL", rx + 18, 64, { font = "headline", color = theme.heading, bold = true })
      Layout.drawTextWrapped("Close the bag and return to the field.", rx + 18, 96, rw - 36, { font = "body", color = theme.textDim })
    else
      Layout.drawText("NO ITEM SELECTED", rx + 18, 64, { font = "caption", color = theme.textMuted })
    end
  else
    -- =========================================================================
    -- PORTRAIT / COMPACT MOBILE DOCKED DRAWER LAYOUT
    -- =========================================================================
    local detailH = 100
    local listH = footY - 50 - detailH - 8
    Layout.drawCard(0, 50, w, listH, { color = theme.surface, borderColor = theme.border, radius = 8 })

    local rowH = 34
    local visibleCount = math.max(1, math.floor((listH - 16) / (rowH + 3)))

    local scroll = viewScroll(#items, visibleCount)

    local itemW = w - 16

    for r = 1, visibleCount do
      local idx = scroll + r
      local item = items[idx]
      if item then
        local isSel = (curIdx == idx)
        local iy = 56 + (r - 1) * (rowH + 3)
        local label = item.label or item.name or item.id or "ITEM"
        local count = item.count or item.qty or item.quantity or item.right or item.displayValue

        if isSel then
          Layout.drawCard(8, iy, itemW, rowH, {
            color = theme.accentDark,
            borderColor = theme.borderStrong,
            borderWidth = 2,
            radius = 6,
          })
          Layout.drawText(label, 16, iy + 8, { font = "caption", color = theme.heading, bold = true })
          if count and tostring(count) ~= "" then
            local cntStr = "x" .. tostring(count)
            Layout.drawBadge(w - 56, iy + 6, cntStr, { kind = "good", font = "tiny" })
          end
        else
          Layout.drawSlot(8, iy, itemW, rowH, {
            color = theme.surfaceHigh,
            borderColor = theme.border,
            borderWidth = 1,
            radius = 6,
          })
          Layout.drawText(label, 16, iy + 8, { font = "caption", color = theme.text, bold = item.cancel })
          if count and tostring(count) ~= "" and not item.cancel then
            local cntStr = "x" .. tostring(count)
            Layout.drawBadge(w - 56, iy + 6, cntStr, { kind = "ghost", font = "tiny" })
          end
        end
      end
    end

    -- Docked Item Preview Drawer
    local detailY = 50 + listH + 6
    Layout.drawCard(0, detailY, w, detailH, { color = theme.surface, borderColor = theme.border, radius = 8 })

    local curItem = items[curIdx]
    if curItem and not curItem.cancel then
      local label = curItem.label or curItem.name or curItem.id or "ITEM"
      Layout.drawText(label, 14, detailY + 8, { font = "headline", color = theme.heading, bold = true })

      local itemId = curItem.value or curItem.id
      local def = (curItem.def) or (itemId and game.data and game.data.items and game.data.items[itemId])
      local desc = itemText(curItem, itemId, def)

      Layout.drawTextWrapped(desc, 14, detailY + 30, w - 28, { font = "caption", color = theme.textDim })
    elseif curItem and curItem.cancel then
      Layout.drawText("CANCEL", 14, detailY + 8, { font = "headline", color = theme.heading, bold = true })
      Layout.drawText("Close the bag.", 14, detailY + 32, { font = "caption", color = theme.textDim })
    else
      Layout.drawText("No item selected", 14, detailY + 14, { font = "caption", color = theme.textMuted })
    end
  end

  -- 4. Interactive Modal SubState Overlays (Item Actions / Quantity Selector / Confirm / Choice / Message)
  local isGen2Submenu = (type(state.submenu) == "table" and ((state.submenu.rows and #state.submenu.rows > 0) or (state.submenu.items and #state.submenu.items > 0)))
  local isGen2Qty = (state.qtyState and state.qtyState.qty ~= nil)
  local isGen2Confirm = (state.confirm and (state.confirm.prompt ~= nil or state.confirm.onYes ~= nil))

  local isG3Deposit = (state.mode == "deposit")
  local isG3Toss = (state.mode == "toss")
  local isG3TossConfirm = (state.mode == "toss_confirm")
  local isG3DepositDone = (state.mode == "deposit_done" and (state._depositText ~= nil or state._depositPending ~= nil))

  local isSubQty = isGen2Qty or isG3Deposit or isG3Toss
      or (subState and (subState.isQuantityBox or subState.qty ~= nil or (subState.max ~= nil and subState.unitPrice ~= nil)))
  local isSubChoice = (subState and (subState.isChoiceBox or (subState.labels and subState.onChoose) or subState.choices or (subState.options and subState.active)))
  local isSubAction = isGen2Submenu
      or (state.mode == "action" and state.ACTIONS ~= nil)
      or (subState and subState ~= state and subState.items and type(subState.items) == "table" and #subState.items > 0 and not isSubQty and not isSubChoice)
      or (state.optionBox and state.optionBox.items and #state.optionBox.items > 0)
      or (type(state.submenu) == "table" and state.submenu.items and #state.submenu.items > 0)

  local isConfirm = isGen2Confirm or isG3TossConfirm
  local isMessage = isG3DepositDone or (state.mode == "message" and state.message)

  if isSubAction then
    local actionMenu = (isGen2Submenu and state.submenu)
        or (subState and subState ~= state and subState.items and subState)
        or state.optionBox
        or state.submenu
    local actionItems = (state.mode == "action" and state.ACTIONS)
        or (actionMenu and (actionMenu.rows or actionMenu.items))
        or {}
    local actionCur = (state.mode == "action" and state.actionCursor)
        or (actionMenu and actionMenu.index)
        or 1
    -- RSE action grids leave false holes. Drop those so Cancel stays the last
    -- real choice and the cursor still lands on it.
    if type(actionItems) == "table" then
      local rows = {}
      local visualCur = nil
      for i, act in ipairs(actionItems) do
        if act ~= false and act ~= nil then
          rows[#rows + 1] = act
          if i == actionCur then visualCur = #rows end
        end
      end
      actionItems = rows
      actionCur = visualCur or 0
    end

    -- Dimmed scrim backdrop for modal focus
    love.graphics.setColor(0, 0, 0, 0.45)
    love.graphics.rectangle("fill", 0, 0, w, h)
    love.graphics.setColor(1, 1, 1, 1)

    local curItem = items[curIdx]
    local itemName = curItem and (curItem.label or curItem.name or curItem.id) or "ITEM"
    local count = heldQty(curItem)

    local modalW = isNarrow and math.min(w - 32, 280) or 260
    local itemH = 38
    local itemGap = 6
    local headerH = 46
    local modalH = headerH + #actionItems * (itemH + itemGap) + 12

    local modalX = math.floor((w - modalW) / 2)
    local modalY = math.floor((h - modalH) / 2)

    -- Container Card
    Layout.drawCard(modalX, modalY, modalW, modalH, {
      color = theme.surface,
      borderColor = theme.borderStrong,
      borderWidth = 2,
      radius = 10,
    })

    -- Header
    Layout.drawText(itemName, modalX + 16, modalY + 12, { font = "headline", color = theme.heading, bold = true, width = modalW - 90 })
    if count and tostring(count) ~= "" then
      local cntStr = "x" .. tostring(count)
      local cntW = Layout.textWidth(cntStr, "tiny") + 16
      Layout.drawBadge(modalX + modalW - cntW - 14, modalY + 12, cntStr, { kind = "good", font = "tiny", width = cntW })
    else
      Layout.drawBadge(modalX + modalW - 74, modalY + 12, "ACTIONS", { kind = "accent", font = "tiny", width = 60 })
    end
    Layout.drawDivider(modalX + 12, modalY + 40, modalW - 24, theme.border)

    -- Action Options List
    for ai, act in ipairs(actionItems) do
      local isSel = (actionCur == ai)
      local ay = modalY + headerH + 4 + (ai - 1) * (itemH + itemGap)
      local rawLabel = type(act) == "table" and (act.label or act.name or act[1]) or tostring(act)
      local label = tostring(rawLabel):upper()

      if isSel then
        Layout.drawCard(modalX + 12, ay, modalW - 24, itemH, {
          color = theme.accentDark,
          borderColor = theme.borderStrong,
          borderWidth = 2,
          radius = 6,
        })
        Layout.drawText(label, modalX + 24, ay + 9, { font = "button", color = theme.heading, bold = true })
        Layout.drawBadge(modalX + modalW - 68, ay + 8, "SELECT", { kind = "accent", font = "tiny", width = 52 })
      else
        Layout.drawSlot(modalX + 12, ay, modalW - 24, itemH, {
          color = theme.surfaceHigh,
          borderColor = theme.border,
          borderWidth = 1,
          radius = 6,
        })
        Layout.drawText(label, modalX + 24, ay + 9, { font = "button", color = theme.text })
      end
    end
  elseif isSubQty then
    -- Dimmed scrim backdrop
    love.graphics.setColor(0, 0, 0, 0.45)
    love.graphics.rectangle("fill", 0, 0, w, h)
    love.graphics.setColor(1, 1, 1, 1)

    local curItem = (state.qtyState and state.qtyState.row)
        or (state.list and type(state.list) == "function" and state.cursor and state.list()[state.cursor])
        or items[curIdx]
    local itemName = curItem and (curItem.label or curItem.name or curItem.id) or "ITEM"
    local qty = (state.qtyState and state.qtyState.qty)
        or ((isG3Deposit or isG3Toss) and state.tossQty)
        or (subState and subState.qty)
        or (subState and subState.getQuantity and subState:getQuantity())
        or 1
    local maxQty = (state.qtyState and state.qtyState.max)
        or (curItem and (curItem.qty or curItem.count or curItem.quantity))
        or (subState and subState.max)
        or 99

    local modalW = isNarrow and math.min(w - 32, 280) or 280
    local modalH = (subState and subState.unitPrice) and 140 or 118
    local modalX = math.floor((w - modalW) / 2)
    local modalY = math.floor((h - modalH) / 2)

    Layout.drawCard(modalX, modalY, modalW, modalH, {
      color = theme.surface,
      borderColor = theme.borderStrong,
      borderWidth = 2,
      radius = 10,
    })

    local title = isG3Deposit and "DEPOSIT HOW MANY?" or (isG3Toss and "TOSS HOW MANY?" or "HOW MANY?")
    Layout.drawText(title, modalX + 16, modalY + 12, { font = "headline", color = theme.heading, bold = true })
    Layout.drawBadge(modalX + modalW - 84, modalY + 12, ("MAX %d"):format(maxQty), { kind = "accent", font = "tiny", width = 68 })
    Layout.drawDivider(modalX + 12, modalY + 38, modalW - 24, theme.border)

    Layout.drawCard(modalX + 16, modalY + 48, modalW - 32, 48, {
      color = theme.accentDark,
      borderColor = theme.borderStrong,
      borderWidth = 2,
      radius = 6,
    })
    Layout.drawText(("× %02d"):format(qty), modalX + 32, modalY + 58, { font = "headline", color = theme.heading, bold = true })
    Layout.drawText("▲ / ▼ Adjust", modalX + modalW - 116, modalY + 62, { font = "caption", color = theme.colors.accent, bold = true })

    if subState and subState.unitPrice then
      local total = (subState.unitPrice or 0) * qty
      Layout.drawText(("Total: ¥%d"):format(total), modalX + 20, modalY + 108, { font = "caption", color = theme.textDim })
    end
  elseif isConfirm then
    love.graphics.setColor(0, 0, 0, 0.45)
    love.graphics.rectangle("fill", 0, 0, w, h)
    love.graphics.setColor(1, 1, 1, 1)

    local prompt = "Are you sure?"
    local choice = 1
    if isG3TossConfirm then
      local curItem = (state.list and type(state.list) == "function" and state.cursor and state.list()[state.cursor]) or items[curIdx]
      local itemName = curItem and (curItem.label or curItem.name or curItem.id) or "ITEM"
      prompt = ("Throw away %d of %s?"):format(state.tossQty or 1, itemName)
      choice = state.yesNoCursor or 1
    elseif state.confirm then
      local conf = state.confirm
      prompt = conf.prompt and (type(conf.prompt) == "table" and table.concat(conf.prompt, " ") or tostring(conf.prompt)) or "Are you sure?"
      choice = conf.choice or 1
    end

    local modalW = isNarrow and math.min(w - 32, 300) or 320
    local modalH = 130
    local modalX = math.floor((w - modalW) / 2)
    local modalY = math.floor((h - modalH) / 2)

    Layout.drawCard(modalX, modalY, modalW, modalH, {
      color = theme.surface,
      borderColor = theme.borderStrong,
      borderWidth = 2,
      radius = 10,
    })
    Layout.drawTextWrapped(prompt, modalX + 16, modalY + 14, modalW - 32, { font = "body", color = theme.heading, bold = true })
    local btnW = math.floor((modalW - 40) / 2)
    Layout.drawButton(modalX + 16, modalY + 76, btnW, 36, "YES", { kind = (choice == 1) and "primary" or "ghost", selected = (choice == 1) })
    Layout.drawButton(modalX + 24 + btnW, modalY + 76, btnW, 36, "NO", { kind = (choice == 2) and "primary" or "ghost", selected = (choice == 2) })
  elseif isMessage then
    love.graphics.setColor(0, 0, 0, 0.45)
    love.graphics.rectangle("fill", 0, 0, w, h)
    love.graphics.setColor(1, 1, 1, 1)

    local msg = (state.mode == "deposit_done" and state._depositText)
      or tostring(state.message or state._msg or "Done.")
    if type(msg) == "table" then
      msg = table.concat(msg, " ")
    end

    local modalW = isNarrow and math.min(w - 32, 300) or 320
    local modalH = 120
    local modalX = math.floor((w - modalW) / 2)
    local modalY = math.floor((h - modalH) / 2)

    Layout.drawCard(modalX, modalY, modalW, modalH, {
      color = theme.surface,
      borderColor = theme.borderStrong,
      borderWidth = 2,
      radius = 10,
    })
    Layout.drawTextWrapped(msg, modalX + 16, modalY + 16, modalW - 32, { font = "body", color = theme.heading, bold = true })
    Layout.drawButton(modalX + 16, modalY + 70, modalW - 32, 36, "CONTINUE (A)", { kind = "primary", selected = true })
  elseif isSubChoice then
    love.graphics.setColor(0, 0, 0, 0.45)
    love.graphics.rectangle("fill", 0, 0, w, h)
    love.graphics.setColor(1, 1, 1, 1)

    local choiceOpts = (subState and (subState.options or subState.labels or subState.choices)) or {}
    local choiceCur = (subState and (subState.cursor or subState.index or subState.choice)) or 1
    local isYesNo = (#choiceOpts == 2 and choiceOpts[1] and tostring(choiceOpts[1]):upper():find("YES"))
        or (subState and subState.kind == "yesno")

    local modalW = isNarrow and math.min(w - 32, 280) or 260
    local modalX = math.floor((w - modalW) / 2)

    if isYesNo then
      local modalH = 110
      local modalY = math.floor((h - modalH) / 2)
      Layout.drawCard(modalX, modalY, modalW, modalH, {
        color = theme.surface,
        borderColor = theme.borderStrong,
        borderWidth = 2,
        radius = 10,
      })
      Layout.drawText("CHOOSE", modalX + 16, modalY + 12, { font = "headline", color = theme.heading, bold = true })
      local btnW = math.floor((modalW - 40) / 2)
      Layout.drawButton(modalX + 16, modalY + 54, btnW, 36, "YES", { kind = (choiceCur == 1) and "primary" or "ghost", selected = (choiceCur == 1) })
      Layout.drawButton(modalX + 24 + btnW, modalY + 54, btnW, 36, "NO", { kind = (choiceCur == 2) and "primary" or "ghost", selected = (choiceCur == 2) })
    else
      local itemH = 36
      local itemGap = 6
      local headerH = 42
      local modalH = headerH + math.max(1, #choiceOpts) * (itemH + itemGap) + 12
      local modalY = math.floor((h - modalH) / 2)
      Layout.drawCard(modalX, modalY, modalW, modalH, {
        color = theme.surface,
        borderColor = theme.borderStrong,
        borderWidth = 2,
        radius = 10,
      })
      Layout.drawText("CHOOSE", modalX + 16, modalY + 12, { font = "headline", color = theme.heading, bold = true })
      Layout.drawDivider(modalX + 12, modalY + 36, modalW - 24, theme.border)
      for ci, opt in ipairs(choiceOpts) do
        local isSel = (choiceCur == ci)
        local cy = modalY + headerH + 4 + (ci - 1) * (itemH + itemGap)
        local optLbl = type(opt) == "table" and (opt.label or opt.name or opt[1]) or tostring(opt)
        if isSel then
          Layout.drawButton(modalX + 12, cy, modalW - 24, itemH, tostring(optLbl):upper(), { kind = "primary", selected = true })
        else
          Layout.drawSlot(modalX + 12, cy, modalW - 24, itemH, { color = theme.surfaceHigh, borderColor = theme.border })
          Layout.drawText(tostring(optLbl):upper(), modalX + 20, cy + 9, { font = "button", color = theme.text })
        end
      end
    end
  end

  -- Bottom Hints Bar
  local hints
  if isSubAction or isSubQty or isSubChoice or isConfirm then
    hints = {
      { key = "▲ ▼", label = "Select", primary = true },
      { key = "A", label = "Confirm" },
      { key = "B", label = "Cancel" },
    }
  elseif isMessage then
    hints = {
      { key = "A", label = "Continue", primary = true },
    }
  else
    hints = {
      { key = "▲ ▼", label = "Select", primary = true },
      { key = "◄ ►", label = "Pocket" },
      { key = "A", label = isSellMode and "Sell" or "Use" },
      { key = "B", label = "Back" },
    }
  end
  Layout.drawHintBar(0, footY, w, 36, hints, { paddingX = isNarrow and 8 or 16, gap = isNarrow and 10 or 20 })
end

return BagRenderer
