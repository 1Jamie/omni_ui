-- OmniUI Player PC (Item Storage) Renderer
-- Desktop/Console grade unified item storage terminal:
-- Seamlessly browse PC Storage and Bag Inventory with dual-tab switcher,
-- rich item inspector, dynamic category tags, action submenus, quantity steppers,
-- and safe toss confirmation dialogs.

local Layout = require("mods.omni_ui.core.Layout")
local PlayerPcController = require("mods.omni_ui.core.PlayerPcController")
local ItemDatabase = require("mods.omni_ui.core.ItemDatabase")

local PlayerPcRenderer = {}

local function getItemCategory(id, def)
  if not id then return "ITEM" end
  local upper = tostring(id):upper()
  if (def and def.keyItem) or upper:find("^HM_") or upper:find("TICKET") or upper:find("KEY") or upper:find("FLUTE") or upper:find("SCOPE") or upper:find("ROD") or upper:find("CASE") or upper:find("MAP") or upper:find("VOUCHER") or upper:find("PARCEL") then
    return "KEY ITEM"
  elseif upper:find("^TM_") or upper:find("^TM%d") then
    return "TM"
  elseif upper:find("BALL") then
    return "POKÉ BALL"
  elseif upper:find("POTION") or upper:find("HEAL") or upper:find("RESTORE") or upper:find("REVIVE") or upper:find("ANTIDOTE") or upper:find("ETHER") or upper:find("ELIXER") or upper:find("WATER") or upper:find("SODA") or upper:find("LEMONADE") or upper:find("MILK") then
    return "MEDICINE"
  elseif upper:find("BERRY") then
    return "BERRY"
  elseif upper:find("STONE") or upper:find("CANDY") or upper:find("PROTEIN") or upper:find("IRON") or upper:find("CARBOS") or upper:find("CALCIUM") or upper:find("HP_UP") or upper:find("PP_UP") or upper:find("ZINC") then
    return "ENHANCER"
  elseif upper:find("^X_") or upper:find("DIRE_HIT") or upper:find("GUARD_SPEC") or upper:find("POKE_DOLL") then
    return "BATTLE ITEM"
  else
    return "GENERAL"
  end
end

