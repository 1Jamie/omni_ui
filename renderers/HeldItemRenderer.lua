-- OmniUI Modern Held Item Action Interface Renderer
-- Floating party item manager for Give, Take, and Swap operations with real-time mon held item status.
-- Responsively adapts card sizing, action buttons, and modal dialogs across all viewport types.

local Layout = require("mods.omni_ui.core.Layout")
local Widgets = require("mods.omni_ui.core.Widgets")

local HeldItemRenderer = {}

function HeldItemRenderer.draw(game, state, vw, vh, theme, subState, viewport)
  if not state then return end

  local ctx = Layout.getContext(vw, vh, viewport)
  local isPortrait = ctx.isPortrait or (vw < 540)
  local isMobileLandscape = not isPortrait and (vh < 440)
  local isCompact = ctx.isCompact or isMobileLandscape or ctx.isUltraCompact

  local data = (game and game.data) or {}
  local save = state.save or (game and game.save) or {}
  local party = (save and save.party) or {}
  local slot = state.slot or 1
  local mon = party[slot] or (state.mon and (type(state.mon) == "function" and state:mon() or state.mon)) or {}
  local monName = (mon.nickname or mon.name or mon.species or "POKÉMON"):upper()
  local monLvl = tonumber(mon.level or 1)
  local heldId = mon.item
  local itemDef = heldId and data.items and data.items[heldId]
  local heldName = (itemDef and itemDef.name) or heldId

  local index = state.index or 1 -- 1 = GIVE, 2 = TAKE

  -- Dimmed Backdrop
  love.graphics.setColor(0, 0, 0, 0.60)
  love.graphics.rectangle("fill", 0, 0, vw, vh)

  -- Main Modal Metrics
  local pad = ctx.isUltraCompact and 8 or (isCompact and 10 or 16)
  local cardW = math.min(480, math.max(280, vw - pad * 2))
  local cardH = math.min(vh - pad * 2, (state.message or state.confirm) and (isCompact and 200 or 230) or (isCompact and 170 or 200))
  local cardX = math.floor((vw - cardW) / 2)
  local cardY = math.floor((vh - cardH) / 2)

  -- 1. Main Action Card
  Layout.drawCard(cardX, cardY, cardW, cardH, {
    color = theme.colors.surface,
    borderColor = theme.colors.borderStrong,
    borderWidth = 1.5,
    radius = theme.metrics and theme.metrics.radius.modal or (isCompact and 10 or 14),
  })

  -- 2. Mon Status Banner Header
  local topY = cardY + pad
  local headerH = isCompact and 20 or 24
  local monHeaderStr = ("SLOT %d : %s (Lv. %d)"):format(slot, monName, monLvl)
  Layout.drawBadge(cardX + pad, topY, monHeaderStr, {
    kind = "accent",
    font = "tiny",
    height = headerH,
    radius = 4,
  })

  local heldBadge = heldName and ("HELD: " .. tostring(heldName):upper()) or "NO ITEM"
  local heldKind = heldName and "good" or "ghost"
  local heldW = Layout.textWidth(heldBadge, "tiny") + 16
  Layout.drawBadge(cardX + cardW - pad - heldW, topY, heldBadge, {
    kind = heldKind,
    font = "tiny",
    height = headerH,
    width = heldW,
    radius = 4,
  })

  -- 3. Action Buttons or Message/Confirm Modal
  local bodyY = topY + headerH + (isCompact and 6 or 10)
  local bodyW = cardW - pad * 2

  if state.message or state.confirm then
    local activeMsg = state.message or state.confirm
    local pageIdx = activeMsg.page or 1
    local pages = activeMsg.pages or {}
    local curLines = pages[pageIdx] or {}
    local line1 = curLines[1] or ""
    local line2 = curLines[2] or ""

    local msgH = cardH - (bodyY - cardY) - pad
    Layout.drawSlot(cardX + pad, bodyY, bodyW, msgH, {
      color = theme.colors.surfaceHigh,
      borderColor = theme.colors.borderStrong,
      borderWidth = 1,
      radius = 6,
    })

    Layout.drawText(line1, cardX + pad + 10, bodyY + (isCompact and 8 or 12), {
      font = isCompact and "caption" or "body",
      color = theme.colors.heading,
      bold = true,
    })
    if line2 and #line2 > 0 and msgH >= 50 then
      Layout.drawText(line2, cardX + pad + 10, bodyY + (isCompact and 24 or 32), {
        font = isCompact and "caption" or "body",
        color = theme.colors.heading,
        bold = true,
      })
    end

    if state.confirm and pageIdx >= #pages then
      local choice = state.confirm.choice or 1
      local btnW = isCompact and 68 or 84
      local btnH = isCompact and 24 or 28
      local btnY = bodyY + msgH - btnH - (isCompact and 4 or 8)

      Layout.drawButton(cardX + cardW - pad - btnW * 2 - 12, btnY, btnW, btnH, "YES", {
        kind = choice == 1 and "primary" or "ghost",
        selected = choice == 1,
        font = "tiny",
      })
      Layout.drawButton(cardX + cardW - pad - btnW - 6, btnY, btnW, btnH, "NO", {
        kind = choice == 2 and "primary" or "ghost",
        selected = choice == 2,
        font = "tiny",
      })
    end
  else
    -- Give / Take Selection Buttons
    local footerH = isCompact and 22 or 28
    local btnAreaH = cardH - (bodyY - cardY) - footerH - pad
    local btnH = math.min(36, math.floor((btnAreaH - 6) / 2))
    local btnGap = 6

    -- Button 1: GIVE
    Layout.drawButton(cardX + pad, bodyY, bodyW, btnH, "GIVE ITEM FROM BAG", {
      kind = index == 1 and "primary" or "ghost",
      selected = index == 1,
      font = btnH > 28 and "button" or "caption",
    })

    -- Button 2: TAKE
    Layout.drawButton(cardX + pad, bodyY + btnH + btnGap, bodyW, btnH, "TAKE HELD ITEM", {
      kind = index == 2 and "primary" or "ghost",
      selected = index == 2,
      font = btnH > 28 and "button" or "caption",
    })

    -- 4. Footer Hint Bar
    local footerY = cardY + cardH - footerH
    Layout.drawText("▲ ▼ Select Action    A Confirm    B Back", cardX + pad, footerY + 2, {
      font = "tiny",
      color = theme.colors.textDim,
      align = "center",
      width = bodyW,
    })
  end
end

return HeldItemRenderer
