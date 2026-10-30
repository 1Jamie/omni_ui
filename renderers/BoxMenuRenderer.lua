-- OmniUI Storage System (Player PC & Bill's PC) Renderer
-- Inventory and Pokémon PC storage manager with count badges, dynamic scrollbars,
-- live item descriptions, and deposit/withdraw confirmation modals.

local Layout = require("mods.omni_ui.core.Layout")
local AdapterResolver = require("mods.omni_ui.adapters.AdapterResolver")

local BoxMenuRenderer = {}

function BoxMenuRenderer.draw(game, state, w, h, theme, subState)
  local isPlayerPC = (state.pcItems ~= nil or state.screenId == "PlayerPC" or state.isPlayerPC)
  local items = state.items or state._items or {}
  local curIdx = state.index or state.cursor or 1
  local scroll = state.scroll or 0
  local title = tostring(state.title or (isPlayerPC and "PLAYER'S ITEM PC" or "BILL'S POKÉMON STORAGE")):upper()

  local ctx = Layout.getContext(w, h)
  local isNarrow = (w < 560) or ctx.isPortrait
  local footY = h - 38

  -- 1. Top Header Card
  Layout.drawCard(0, 0, w, 44, { color = theme.surface, borderColor = theme.border, radius = 8 })
  Layout.drawText(title, 18, 12, { font = "headline", color = theme.heading, bold = true })
  Layout.drawBadge(w - (isNarrow and 100 or 180), 10, ("%d STORED"):format(#items), { kind = "good", font = "caption", height = 24 })

  if isNarrow then
    -- =========================================================================
    -- PORTRAIT / COMPACT MOBILE FULL-WIDTH LIST + DOCKED PREVIEW DRAWER
    -- =========================================================================
    local detailH = 96
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
    state.scroll = scroll

    local itemW = (#items > visibleCount) and (w - 28) or (w - 16)

    for r = 1, visibleCount do
      local idx = scroll + r
      local it = items[idx]
      if it then
        local isSel = (curIdx == idx)
        local iy = 56 + (r - 1) * (rowH + 3)
        local label = it.label or it.name or it.id or "ITEM"
        local count = it.count or it.right or it.displayValue

        if isSel then
          Layout.drawCard(8, iy, itemW, rowH, {
            color = theme.accentDark,
            borderColor = theme.borderStrong,
            borderWidth = 2,
            radius = 6,
          })
          Layout.drawText(label, 16, iy + 8, { font = "caption", color = theme.heading, bold = true, width = itemW - 80 })
          if count and tostring(count) ~= "" then
            local cntStr = "x" .. tostring(count)
            local cntW = Layout.textWidth(cntStr, "tiny") + 16
            Layout.drawBadge(8 + itemW - cntW - 6, iy + 6, cntStr, { kind = "good", font = "tiny", width = cntW })
          end
        else
          Layout.drawSlot(8, iy, itemW, rowH, {
            color = theme.surfaceHigh,
            borderColor = theme.border,
            borderWidth = 1,
            radius = 6,
          })
          Layout.drawText(label, 16, iy + 8, { font = "caption", color = theme.text, width = itemW - 80 })
          if count and tostring(count) ~= "" then
            local cntStr = "x" .. tostring(count)
            local cntW = Layout.textWidth(cntStr, "tiny") + 16
            Layout.drawBadge(8 + itemW - cntW - 6, iy + 6, cntStr, { kind = "ghost", font = "tiny", width = cntW })
          end
        end
      end
    end

    if #items > visibleCount then
      Layout.drawScrollBar(w - 12, 56, 5, listH - 12, #items, visibleCount, scroll)
    end

    -- Docked Item Preview Drawer
    local detailY = 50 + listH + 6
    Layout.drawCard(0, detailY, w, detailH, { color = theme.surface, borderColor = theme.border, radius = 8 })

    local curItem = items[curIdx]
    if curItem and not curItem.cancel then
      local label = curItem.label or curItem.name or curItem.id or "ITEM"
      Layout.drawText(label, 14, detailY + 8, { font = "headline", color = theme.heading, bold = true })
      Layout.drawBadge(w - 90, detailY + 8, "STORAGE", { kind = "ghost", font = "tiny" })

      local itemId = curItem.value or curItem.id
      local def = (curItem.def) or (itemId and game.data and game.data.items and game.data.items[itemId])
      local desc = (def and def.description) or "Item stored safely inside the terminal storage system."
      if type(desc) == "table" then desc = table.concat(desc, " ") end

      Layout.drawTextWrapped(desc, 14, detailY + 30, w - 28, { font = "caption", color = theme.textDim })
    else
      Layout.drawText("LOG OFF TERMINAL", 14, detailY + 12, { font = "headline", color = theme.textMuted, bold = true })
      Layout.drawText("Exit storage system and return to room.", 14, detailY + 36, { font = "caption", color = theme.textDim })
    end

    -- Submenu Modal (WITHDRAW / DEPOSIT / TOSS)
    if subState and (subState.isMenu or subState.items) and subState.items and not subState.pages then
      local subW = math.min(w - 32, 200)
      local subH = #subState.items * 38 + 18
      local sx = math.floor((w - subW) / 2)
      local sy = math.max(60, math.floor((h - subH) / 2))

      love.graphics.setColor(0, 0, 0, 0.45)
      love.graphics.rectangle("fill", 0, 0, w, h)
      love.graphics.setColor(1, 1, 1, 1)

      Layout.drawCard(sx, sy, subW, subH, {
        color = theme.surface,
        borderColor = theme.borderStrong,
        borderWidth = 2,
        radius = 8,
      })

      for si, entry in ipairs(subState.items) do
        local isSubSel = (subState.index == si)
        local ey = sy + 9 + (si - 1) * 38
        local lbl = tostring(entry.label or "OPTION"):upper()
        if isSubSel then
          Layout.drawButton(sx + 8, ey, subW - 16, 32, lbl, { kind = "primary", selected = true })
        else
          Layout.drawSlot(sx + 8, ey, subW - 16, 32, { color = theme.surfaceHigh, borderColor = theme.border })
          Layout.drawText(lbl, sx + 14, ey + 8, { font = "button", color = theme.text })
        end
      end
    end
  else
    -- =========================================================================
    -- LANDSCAPE / STANDARD 2-PANEL LAYOUT
    -- =========================================================================
    local bodyH = h - 96
    local leftW = math.floor(w * 0.54)
    local rightX = leftW + 12
    local rightW = w - rightX

    -- Left Storage List Panel
    Layout.drawCard(0, 52, leftW, bodyH, { color = theme.surface, borderColor = theme.border, radius = 8 })

    local rowH = 40
    local visibleCount = math.max(1, math.floor((bodyH - 24) / (rowH + 4)))

    if curIdx <= scroll then
      scroll = curIdx - 1
    elseif curIdx > scroll + visibleCount then
      scroll = curIdx - visibleCount
    end
    scroll = math.max(0, math.min(math.max(0, #items - visibleCount), scroll))
    state.scroll = scroll

    local itemW = (#items > visibleCount) and (leftW - 28) or (leftW - 16)

    for r = 1, visibleCount do
      local idx = scroll + r
      local it = items[idx]
      if it then
        local isSel = (curIdx == idx)
        local iy = 62 + (r - 1) * (rowH + 4)
        local label = it.label or it.name or it.id or "ITEM"
        local count = it.count or it.right or it.displayValue

        if isSel then
          Layout.drawCard(8, iy, itemW, rowH, {
            color = theme.accentDark,
            borderColor = theme.borderStrong,
            borderWidth = 2,
            radius = 6,
          })
          Layout.drawText(label, 20, iy + 10, { font = "button", color = theme.heading, bold = true })
          if count and tostring(count) ~= "" then
            local cntStr = "x" .. tostring(count)
            local cntW = Layout.textWidth(cntStr, "tiny") + 16
            Layout.drawBadge(8 + itemW - cntW - 8, iy + 8, cntStr, { kind = "good", font = "tiny", width = cntW })
          end
        else
          Layout.drawSlot(8, iy, itemW, rowH, {
            color = theme.surfaceHigh,
            borderColor = theme.border,
            borderWidth = 1,
            radius = 6,
          })
          Layout.drawText(label, 20, iy + 10, { font = "button", color = theme.text })
          if count and tostring(count) ~= "" then
            local cntStr = "x" .. tostring(count)
            local cntW = Layout.textWidth(cntStr, "tiny") + 16
            Layout.drawBadge(8 + itemW - cntW - 8, iy + 8, cntStr, { kind = "ghost", font = "tiny", width = cntW })
          end
        end
      end
    end

    if #items > visibleCount then
      Layout.drawScrollBar(leftW - 14, 62, 6, bodyH - 24, #items, visibleCount, scroll)
    end

    -- Right Preview & Operation Panel
    Layout.drawCard(rightX, 52, rightW, bodyH, { color = theme.surface, borderColor = theme.border, radius = 8 })

    local curItem = items[curIdx]
    if curItem and not curItem.cancel then
      local label = curItem.label or curItem.name or curItem.id or "ITEM"
      Layout.drawText(label, rightX + 18, 66, { font = "headline", color = theme.heading, bold = true })
      Layout.drawBadge(rightX + rightW - 100, 66, "STORAGE", { kind = "ghost" })

      local itemId = curItem.value or curItem.id
      local def = (curItem.def) or (itemId and game.data and game.data.items and game.data.items[itemId])
      local desc = (def and def.description) or "Item stored safely inside the terminal storage system."
      if type(desc) == "table" then desc = table.concat(desc, " ") end

      local descH = 140
      Layout.drawSlot(rightX + 14, 100, rightW - 28, descH, { color = theme.surfaceHigh, borderColor = theme.border, radius = 6 })
      Layout.drawTextWrapped(desc, rightX + 26, 114, rightW - 52, { font = "body", color = theme.textDim })
    else
      Layout.drawText("LOG OFF TERMINAL", rightX + 18, 66, { font = "headline", color = theme.textMuted, bold = true })
      Layout.drawSlot(rightX + 14, 100, rightW - 28, 80, { color = theme.surfaceHigh, borderColor = theme.border, radius = 6 })
      Layout.drawText("Exit the storage system and return to room.", rightX + 26, 126, { font = "caption", color = theme.textDim })
    end

    if subState and (subState.isMenu or subState.items) and subState.items and not subState.pages then
      local subW = 150
      local subH = #subState.items * 36 + 18
      local sx = leftW - subW - 14
      local sy = 70

      Layout.drawCard(sx, sy, subW, subH, {
        color = theme.surface,
        borderColor = theme.borderStrong,
        borderWidth = 2,
        radius = 8,
      })

      for si, entry in ipairs(subState.items) do
        local isSubSel = (subState.index == si)
        local ey = sy + 9 + (si - 1) * 36
        local lbl = tostring(entry.label or "OPTION"):upper()
        if isSubSel then
          Layout.drawButton(sx + 6, ey, subW - 12, 32, lbl, { kind = "primary", selected = true })
        else
          Layout.drawSlot(sx + 6, ey, subW - 12, 32, { color = theme.surfaceHigh, borderColor = theme.border })
          Layout.drawText(lbl, sx + 14, ey + 8, { font = "button", color = theme.text })
        end
      end
    end
  end

  -- 4. Bottom Button Hints Footer Bar
  local hints = {
    { key = "▲ ▼", label = "Select", primary = true },
    { key = "A", label = "Options" },
    { key = "B", label = "Log Off" },
  }
  Layout.drawHintBar(0, footY, w, 36, hints, { paddingX = isNarrow and 8 or 16, gap = isNarrow and 10 or 20 })
end

return BoxMenuRenderer
