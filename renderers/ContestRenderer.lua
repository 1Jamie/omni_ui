-- OmniUI Modern Bug Catching Contest Comparison Screen Renderer
-- Responsive inspection card between Stock Pokémon and New Catch with stat deltas & action selector.
-- Reconstructs side-by-side cards into stacked vertical cards in portrait and adapts heights for mobile landscape.

local Layout = require("mods.omni_ui.core.Layout")
local Widgets = require("mods.omni_ui.core.Widgets")

local ContestRenderer = {}

local function monName(mon)
  if not mon then return "UNKNOWN" end
  return (mon.nickname or mon.name or mon.species or "POKÉMON"):upper()
end

local function monLevel(mon)
  if not mon then return 1 end
  return tonumber(mon.level or 1)
end

local function monHp(mon)
  if not mon then return 0 end
  return tonumber(mon.maxHp or (mon.stats and mon.stats.hp) or mon.hp or 0)
end

function ContestRenderer.draw(game, state, vw, vh, theme, subState, viewport)
  if not state then return end

  local ctx = Layout.getContext(vw, vh, viewport)
  local isPortrait = ctx.isPortrait or (vw < 540)
  local isMobileLandscape = not isPortrait and (vh < 440)
  local isCompact = ctx.isCompact or isMobileLandscape or ctx.isUltraCompact

  local data = (game and game.data) or {}
  local stockMon = state.stock
  local caughtMon = state.caught
  local choice = state.choice or 1 -- 1 = YES (switch), 2 = NO (keep stock)

  -- 1. Dimmed Map Backdrop
  love.graphics.setColor(0, 0, 0, 0.70)
  love.graphics.rectangle("fill", 0, 0, vw, vh)

  -- Card Coordinates
  local pad = ctx.isUltraCompact and 8 or (isCompact and 10 or 16)
  local cardW = math.min(720, vw - pad * 2)
  local cardH = math.min(520, vh - pad * 2)
  local cardX = math.floor((vw - cardW) / 2)
  local cardY = math.floor((vh - cardH) / 2)

  -- 2. Master Comparison Frame
  Layout.drawCard(cardX, cardY, cardW, cardH, {
    color = theme.colors.surface,
    borderColor = theme.colors.borderStrong,
    borderWidth = 1.5,
    radius = theme.metrics and theme.metrics.radius.modal or (isCompact and 10 or 16),
  })

  -- 3. Top Header
  local topY = cardY + pad
  local headerH = isCompact and 22 or 26
  Layout.drawBadge(cardX + pad, topY, "BUG-CATCHING CONTEST", {
    kind = "accent",
    font = "tiny",
    height = headerH,
    radius = 4,
  })

  local evalW = isCompact and 110 or 130
  Layout.drawBadge(cardX + cardW - pad - evalW, topY, "EVALUATION", {
    kind = "primary",
    font = "tiny",
    height = headerH,
    width = evalW,
    radius = 4,
  })

  -- Helper to draw a Pokémon card/slot
  local function drawMonCard(mon, cx, cy, cw, ch, isStock, isCompactView)
    local name = monName(mon)
    local lvl = monLevel(mon)
    local hp = monHp(mon)
    local species = mon and mon.species or "CATERPIE"
    local pDef = data.pokemon and data.pokemon[species] or { types = { "BUG" } }

    Layout.drawCard(cx, cy, cw, ch, {
      color = theme.colors.surfaceHigh,
      borderColor = isStock and theme.colors.border or (theme.colors.hpGreen or theme.colors.accent),
      borderWidth = isStock and 1 or 1.5,
      radius = 8,
    })

    local tagText = isStock and "STOCK MON (IN BAG)" or "NEW CAUGHT MON"
    local tagKind = isStock and "ghost" or "good"
    Layout.drawBadge(cx + 8, cy + 6, tagText, {
      kind = tagKind,
      font = "tiny",
      height = 18,
      radius = 3,
    })

    local nameY = cy + (isCompactView and 26 or 30)
    Layout.drawText(name, cx + 10, nameY, {
      font = isCompactView and "button" or "headline",
      color = theme.colors.heading,
      bold = true,
    })

    Layout.drawBadge(cx + cw - 64, cy + 6, ("Lv. %d"):format(lvl), {
      kind = "primary",
      font = "tiny",
      height = 18,
      width = 54,
      radius = 3,
    })

    local uTypes = Widgets.getUniqueTypes(pDef.types)
    if #uTypes > 0 then
      local tyX = cx + 10
      local tyY = nameY + (isCompactView and 20 or 24)
      for _, tName in ipairs(uTypes) do
        local bw = Widgets.drawTypeBadge(tName, tyX, tyY, { height = 16, font = "tiny" })
        tyX = tyX + (bw or 50) + 4
      end
    end

    -- Health slot / bar
    local statY = cy + ch - (isCompactView and 30 or 44)
    local statH = isCompactView and 24 or 38
    Layout.drawSlot(cx + 8, statY, cw - 16, statH, {
      color = theme.colors.surface,
      borderColor = theme.colors.border,
      borderWidth = 1,
      radius = 5,
    })

    Layout.drawText(("%d HP"):format(hp), cx + 14, statY + math.floor((statH - Layout.textHeight("tiny")) / 2), {
      font = "tiny",
      color = theme.colors.hpGreen or theme.colors.accent,
      bold = true,
    })

    local barW = cw - 90
    local barX = cx + 76
    local barY = statY + math.floor((statH - 6) / 2)
    Layout.drawProgressBar(barX, barY, barW, 6, hp, 200, {
      fillColor = theme.colors.hpGreen,
      bgColor = theme.colors.surfaceHigh,
    })
  end

  -- Stat comparison deltas
  local stockHp = monHp(stockMon)
  local caughtHp = monHp(caughtMon)
  local hpDiff = caughtHp - stockHp

  -- 4. Content Area Layout (Portrait Stacked vs Landscape Side-by-Side)
  local compY = topY + headerH + (isCompact and 6 or 10)
  local promptH = isCompact and (isPortrait and 76 or 64) or 88
  local compH = cardH - (compY - cardY) - promptH - pad

  if isPortrait then
    -- =========================================================================
    -- PORTRAIT STACKED LAYOUT (Top: Stock, Bottom: Caught)
    -- =========================================================================
    local slotGap = 8
    local singleSlotH = math.floor((compH - slotGap) / 2)
    local slotW = cardW - pad * 2

    drawMonCard(stockMon, cardX + pad, compY, slotW, singleSlotH, true, true)
    drawMonCard(caughtMon, cardX + pad, compY + singleSlotH + slotGap, slotW, singleSlotH, false, true)

    if hpDiff ~= 0 then
      local deltaLabel = hpDiff > 0 and ("+ %d HP"):format(hpDiff) or ("- %d HP"):format(math.abs(hpDiff))
      local deltaKind = hpDiff > 0 and "good" or "danger"
      local badgeW = 70
      Layout.drawBadge(cardX + cardW - pad - badgeW - 8, compY + singleSlotH - 10, deltaLabel, {
        kind = deltaKind,
        font = "tiny",
        height = 20,
        width = badgeW,
        radius = 10,
      })
    end
  else
    -- =========================================================================
    -- LANDSCAPE SIDE-BY-SIDE LAYOUT
    -- =========================================================================
    local colW = math.floor((cardW - pad * 2 - (isCompact and 10 or 16)) / 2)
    local leftColX = cardX + pad
    local rightColX = leftColX + colW + (isCompact and 10 or 16)

    drawMonCard(stockMon, leftColX, compY, colW, compH, true, isMobileLandscape)
    drawMonCard(caughtMon, rightColX, compY, colW, compH, false, isMobileLandscape)

    if hpDiff ~= 0 then
      local deltaLabel = hpDiff > 0 and ("+ %d HP GAIN"):format(hpDiff) or ("- %d HP LESS"):format(math.abs(hpDiff))
      local deltaKind = hpDiff > 0 and "good" or "danger"
      local badgeW = isCompact and 90 or 108
      local badgeX = cardX + math.floor((cardW - badgeW) / 2)
      Layout.drawBadge(badgeX, compY + math.floor(compH / 2) - 11, deltaLabel, {
        kind = deltaKind,
        font = "tiny",
        height = 22,
        width = badgeW,
        radius = 11,
      })
    end
  end

  -- 5. Bottom Action Question & Buttons
  local promptY = cardY + cardH - promptH - pad
  local promptW = cardW - pad * 2
  Layout.drawCard(cardX + pad, promptY, promptW, promptH, {
    color = theme.colors.surfaceHigh,
    borderColor = theme.colors.accent,
    borderWidth = 1.5,
    radius = 8,
  })

  local questionText = isCompact and "Keep newly caught Pokémon or retain stock?" or "Switch Pokémon? Keep the newly caught Pokémon or retain your stock?"
  Layout.drawText(questionText, cardX + pad + 12, promptY + (isCompact and 6 or 10), {
    font = isCompact and "caption" or "body",
    color = theme.colors.heading,
    bold = true,
  })

  local btnW = math.min(220, math.floor((promptW - (isCompact and 24 or 36)) / 2))
  local btnH = isCompact and 28 or 34
  local btnY = promptY + promptH - btnH - (isCompact and 6 or 8)

  Layout.drawButton(cardX + pad + 12, btnY, btnW, btnH, isCompact and "YES (NEW)" or "YES (KEEP NEW MON)", {
    kind = choice == 1 and "primary" or "ghost",
    selected = choice == 1,
    font = "tiny",
  })

  local btn2X = cardX + pad + promptW - btnW - 12
  Layout.drawButton(btn2X, btnY, btnW, btnH, isCompact and "NO (STOCK)" or "NO (KEEP STOCK)", {
    kind = choice == 2 and "primary" or "ghost",
    selected = choice == 2,
    font = "tiny",
  })
end

return ContestRenderer