function PlayerPcRenderer.draw(game, state, w, h, theme, subState, animProgress)
  game = game or {}
  state = state or {}

  -- 1. Initialize or Bind Player PC Controller
  if not state.__playerPcController then
    state.__playerPcController = PlayerPcController.new(game, {
      tab = (state.kind == "pc_item_deposit" or state.mode == "deposit") and "bag" or "pc",
    })
  end

  local ctrl = state.__playerPcController
  ctrl:refresh()

  -- If mock items were passed in headless unit tests, safely inject if actual item data (and not root menu choices)
  if state.items and type(state.items) == "table" and #state.items > 0 then
    local first = state.items[1]
    local isRootMenuChoice = (type(first) == "table" and first.label and (
      first.label:find("WITHDRAW") or first.label:find("DEPOSIT") or first.label:find("LOG OFF") or first.label:find("TOSS")
    ))
    if not isRootMenuChoice and type(first) == "table" and (first.id or first.count or first.value) then
      if ctrl.tab == "bag" and #ctrl.bagItems == 0 then
        ctrl.bagItems = state.items
      elseif ctrl.tab == "pc" and #ctrl.pcItems == 0 then
        ctrl.pcItems = state.items
      end
    end
  end

  local items, curIdx, tabName = ctrl:getActiveList()
  local isPcTab = (ctrl.tab == "pc")
  local pcCap = ctrl.maxPcItems or (ctrl.adapter and ctrl.adapter.getPcCapacity and ctrl.adapter:getPcCapacity()) or 50
  local bagCap = ctrl.maxBagItems or (ctrl.adapter and ctrl.adapter.getBagCapacity and ctrl.adapter:getBagCapacity()) or 20
  pcCap = math.max(pcCap, #ctrl.pcItems)
  bagCap = math.max(bagCap, #ctrl.bagItems)
  local maxCap = isPcTab and pcCap or bagCap
  local ctx = Layout.getContext(w, h)
  local isNarrow = (w < 560) or ctx.isPortrait
  local footY = h - 38

  if not isNarrow then
    -- =========================================================================
    -- LANDSCAPE / STANDARD 2-PANEL LAYOUT
    -- =========================================================================
    -- Top Header Card with Integrated Tab Switcher
    Layout.drawCard(0, 0, w, 46, { color = theme.surface, borderColor = theme.border, radius = 8 })
    Layout.drawText("ITEM STORAGE TERMINAL", 18, 13, { font = "headline", color = theme.heading, bold = true })

    local pcTabLabel = ("PC STORAGE (%d/%d)"):format(#ctrl.pcItems, pcCap)
    local bagTabLabel = ("BAG ITEMS (%d/%d)"):format(#ctrl.bagItems, bagCap)
    local tabW = math.max(168, Layout.textWidth(pcTabLabel, "caption") + 28, Layout.textWidth(bagTabLabel, "caption") + 28)
    local tabH = 30
    local tabY = 8
    local tab2X = w - tabW - 16
    local tab1X = tab2X - tabW - 10

    -- Tab 1: PC Storage
    local pcTabSelected = (ctrl.tab == "pc")
    Layout.drawCard(tab1X, tabY, tabW, tabH, {
      color = pcTabSelected and theme.accentDark or theme.surfaceHigh,
      borderColor = pcTabSelected and (theme.colors.accent or theme.borderStrong) or theme.border,
      borderWidth = pcTabSelected and 2 or 1,
      radius = 6,
    })
    Layout.drawText(pcTabLabel, tab1X + 14, tabY + 8, {
      font = "caption",
      color = pcTabSelected and theme.heading or theme.textMuted,
      bold = pcTabSelected,
    })

    -- Tab 2: Bag Inventory
    local bagTabSelected = (ctrl.tab == "bag")
    Layout.drawCard(tab2X, tabY, tabW, tabH, {
      color = bagTabSelected and theme.accentDark or theme.surfaceHigh,
      borderColor = bagTabSelected and (theme.colors.accent or theme.borderStrong) or theme.border,
      borderWidth = bagTabSelected and 2 or 1,
      radius = 6,
    })
    Layout.drawText(bagTabLabel, tab2X + 14, tabY + 8, {
      font = "caption",
      color = bagTabSelected and theme.heading or theme.textMuted,
      bold = bagTabSelected,
    })

    Layout.drawBadge(tab1X - 110, tabY + 3, "◄ / ► TABS", { kind = "ghost", font = "tiny" })

    local bodyH = h - 100
    local leftW = math.floor(w * 0.54)
    local rightX = leftW + 12
    local rightW = w - rightX

    -- Left Storage / Bag List Panel
    Layout.drawCard(0, 54, leftW, bodyH, { color = theme.surface, borderColor = theme.border, radius = 8 })

    local listHeaderTitle = isPcTab and "PC STORED ITEMS" or "BAG INVENTORY ITEMS"
    Layout.drawText(listHeaderTitle, 16, 66, { font = "title", color = theme.heading, bold = true })
    local capBadgeText = ("%d / %d"):format(#items, maxCap)
    local capFont = "caption"
    local capBw = Layout.textWidth(capBadgeText, capFont) + 18
    Layout.drawBadge(leftW - capBw - 16, 64, capBadgeText, {
      kind = (#items >= maxCap) and "danger" or (#items > 0) and "good" or "ghost",
      font = capFont,
      width = capBw,
    })

    local barW = leftW - 32
    local barFraction = math.min(1.0, #items / math.max(1, maxCap))
    Layout.drawProgressBar(16, 92, barW, 4, barFraction, {
      fillColor = (#items >= maxCap) and theme.colors.danger or theme.colors.accent,
      bgColor = theme.surfaceHigh,
    })

    local rowH = 40
    local listStartY = 104
    local listAreaH = bodyH - (listStartY - 54) - 8
    local visibleCount = math.max(1, math.floor(listAreaH / (rowH + 4)))

    local scroll = isPcTab and (ctrl.pcScroll or 0) or (ctrl.bagScroll or 0)
    if curIdx <= scroll then
      scroll = curIdx - 1
    elseif curIdx > scroll + visibleCount then
      scroll = curIdx - visibleCount
    end
    scroll = math.max(0, math.min(math.max(0, #items - visibleCount), scroll))
    if isPcTab then ctrl.pcScroll = scroll else ctrl.bagScroll = scroll end

    local itemW = (#items > visibleCount) and (leftW - 28) or (leftW - 16)

    if #items == 0 then
      local emptyTitle = isPcTab and "NO STORED ITEMS" or "BAG IS EMPTY"
      local emptyDesc = isPcTab and "Deposit items from your Bag to store them safely here.\nUse ◄ / ► to switch to your Bag."
          or "You have no items in your Bag inventory.\nUse ◄ / ► to switch to PC Storage."
      Layout.drawCard(16, listStartY + 10, leftW - 32, 100, { color = theme.surfaceHigh, borderColor = theme.border, radius = 6 })
      Layout.drawText(emptyTitle, 32, listStartY + 26, { font = "title", color = theme.textMuted })
      Layout.drawTextWrapped(emptyDesc, 32, listStartY + 54, leftW - 64, { font = "body", color = theme.textDim })
    else
      for r = 1, visibleCount do
        local idx = scroll + r
        local it = items[idx]
        if it then
          local isSel = (curIdx == idx)
          local iy = listStartY + (r - 1) * (rowH + 4)
          local label = it.label or it.name or it.id or "ITEM"
          local count = it.count or it.qty or it.stack
          local def = it.def or (game.data and game.data.items and (game.data.items[it.id] or game.data.items[it.value]))
          local isKey = (def and def.keyItem) or (type(it.id) == "string" and it.id:find("^HM_"))

          if isSel then
            Layout.drawCard(8, iy, itemW, rowH, {
              color = theme.accentDark,
              borderColor = theme.colors.accent or theme.borderStrong,
              borderWidth = 2,
              radius = 6,
            })
            Layout.drawText(label, 20, iy + 11, { font = "button", color = theme.heading, bold = true })
            if isKey then
              Layout.drawBadge(8 + itemW - 64, iy + 8, "KEY", { kind = "accent", font = "tiny", width = 56 })
            elseif count and tostring(count) ~= "" and not it.cancel then
              local cntStr = "x" .. tostring(count)
              local cntW = math.max(48, Layout.textWidth(cntStr, "tiny") + 16)
              Layout.drawBadge(8 + itemW - cntW - 8, iy + 8, cntStr, { kind = "good", font = "tiny", width = cntW })
            end
          else
            Layout.drawSlot(8, iy, itemW, rowH, {
              color = theme.surfaceHigh,
              borderColor = theme.border,
              borderWidth = 1,
              radius = 6,
            })
            Layout.drawText(label, 20, iy + 11, { font = "button", color = theme.text })
            if isKey then
              Layout.drawBadge(8 + itemW - 64, iy + 8, "KEY", { kind = "ghost", font = "tiny", width = 56 })
            elseif count and tostring(count) ~= "" and not it.cancel then
              local cntStr = "x" .. tostring(count)
              local cntW = math.max(48, Layout.textWidth(cntStr, "tiny") + 16)
              Layout.drawBadge(8 + itemW - cntW - 8, iy + 8, cntStr, { kind = "ghost", font = "tiny", width = cntW })
            end
          end
        end
      end
    end

    if #items > visibleCount then
      Layout.drawScrollBar(leftW - 14, listStartY, 6, listAreaH, #items, visibleCount, scroll)
    end

    -- Right Inspector Panel
    Layout.drawCard(rightX, 54, rightW, bodyH, { color = theme.surface, borderColor = theme.border, radius = 8 })

    local curItem = ctrl:getSelectedItem() or items[curIdx]
    if curItem and not curItem.cancel then
      local label = curItem.label or curItem.name or curItem.id or "ITEM"
      local itemId = curItem.value or curItem.id
      local def = curItem.def or (itemId and game.data and game.data.items and (game.data.items[itemId] or game.data.items[curItem.id]))
      local category = getItemCategory(itemId, def)

      Layout.drawText(label, rightX + 18, 68, { font = "headline", color = theme.heading, bold = true })
      Layout.drawBadge(rightX + rightW - 110, 68, category, { kind = "accent", font = "tiny" })

      local desc = ItemDatabase.getDescription(itemId, def, game)
      local descH = 144
      Layout.drawSlot(rightX + 16, 98, rightW - 32, descH, { color = theme.surfaceHigh, borderColor = theme.border, radius = 6 })
      Layout.drawText("ITEM DESCRIPTION", rightX + 26, 108, { font = "caption", color = theme.colors.accent, bold = true })
      Layout.drawTextWrapped(desc, rightX + 26, 132, rightW - 52, { font = "body", color = theme.text })

      local statY = 98 + descH + 12
      local statH = bodyH + 54 - statY - 14
      Layout.drawSlot(rightX + 16, statY, rightW - 32, statH, { color = theme.surfaceHigh, borderColor = theme.border, radius = 6 })
      Layout.drawText("STORAGE & ITEM STATUS", rightX + 26, statY + 12, { font = "caption", color = theme.colors.accent, bold = true })

      local stackCount = curItem.count or curItem.stack or 1
      local isKey = (def and def.keyItem) or (type(curItem.id) == "string" and curItem.id:find("^HM_"))
      local locStr = isPcTab and ("Location: PC Storage (%d / %d slots)"):format(#ctrl.pcItems, pcCap)
          or ("Location: Bag Inventory (%d / %d slots)"):format(#ctrl.bagItems, bagCap)

      Layout.drawText(locStr, rightX + 26, statY + 36, { font = "caption", color = theme.heading })

      local qtyDesc = isKey and "Item Stack: Unique Key Item" or ("Current Stack: x%02d"):format(stackCount)
      Layout.drawText(qtyDesc, rightX + 26, statY + 60, { font = "caption", color = theme.textDim })

      local price = def and def.price
      local priceStr = (price and price > 0) and ("Sell Value: ¥%d"):format(math.floor(price / 2)) or "Sell Value: Non-sellable"
      Layout.drawText(priceStr, rightX + 26, statY + 84, { font = "caption", color = theme.textDim })

      local tossPolicy = isKey and "Key Item • Cannot Discard" or "Standard Item • Discardable"
      Layout.drawBadge(rightX + 26, statY + 112, tossPolicy, {
        kind = isKey and "danger" or "ghost",
        font = "tiny",
        height = 24,
      })
    else
      Layout.drawText("NO ITEM SELECTED", rightX + 18, 68, { font = "headline", color = theme.textMuted })
      Layout.drawSlot(rightX + 16, 98, rightW - 32, 140, { color = theme.surfaceHigh, borderColor = theme.border, radius = 6 })
      Layout.drawText("Select an item from the list on the left to view its description and storage details.", rightX + 26, 118, {
        font = "body",
        color = theme.textDim,
        width = rightW - 52,
      })
    end
  else
    -- =========================================================================
    -- PORTRAIT / COMPACT MOBILE VERTICALLY STACKED LAYOUT
    -- =========================================================================
    -- Top Tab Switcher: Full-width dual buttons
    Layout.drawCard(0, 0, w, 40, { color = theme.surface, borderColor = theme.border, radius = 8 })
    local tabW = math.floor((w - 12) / 2)

    local pcTabSelected = (ctrl.tab == "pc")
    local pcTabLabel = ("PC STORAGE (%d/%d)"):format(#ctrl.pcItems, pcCap)
    Layout.drawButton(6, 5, tabW - 3, 30, pcTabLabel, {
      kind = pcTabSelected and "accent" or "ghost",
      selected = pcTabSelected,
      font = "caption",
    })

    local bagTabSelected = (ctrl.tab == "bag")
    local bagTabLabel = ("BAG ITEMS (%d/%d)"):format(#ctrl.bagItems, bagCap)
    Layout.drawButton(6 + tabW + 3, 5, tabW - 3, 30, bagTabLabel, {
      kind = bagTabSelected and "accent" or "ghost",
      selected = bagTabSelected,
      font = "caption",
    })

    -- Middle Active Items List Panel
    local detailH = 114
    local listH = footY - 46 - detailH - 8
    Layout.drawCard(0, 46, w, listH, { color = theme.surface, borderColor = theme.border, radius = 8 })

    local rowH = 36
    local listStartY = 54
    local visibleCount = math.max(1, math.floor((listH - 16) / (rowH + 3)))

    local scroll = isPcTab and (ctrl.pcScroll or 0) or (ctrl.bagScroll or 0)
    if curIdx <= scroll then
      scroll = curIdx - 1
    elseif curIdx > scroll + visibleCount then
      scroll = curIdx - visibleCount
    end
    scroll = math.max(0, math.min(math.max(0, #items - visibleCount), scroll))
    if isPcTab then ctrl.pcScroll = scroll else ctrl.bagScroll = scroll end

    local itemW = (#items > visibleCount) and (w - 26) or (w - 16)

    if #items == 0 then
      local emptyTitle = isPcTab and "NO STORED ITEMS" or "BAG IS EMPTY"
      Layout.drawSlot(8, listStartY + 4, w - 16, 60, { color = theme.surfaceHigh, borderColor = theme.border, radius = 6 })
      Layout.drawText(emptyTitle, 16, listStartY + 14, { font = "caption", color = theme.textMuted, bold = true })
      Layout.drawText("Press ◄ / ► to switch between PC and Bag.", 16, listStartY + 34, { font = "tiny", color = theme.textDim })
    else
      for r = 1, visibleCount do
        local idx = scroll + r
        local it = items[idx]
        if it then
          local isSel = (curIdx == idx)
          local iy = listStartY + (r - 1) * (rowH + 3)
          local label = it.label or it.name or it.id or "ITEM"
          local count = it.count or it.qty or it.stack
          local def = it.def or (game.data and game.data.items and (game.data.items[it.id] or game.data.items[it.value]))
          local isKey = (def and def.keyItem) or (type(it.id) == "string" and it.id:find("^HM_"))

          if isSel then
            Layout.drawCard(8, iy, itemW, rowH, {
              color = theme.accentDark,
              borderColor = theme.colors.accent or theme.borderStrong,
              borderWidth = 2,
              radius = 6,
            })
            Layout.drawText(label, 16, iy + 9, { font = "caption", color = theme.heading, bold = true, width = itemW - 74 })
            if isKey then
              Layout.drawBadge(8 + itemW - 56, iy + 6, "KEY", { kind = "accent", font = "tiny", width = 48 })
            elseif count and tostring(count) ~= "" and not it.cancel then
              local cntStr = "x" .. tostring(count)
              Layout.drawBadge(8 + itemW - 56, iy + 6, cntStr, { kind = "good", font = "tiny", width = 48 })
            end
          else
            Layout.drawSlot(8, iy, itemW, rowH, {
              color = theme.surfaceHigh,
              borderColor = theme.border,
              borderWidth = 1,
              radius = 6,
            })
            Layout.drawText(label, 16, iy + 9, { font = "caption", color = theme.text, width = itemW - 74 })
            if isKey then
              Layout.drawBadge(8 + itemW - 56, iy + 6, "KEY", { kind = "ghost", font = "tiny", width = 48 })
            elseif count and tostring(count) ~= "" and not it.cancel then
              local cntStr = "x" .. tostring(count)
              Layout.drawBadge(8 + itemW - 56, iy + 6, cntStr, { kind = "ghost", font = "tiny", width = 48 })
            end
          end
        end
      end
    end

    if #items > visibleCount then
      Layout.drawScrollBar(w - 14, listStartY, 5, listH - 18, #items, visibleCount, scroll)
    end

    -- Bottom Docked Item Detail Drawer
    local detailY = 46 + listH + 6
    Layout.drawCard(0, detailY, w, detailH, { color = theme.surface, borderColor = theme.border, radius = 8 })

    local curItem = ctrl:getSelectedItem() or items[curIdx]
    if curItem and not curItem.cancel then
      local label = curItem.label or curItem.name or curItem.id or "ITEM"
      local itemId = curItem.value or curItem.id
      local def = curItem.def or (itemId and game.data and game.data.items and (game.data.items[itemId] or game.data.items[curItem.id]))
      local category = getItemCategory(itemId, def)

      Layout.drawText(label, 14, detailY + 8, { font = "headline", color = theme.heading, bold = true, width = w - 120 })
      Layout.drawBadge(w - 90, detailY + 8, category, { kind = "accent", font = "tiny" })

      local desc = ItemDatabase.getDescription(itemId, def, game)
      Layout.drawTextWrapped(desc, 14, detailY + 34, w - 28, { font = "caption", color = theme.textDim })
    else
      Layout.drawText("No item selected", 14, detailY + 14, { font = "caption", color = theme.textMuted })
    end
  end

  -- 5. Footer Hint Bar
  local hints = {
    { key = "A", label = "Actions", primary = true },
    { key = "◄ ►", label = "Pocket" },
    { key = "▲ ▼", label = "Select" },
    { key = "B", label = "Back" },
  }
  Layout.drawHintBar(0, footY, w, 36, hints, { paddingX = isNarrow and 8 or 16, gap = isNarrow and 10 or 20 })

  -- 6. Interactive Modal SubState Overlays (Dynamic Width & Centering)
  local isSubQty = (subState and (subState.isQuantityBox or subState.qty ~= nil)) or (state.qty and state.max)
  local isSubChoice = (subState and (subState.isChoiceBox or subState.choices ~= nil or subState.labels ~= nil or subState.onChoose ~= nil))
  local isSubAction = (subState and subState.items and not isSubQty and not isSubChoice)
  local isSubNotice = state.pcCompletion or (state.footer and state.footer:find("{PROMPT}"))

  if ctrl.mode == "action_menu" or isSubAction then
    local rawActionItems = (isSubAction and subState.items)
    local actions = {}
    if rawActionItems then
      for _, itm in ipairs(rawActionItems) do
        local str = (type(itm) == "table" and (itm.label or itm.name or itm[1])) or tostring(itm)
        actions[#actions + 1] = { id = str, label = str:upper(), desc = "Select option" }
      end
    else
      actions = isPcTab and {
        { id = "WITHDRAW", label = "WITHDRAW TO BAG", desc = "Move items into your bag inventory" },
        { id = "TOSS", label = "TOSS ITEM", desc = "Permanently discard from storage" },
        { id = "CANCEL", label = "CANCEL", desc = "Return to item browser" },
      } or {
        { id = "DEPOSIT", label = "DEPOSIT TO PC", desc = "Store items safely in PC storage" },
        { id = "TOSS", label = "TOSS ITEM", desc = "Permanently discard from bag" },
        { id = "CANCEL", label = "CANCEL", desc = "Return to item browser" },
      }
    end

    local actionCur = (isSubAction and (subState.index or 1)) or ctrl.actionCursor or 1
    local mw = math.min(320, w - 24)
    local mh = 64 + #actions * 52
    local mx = math.floor((w - mw) / 2)
    local my = math.floor((h - mh) / 2)

    Layout.drawCard(mx, my, mw, mh, {
      color = theme.surface,
      borderColor = theme.colors.accent or theme.borderStrong,
      borderWidth = 2,
      radius = 10,
    })

    local curItem = ctrl:getSelectedItem() or items[curIdx]
    local itemName = curItem and (curItem.label or curItem.name or curItem.id) or "Selected Item"
    Layout.drawText("SELECT ACTION", mx + 20, my + 14, { font = "headline", color = theme.heading, bold = true })
    Layout.drawText(itemName, mx + 20, my + 34, { font = "caption", color = theme.colors.accent, bold = true, width = mw - 40 })

    for ai, act in ipairs(actions) do
      local isSel = (actionCur == ai)
      local ay = my + 54 + (ai - 1) * 50

      if isSel then
        Layout.drawCard(mx + 16, ay, mw - 32, 44, {
          color = theme.accentDark,
          borderColor = theme.colors.accent or theme.borderStrong,
          borderWidth = 2,
          radius = 6,
        })
        Layout.drawText(act.label, mx + 24, ay + 6, { font = "button", color = theme.heading, bold = true })
        Layout.drawText(act.desc, mx + 24, ay + 24, { font = "tiny", color = theme.textMuted })
      else
        Layout.drawSlot(mx + 16, ay, mw - 32, 44, {
          color = theme.surfaceHigh,
          borderColor = theme.border,
          borderWidth = 1,
          radius = 6,
        })
        Layout.drawText(act.label, mx + 24, ay + 6, { font = "button", color = theme.text })
        Layout.drawText(act.desc, mx + 24, ay + 24, { font = "tiny", color = theme.textDim })
      end
    end

  elseif ctrl.mode == "quantity" or isSubQty then
    local activeQty = (isSubQty and (subState and subState.qty or state.qty)) or ctrl.qty or 1
    local maxQty = (isSubQty and (subState and subState.max or state.max)) or ctrl.maxQty or 1

    local mw = math.min(340, w - 24)
    local mh = 186
    local mx = math.floor((w - mw) / 2)
    local my = math.floor((h - mh) / 2)

    Layout.drawCard(mx, my, mw, mh, {
      color = theme.surface,
      borderColor = theme.colors.accent or theme.borderStrong,
      borderWidth = 2,
      radius = 10,
    })

    local actionTitle = (ctrl.activeAction == "WITHDRAW" and "WITHDRAW QUANTITY")
        or (ctrl.activeAction == "DEPOSIT" and "DEPOSIT QUANTITY")
        or (ctrl.activeAction == "TOSS" and "TOSS QUANTITY")
        or "SET QUANTITY"
    Layout.drawText(actionTitle, mx + 20, my + 14, { font = "headline", color = theme.heading, bold = true })

    local curItem = ctrl:getSelectedItem() or items[curIdx]
    local itemName = curItem and (curItem.label or curItem.name or curItem.id) or "Item"
    Layout.drawBadge(mx + mw - 110, my + 12, ("MAX: %d"):format(maxQty), { kind = "accent", font = "tiny" })

    Layout.drawSlot(mx + 16, my + 44, mw - 32, 78, {
      color = theme.surfaceHigh,
      borderColor = theme.border,
      borderWidth = 1,
      radius = 8,
    })

    Layout.drawText(itemName, mx + 24, my + 52, { font = "caption", color = theme.textMuted, bold = true, width = mw - 48 })
    local qtyStr = ("◄   x %02d / %02d   ►"):format(activeQty, maxQty)
    Layout.drawText(qtyStr, mx + 24, my + 72, { font = "title", color = theme.colors.accent or theme.heading, bold = true })

    local qFrac = math.min(1.0, activeQty / math.max(1, maxQty))
    Layout.drawProgressBar(mx + 24, my + 104, mw - 48, 4, qFrac, {
      fillColor = theme.colors.accent,
      bgColor = theme.surface,
    })

    Layout.drawText("▲/▼: ±10   ◄/►: ±1   A: Set   B: Cancel", mx + 20, my + 142, { font = "caption", color = theme.textDim })

  elseif ctrl.mode == "confirm_toss" or isSubChoice then
    local mw = math.min(340, w - 24)
    local mh = 160
    local mx = math.floor((w - mw) / 2)
    local my = math.floor((h - mh) / 2)

    Layout.drawCard(mx, my, mw, mh, {
      color = theme.surface,
      borderColor = theme.colors.danger or theme.borderStrong,
      borderWidth = 2,
      radius = 10,
    })

    Layout.drawText("CONFIRM ACTION", mx + 20, my + 14, { font = "headline", color = theme.colors.danger or theme.heading, bold = true })
    local curItem = ctrl:getSelectedItem() or items[curIdx]
    local itemName = curItem and (curItem.label or curItem.name or curItem.id) or "item"
    local promptText = ("Are you sure you want to discard %dx %s? This cannot be undone."):format(ctrl.qty or 1, itemName)
    if isSubChoice and state.footer then promptText = state.footer:gsub("{PROMPT}", "") end
    Layout.drawTextWrapped(promptText, mx + 20, my + 44, mw - 40, { font = "body", color = theme.text })

    local btnW = math.floor((mw - 56) / 2)
    local btnH = 34
    local btnY = my + 104

    local choiceCur = (isSubChoice and (subState and subState.index or 1)) or ctrl.actionCursor or 1
    local isYes = (choiceCur == 1)
    Layout.drawButton(mx + 20, btnY, btnW, btnH, "YES, TOSS", {
      kind = isYes and "danger" or "ghost",
      selected = isYes,
      font = "button",
    })

    local isNo = (choiceCur == 2)
    Layout.drawButton(mx + mw - btnW - 20, btnY, btnW, btnH, "NO, KEEP", {
      kind = isNo and "primary" or "ghost",
      selected = isNo,
      font = "button",
    })

  elseif (ctrl.mode == "message" and ctrl.message) or isSubNotice then
    local noticeText = (ctrl.mode == "message" and ctrl.message) or (state.footer and state.footer:gsub("{PROMPT}", ""):gsub("\n", " ")) or "Item transferred successfully."

    local mw = math.min(380, w - 24)
    local mh = 146
    local mx = math.floor((w - mw) / 2)
    local my = math.floor((h - mh) / 2)

    Layout.drawCard(mx, my, mw, mh, {
      color = theme.surface,
      borderColor = (ctrl.messageKind == "danger") and theme.colors.danger or theme.borderStrong,
      borderWidth = 2,
      radius = 10,
    })

    Layout.drawText("TERMINAL NOTICE", mx + 20, my + 14, { font = "headline", color = theme.heading, bold = true })
    Layout.drawTextWrapped(noticeText, mx + 20, my + 46, mw - 40, { font = "body", color = theme.text })

    local badgeText = "PRESS A TO DISMISS"
    local fontName = "tiny"
    local bw = Layout.textWidth(badgeText, fontName) + 20
    local badgeX = mx + mw - bw - 18
    local badgeY = my + mh - 34
    Layout.drawBadge(badgeX, badgeY, badgeText, {
      kind = (ctrl.messageKind == "danger") and "danger" or "good",
      font = fontName,
      width = bw,
    })
  end
end

return PlayerPcRenderer
