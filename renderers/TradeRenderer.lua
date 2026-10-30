-- OmniUI Modern Link Trade & NPC Trade Screen Renderer
-- Dual-pane split-screen interface displaying Local party vs Remote/NPC partner with network handshake & mon inspection.
-- Full multi-device responsiveness supporting horizontal desktop layouts and stacked mobile portrait orientations.

local Layout = require("mods.omni_ui.core.Layout")
local Widgets = require("mods.omni_ui.core.Widgets")

local TradeRenderer = {}

function TradeRenderer.draw(game, state, vw, vh, theme, subState, viewport)
  if not state then return end

  local ctx = Layout.getContext(vw, vh, viewport)
  local isPortrait = ctx.isPortrait or (vw < 540)
  local isMobileLandscape = not isPortrait and (vh < 440)
  local isCompact = ctx.isCompact or isMobileLandscape

  local data = (game and game.data) or state.data or {}
  local save = state.save or (game and game.save) or {}
  local party = (save and save.party) or {}
  local row = state.row or {}
  local anim = state.animating or state.isAnimating
  local picking = state.picking

  -- 1. Dimmed Map / Network Space Backdrop
  love.graphics.setColor(0, 0, 0, 0.70)
  love.graphics.rectangle("fill", 0, 0, vw, vh)

  -- Layout Metrics
  local pad = ctx.isUltraCompact and 8 or (isCompact and 10 or 16)
  local cardW = math.min(760, vw - pad * 2)
  local cardH = math.min(540, vh - pad * 2)
  local cardX = math.floor((vw - cardW) / 2)
  local cardY = math.floor((vh - cardH) / 2)

  -- 2. Master Glassmorphic Frame
  Layout.drawCard(cardX, cardY, cardW, cardH, {
    color = theme.colors.surface,
    borderColor = theme.colors.borderStrong,
    borderWidth = 1.5,
    radius = theme.metrics and theme.metrics.radius.modal or (isCompact and 10 or 16),
  })

  -- 3. Top Header Bar
  local headerH = isCompact and 26 or 32
  local topY = cardY + pad
  Layout.drawBadge(cardX + pad, topY, "LINK TRADE SYSTEM", {
    kind = "accent",
    font = "tiny",
    height = headerH,
    radius = 4,
  })

  local syncStatus = anim and "SYNCHRONIZING..." or (picking and "SELECTING POKÉMON..." or "LINK CONNECTED")
  local syncKind = anim and "warning" or (picking and "primary" or "good")
  local syncW = Layout.textWidth(syncStatus, "tiny") + 16
  Layout.drawBadge(cardX + cardW - pad - syncW, topY, syncStatus, {
    kind = syncKind,
    font = "tiny",
    height = headerH,
    width = syncW,
    radius = 4,
  })

  -- Wanted Mon & Partner Mon Data
  local wantedSpecies = row.give or (party[1] and party[1].species) or "DROWZEE"
  local wantedDef = data.pokemon and data.pokemon[wantedSpecies] or { name = wantedSpecies, types = { "NORMAL" } }
  local wantedName = wantedDef.name or wantedSpecies

  local getSpecies = row.get or "MACHOP"
  local getDef = data.pokemon and data.pokemon[getSpecies] or { name = getSpecies, types = { "FIGHTING" } }
  local getName = row.nickname or getDef.name or getSpecies

  local contentY = topY + headerH + (isCompact and 4 or 8)
  local footerH = (state.message or state.confirm) and (isCompact and 86 or 110) or (isCompact and 28 or 36)
  local contentH = cardH - (contentY - cardY) - footerH - pad

  if isPortrait then
    -- =========================================================================
    -- PORTRAIT STACKED LAYOUT (Top: Player Wanted, Middle: Badge, Bottom: Partner Offer)
    -- =========================================================================
    local slotGap = 6
    local slotH = math.floor((contentH - slotGap) / 2)
    local slotW = cardW - pad * 2

    -- Top Slot: Player Request
    Layout.drawCard(cardX + pad, contentY, slotW, slotH, {
      color = theme.colors.surfaceHigh,
      borderColor = theme.colors.border,
      borderWidth = 1,
      radius = 8,
    })
    Layout.drawBadge(cardX + pad + 8, contentY + 6, "YOU GIVE", { kind = "accent", font = "tiny", height = 18, radius = 3 })
    Layout.drawText(tostring(wantedName):upper(), cardX + pad + 80, contentY + 6, { font = "button", color = theme.colors.heading, bold = true })

    local wantedTypes = Widgets.getUniqueTypes(wantedDef.types)
    if #wantedTypes > 0 then
      local tyX = cardX + pad + 8
      for _, tName in ipairs(wantedTypes) do
        local bw = Widgets.drawTypeBadge(tName, tyX, contentY + 28, { height = 16, font = "tiny" })
        tyX = tyX + (bw or 50) + 4
      end
    end

    if row.gender then
      local gText = (row.gender == "TRADE_GENDER_FEMALE" or row.gender == "female") and "♀ FEMALE" or "♂ MALE"
      local gKind = (row.gender == "TRADE_GENDER_FEMALE" or row.gender == "female") and "danger" or "primary"
      Layout.drawBadge(cardX + slotW - 70, contentY + 6, gText, { kind = gKind, font = "tiny", height = 18, radius = 3 })
    end

    -- Bottom Slot: Partner Offer
    local botSlotY = contentY + slotH + slotGap
    Layout.drawCard(cardX + pad, botSlotY, slotW, slotH, {
      color = theme.colors.surfaceHigh,
      borderColor = theme.colors.hpGreen or theme.colors.accent,
      borderWidth = 1.5,
      radius = 8,
    })
    Layout.drawBadge(cardX + pad + 8, botSlotY + 6, "YOU GET", { kind = "good", font = "tiny", height = 18, radius = 3 })
    Layout.drawText(tostring(getName):upper(), cardX + pad + 80, botSlotY + 6, { font = "button", color = theme.colors.heading, bold = true })

    local getTypes = Widgets.getUniqueTypes(getDef.types)
    if #getTypes > 0 then
      local tyX = cardX + pad + 8
      for _, tName in ipairs(getTypes) do
        local bw = Widgets.drawTypeBadge(tName, tyX, botSlotY + 28, { height = 16, font = "tiny" })
        tyX = tyX + (bw or 50) + 4
      end
    end

    if row.item then
      local itemDef = data.items and data.items[row.item]
      local itemName = (itemDef and itemDef.name) or row.item
      Layout.drawText("ITEM: " .. tostring(itemName):upper(), cardX + pad + 120, botSlotY + 28, { font = "tiny", color = theme.colors.accent, bold = true })
    end
  else
    -- =========================================================================
    -- LANDSCAPE SIDE-BY-SIDE DUAL PANE
    -- =========================================================================
    local paneW = math.floor((cardW - pad * 2 - (isCompact and 10 or 16)) / 2)

    -- Left Pane: Local Player Party & Wanted Mon
    local leftX = cardX + pad
    Layout.drawCard(leftX, contentY, paneW, contentH, {
      color = theme.colors.surfaceHigh,
      borderColor = theme.colors.border,
      borderWidth = 1,
      radius = 10,
    })

    Layout.drawText("PLAYER OFFER / WANTED", leftX + 12, contentY + 8, {
      font = "tiny",
      color = theme.colors.accent,
      bold = true,
    })

    local monCardY = contentY + (isCompact and 26 or 32)
    local monCardH = contentH - (isCompact and 32 or 40)
    Layout.drawSlot(leftX + 8, monCardY, paneW - 16, monCardH, {
      color = theme.colors.surface,
      borderColor = theme.colors.borderStrong,
      borderWidth = 1,
      radius = 8,
    })

    Layout.drawText("REQUESTING:", leftX + 16, monCardY + 8, {
      font = "tiny",
      color = theme.colors.textDim,
    })
    Layout.drawText(tostring(wantedName):upper(), leftX + 16, monCardY + (isCompact and 22 or 26), {
      font = isCompact and "button" or "headline",
      color = theme.colors.heading,
      bold = true,
    })

    local wantedTypes = Widgets.getUniqueTypes(wantedDef.types)
    if #wantedTypes > 0 then
      local tyX = leftX + 16
      local tyY = monCardY + (isCompact and 48 or 58)
      for _, tName in ipairs(wantedTypes) do
        local bw = Widgets.drawTypeBadge(tName, tyX, tyY, { height = isCompact and 16 or 18, font = "tiny" })
        tyX = tyX + (bw or 56) + 6
      end
    end

    if row.gender then
      local gText = (row.gender == "TRADE_GENDER_FEMALE" or row.gender == "female") and "♀ FEMALE" or "♂ MALE"
      local gKind = (row.gender == "TRADE_GENDER_FEMALE" or row.gender == "female") and "danger" or "primary"
      local gY = monCardY + (isCompact and 72 or 88)
      Layout.drawBadge(leftX + 16, gY, gText, {
        kind = gKind,
        font = "tiny",
        height = 18,
        radius = 4,
      })
    end

    -- Right Pane: Partner Mon (The Mon You Receive)
    local rightX = cardX + pad + paneW + (isCompact and 10 or 16)
    Layout.drawCard(rightX, contentY, paneW, contentH, {
      color = theme.colors.surfaceHigh,
      borderColor = theme.colors.hpGreen or theme.colors.accent,
      borderWidth = 1,
      radius = 10,
    })

    Layout.drawText("PARTNER OFFER (RECEIVE)", rightX + 12, contentY + 8, {
      font = "tiny",
      color = theme.colors.hpGreen or theme.colors.accent,
      bold = true,
    })

    Layout.drawSlot(rightX + 8, monCardY, paneW - 16, monCardH, {
      color = theme.colors.surface,
      borderColor = theme.colors.borderStrong,
      borderWidth = 1,
      radius = 8,
    })

    Layout.drawText("OFFERING:", rightX + 16, monCardY + 8, {
      font = "tiny",
      color = theme.colors.textDim,
    })
    Layout.drawText(tostring(getName):upper(), rightX + 16, monCardY + (isCompact and 22 or 26), {
      font = isCompact and "button" or "headline",
      color = theme.colors.heading,
      bold = true,
    })

    local getTypes = Widgets.getUniqueTypes(getDef.types)
    if #getTypes > 0 then
      local tyX = rightX + 16
      local tyY = monCardY + (isCompact and 48 or 58)
      for _, tName in ipairs(getTypes) do
        local bw = Widgets.drawTypeBadge(tName, tyX, tyY, { height = isCompact and 16 or 18, font = "tiny" })
        tyX = tyX + (bw or 56) + 6
      end
    end

    if row.item then
      local itemDef = data.items and data.items[row.item]
      local itemName = (itemDef and itemDef.name) or row.item
      local itemY = monCardY + (isCompact and 72 or 88)
      Layout.drawText("HELD: " .. tostring(itemName):upper(), rightX + 16, itemY, {
        font = "tiny",
        color = theme.colors.accent,
        bold = true,
      })
    end

    if row.otName or row.otId then
      local otStr = ("OT: %s (ID: %s)"):format(row.otName or "TRAINER", row.otId or "00000")
      local otY = monCardY + (isCompact and 92 or 112)
      Layout.drawText(otStr, rightX + 16, otY, {
        font = "tiny",
        color = theme.colors.textDim,
      })
    end

    -- Central Pulse Badge
    local midX = cardX + math.floor(cardW / 2)
    local midY = monCardY + math.floor(monCardH / 2)
    Layout.drawBadge(midX - 14, midY - 12, "⇄", {
      kind = "primary",
      font = "button",
      width = 28,
      height = 24,
      radius = 5,
    })
  end

  -- 5. Footer Dialogue / Confirmation Modal
  local msgBoxY = cardY + cardH - footerH - pad
  local msgBoxW = cardW - pad * 2

  if state.message or state.confirm then
    local activeMsg = state.message or state.confirm
    local pageIdx = activeMsg.page or 1
    local pages = activeMsg.pages or {}
    local curLines = pages[pageIdx] or {}
    local line1 = curLines[1] or ""
    local line2 = curLines[2] or ""

    Layout.drawCard(cardX + pad, msgBoxY, msgBoxW, footerH, {
      color = theme.colors.surfaceHigh,
      borderColor = theme.colors.accent,
      borderWidth = 1.5,
      radius = 8,
    })

    Layout.drawText(line1, cardX + pad + 12, msgBoxY + (isCompact and 6 or 10), {
      font = isCompact and "caption" or "body",
      color = theme.colors.heading,
      bold = true,
    })
    if line2 and #line2 > 0 then
      Layout.drawText(line2, cardX + pad + 12, msgBoxY + (isCompact and 24 or 32), {
        font = isCompact and "caption" or "body",
        color = theme.colors.heading,
        bold = true,
      })
    end

    -- Yes / No Choice Buttons
    if state.confirm and pageIdx >= #pages then
      local choice = state.confirm.choice or 1
      local btnW = isCompact and 70 or 86
      local btnH = isCompact and 26 or 30
      local btnY = msgBoxY + footerH - btnH - (isCompact and 6 or 8)

      Layout.drawButton(cardX + cardW - pad - btnW * 2 - 14, btnY, btnW, btnH, "YES", {
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
    Layout.drawText("A Confirm    B Cancel", cardX + pad, msgBoxY + (isCompact and 6 or 10), {
      font = "tiny",
      color = theme.colors.textDim,
      align = "center",
      width = msgBoxW,
    })
  end
end

return TradeRenderer
